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
      [...memberships.values()].filter((m) => m.gymId === g && (incl || m.visibleInRoster !== false)),
    listByUser: async (u: string): Promise<GymMembership[]> => [...memberships.values()].filter((m) => m.userId === u),
    update: async (g: string, u: string, patch: Partial<GymMembership>): Promise<GymMembership | null> => {
      const k = `${g}:${u}`; const cur = memberships.get(k); if (!cur) return null;
      const next = { ...cur, ...patch }; memberships.set(k, next); return next;
    },
    setHome: async (u: string, g: string): Promise<void> => {
      [...memberships.values()].filter((m) => m.userId === u).forEach((m) => { m.isHome = m.gymId === g; });
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
});
