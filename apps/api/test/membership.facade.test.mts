// apps/api/test/membership.facade.test.mts
import { describe, expect, it } from "bun:test";
import { MembershipFacade } from "../src/facades/membership.facade.mts";
import type { GymMembership, BeltPromotion, Gym, User } from "@bjj/contract";

function facade(seed?: { gymOwnerId?: string; memberships?: GymMembership[]; users?: User[] }): {
  f: MembershipFacade;
  memberships: Map<string, GymMembership>;
  promotions: BeltPromotion[];
  users: Map<string, User>;
} {
  const memberships = new Map<string, GymMembership>(); // key `${gymId}:${userId}`
  (seed?.memberships ?? []).forEach((m) => memberships.set(`${m.gymId}:${m.userId}`, m));
  const promotions: BeltPromotion[] = [];
  const users = new Map<string, User>();
  (seed?.users ?? []).forEach((u) => users.set(u.id, u));
  const gyms = new Map<string, Gym>([["g1", { id: "g1", name: "Atos", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }]]);

  const membershipRepo = {
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      const k = `${m.gymId}:${m.userId}`; const cur = memberships.get(k); if (cur) return cur;
      memberships.set(k, m); return m;
    },
    find: async (g: string, u: string): Promise<GymMembership | null> => memberships.get(`${g}:${u}`) ?? null,
    remove: async (g: string, u: string): Promise<void> => { memberships.delete(`${g}:${u}`); },
    listByGym: async (g: string, incl: boolean): Promise<GymMembership[]> =>
      [...memberships.values()].filter((m) => {
        if (m.gymId !== g) return false;
        if (m.status === 'pending') return false;
        if (incl) return true;
        return m.status !== 'hidden' && m.status !== 'inactive' && m.visibleInRoster !== false;
      }),
    listByUser: async (u: string): Promise<GymMembership[]> => [...memberships.values()].filter((m) => m.userId === u),
    update: async (g: string, u: string, patch: Partial<GymMembership>): Promise<GymMembership | null> => {
      const k = `${g}:${u}`; const cur = memberships.get(k); if (!cur) return null;
      const next = { ...cur, ...patch }; memberships.set(k, next); return next;
    },
    setHome: async (u: string, g: string): Promise<void> => {
      [...memberships.values()].filter((m) => m.userId === u).forEach((m) => { m.isHome = m.gymId === g; });
    },
    listAll: async (skip: number, limit: number): Promise<{ items: GymMembership[]; total: number }> => {
      const items = [...memberships.values()];
      return { items: items.slice(skip, skip + limit), total: items.length };
    },
  };
  const promotionRepo = {
    insert: async (p: BeltPromotion): Promise<BeltPromotion> => { promotions.push(p); return p; },
    listByUser: async (u: string): Promise<BeltPromotion[]> => promotions.filter((p) => p.userId === u),
  };
  const gymRepo = { findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null };
  const userRepo = {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id); if (!cur) return null; const next = { ...cur, ...patch }; users.set(id, next); return next;
    },
  };
  let n = 0;
  return { f: new MembershipFacade(membershipRepo, promotionRepo, gymRepo, userRepo, () => `id-${n++}`), memberships, promotions, users };
}

const member = (gymId: string, userId: string, over: Partial<GymMembership> = {}): GymMembership => ({
  id: `${gymId}-${userId}`, gymId, userId, status: "active", verifiedMember: false, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "2026-07-27T00:00:00.000Z", ...over,
});

describe("MembershipFacade", () => {
  it("join is idempotent and requires an existing gym", async () => {
    const { f } = facade();
    const m1 = await f.join("u1", "g1");
    const m2 = await f.join("u1", "g1");
    expect(m2.id).toBe(m1.id);
    await expect(f.join("u1", "missing")).rejects.toMatchObject({ code: "not_found" });
  });

  it("roster hides opted-out members and flags missing profiles", async () => {
    const { f } = facade({
      memberships: [member("g1", "vis"), member("g1", "hid", { visibleInRoster: false })],
      users: [{ id: "vis", email: "v@x.co", displayName: "Vis", beltRank: "blue" }],
    });
    const roster = await f.roster("g1");
    expect(roster.map((r) => r.userId)).toEqual(["vis"]);
    expect(roster[0]?.hasProfile).toBe(true);
  });

  it("only owner/coach/admin can promote; never self", async () => {
    const owner = "owner1";
    const { f, promotions, users } = facade({
      gymOwnerId: owner,
      memberships: [member("g1", "student"), member("g1", "coach1", { gymRole: "coach" })],
      users: [{ id: "student", email: "s@x.co", displayName: "S", beltRank: "white" }],
    });
    await expect(f.promote("stranger", "g1", "student", { beltRank: "blue", beltStripes: 0 }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
    await expect(f.promote(owner, "g1", owner, { beltRank: "black", beltStripes: 0 }, "gym_owner"))
      .rejects.toMatchObject({ code: "forbidden" });
    const promo = await f.promote("coach1", "g1", "student", { beltRank: "blue", beltStripes: 2 }, "practitioner");
    expect(promo.beltRank).toBe("blue");
    expect(promotions.length).toBe(1);
    expect(users.get("student")?.verifiedBeltRank).toBe("blue");
    expect(users.get("student")?.verifiedBeltStripes).toBe(2);
    expect(users.get("student")?.verifiedByGymId).toBe("g1");
  });

  it("promote rejects a non-member target", async () => {
    const { f } = facade({ gymOwnerId: "owner1" });
    await expect(f.promote("owner1", "g1", "ghost", { beltRank: "blue", beltStripes: 0 }, "gym_owner"))
      .rejects.toMatchObject({ code: "not_found" });
  });

  it("manage actions return not_found for a non-existent gym", async () => {
    const { f } = facade({ gymOwnerId: "owner1" });
    await expect(
      f.promote("owner1", "ghost-gym", "student", { beltRank: "blue", beltStripes: 0 }, "practitioner"),
    ).rejects.toMatchObject({ code: "not_found" });
    await expect(
      f.updateMembership("owner1", "ghost-gym", "student", { verifiedMember: true }, "practitioner"),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("setting a home gym updates User.homeGymId and demotes others", async () => {
    const { f, memberships, users } = facade({
      memberships: [member("g1", "u1", { isHome: true }), member("gB", "u1")],
      users: [{ id: "u1", email: "u@x.co", displayName: "U" }],
    });
    await f.updateMyMembership("u1", "gB", { isHome: true });
    expect(memberships.get("gB:u1")?.isHome).toBe(true);
    expect(memberships.get("g1:u1")?.isHome).toBe(false);
    expect(users.get("u1")?.homeGymId).toBe("gB");
  });

  it('public roster omits hidden and inactive members', async () => {
    const { f } = facade({
      memberships: [
        member('g1', 'act'),
        member('g1', 'hid', { status: 'hidden' }),
        member('g1', 'ina', { status: 'inactive' }),
      ],
    });
    const roster = await f.roster('g1');
    expect(roster.map((r) => r.userId)).toEqual(['act']);
    expect(roster[0]?.status).toBe('active');
  });

  it('a manager roster includes hidden and inactive, active first', async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [
        member('g1', 'ina', { status: 'inactive' }),
        member('g1', 'hid', { status: 'hidden' }),
        member('g1', 'act'),
      ],
    });
    const roster = await f.roster('g1', true, { userId: owner, role: 'gym_owner' });
    expect(roster.map((r) => r.userId)).toEqual(['act', 'hid', 'ina']);
    expect(roster.map((r) => r.status)).toEqual(['active', 'hidden', 'inactive']);
  });

  it('includeHidden requires a caller who can manage the gym', async () => {
    const { f } = facade({ memberships: [member('g1', 'plain')] });
    await expect(f.roster('g1', true)).rejects.toMatchObject({ code: 'unauthorized' });
    await expect(f.roster('g1', true, { userId: 'plain', role: 'practitioner' }))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it('an owner can hide a member and the change is stamped', async () => {
    const owner = 'owner1';
    const { f, memberships } = facade({ gymOwnerId: owner, memberships: [member('g1', 'student')] });
    const updated = await f.updateMembership(owner, 'g1', 'student', { status: 'hidden' }, 'gym_owner');
    expect(updated.status).toBe('hidden');
    expect(updated.statusUpdatedBy).toBe(owner);
    expect(typeof updated.statusUpdatedAt).toBe('string');
    expect(memberships.get('g1:student')?.status).toBe('hidden');
  });

  it('a caller cannot change their own status', async () => {
    const owner = 'owner1';
    const { f } = facade({ gymOwnerId: owner, memberships: [member('g1', owner, { gymRole: 'owner' })] });
    await expect(f.updateMembership(owner, 'g1', owner, { status: 'inactive' }, 'gym_owner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it("the gym's owner cannot be hidden or deactivated", async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [member('g1', owner, { gymRole: 'owner' }), member('g1', 'coach1', { gymRole: 'coach' })],
    });
    await expect(f.updateMembership('coach1', 'g1', owner, { status: 'hidden' }, 'practitioner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it("setting the gym's owner back to 'active' is allowed (the guard rail only blocks non-active)", async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [member('g1', owner, { gymRole: 'owner' }), member('g1', 'coach1', { gymRole: 'coach' })],
    });
    const updated = await f.updateMembership('coach1', 'g1', owner, { status: 'active' }, 'practitioner');
    expect(updated.status).toBe('active');
  });

  it('status changes leave verifiedMember and gymRole untouched', async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [member('g1', 'student', { verifiedMember: true, gymRole: 'coach' })],
    });
    const updated = await f.updateMembership(owner, 'g1', 'student', { status: 'inactive' }, 'gym_owner');
    expect(updated.verifiedMember).toBe(true);
    expect(updated.gymRole).toBe('coach');
  });
});
