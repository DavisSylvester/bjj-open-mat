import { describe, expect, it } from "bun:test";
import type { Gym, GymMembership, User } from "@bjj/contract";
import { AdminMembersFacade } from "../src/facades/admin-members.facade.mts";
import type { GymRepo, MembershipRepo, UserRepo } from "../src/facades/admin-members.facade.mts";
import type { GymMemberCounts } from "../src/repositories/membership.repository.mts";

const GYMS: Gym[] = [
  { id: "g-1", name: "Renzo Dallas", address: "A", state: "TX", city: "Dallas", amenities: [], isVerified: true, ownerId: "u-9" },
  { id: "g-2", name: "Alliance Frisco", address: "B", state: "TX", amenities: [], isVerified: false },
  { id: "g-3", name: "Nowhere BJJ", address: "C", amenities: [], isVerified: false },
  { id: "g-4", name: "Empty Gym", address: "D", state: "CA", amenities: [], isVerified: false },
];

const COUNTS: GymMemberCounts[] = [
  { gymId: "g-1", memberCount: 2, pendingCount: 1 },
  { gymId: "g-2", memberCount: 1, pendingCount: 0 },
  { gymId: "g-3", memberCount: 1, pendingCount: 0 },
];

interface FacadeOverrides {
  memberships?: Partial<MembershipRepo>;
  users?: Partial<UserRepo>;
  gyms?: Partial<GymRepo>;
}

/// Stubs are typed against the facade's own dependency types, so renaming a
/// repository method breaks compilation here instead of passing silently.
function facade(overrides: FacadeOverrides = {}): AdminMembersFacade {
  const memberships: MembershipRepo = {
    countsByGym: async (): Promise<GymMemberCounts[]> => COUNTS,
    listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: [], total: 0 }),
    ...overrides.memberships,
  };
  const users: UserRepo = {
    findByIds: async (): Promise<User[]> => [],
    listWithoutMemberships: async (): Promise<{ items: User[]; total: number }> => ({ items: [], total: 0 }),
    ...overrides.users,
  };
  const gyms: GymRepo = {
    list: async (): Promise<{ items: Gym[]; total: number }> => ({ items: GYMS, total: GYMS.length }),
    ...overrides.gyms,
  };
  return new AdminMembersFacade(memberships, users, gyms);
}

describe("AdminMembersFacade.tree", () => {
  it("groups gyms by state and sorts states alphabetically", async () => {
    const tree = await facade().tree();
    expect(tree.states.map((s) => s.state)).toEqual(["TX"]);
    expect(tree.states[0]!.gyms.map((g) => g.name)).toEqual(["Alliance Frisco", "Renzo Dallas"]);
  });

  it("puts a gym with no state into noState", async () => {
    const tree = await facade().tree();
    expect(tree.noState.map((g) => g.id)).toEqual(["g-3"]);
  });

  it("omits gyms with no memberships entirely", async () => {
    const tree = await facade().tree();
    const allIds = [...tree.states.flatMap((s) => s.gyms), ...tree.noState].map((g) => g.id);
    expect(allIds).not.toContain("g-4");
  });

  it("carries counts and ownerId through", async () => {
    const tree = await facade().tree();
    const g1 = tree.states[0]!.gyms.find((g) => g.id === "g-1")!;
    expect(g1.memberCount).toBe(2);
    expect(g1.pendingCount).toBe(1);
    expect(g1.ownerId).toBe("u-9");
  });

  it("surfaces a counted gymId that has no gym document instead of dropping it", async () => {
    const f = facade({
      memberships: {
        countsByGym: async (): Promise<GymMemberCounts[]> => [
          ...COUNTS,
          { gymId: "g-deleted", memberCount: 4, pendingCount: 2 },
        ],
      },
    });
    const tree = await f.tree();
    const orphan = tree.noState.find((g) => g.id === "g-deleted");
    expect(orphan).toBeDefined();
    expect(orphan!.name).toBe("Unknown gym (g-deleted)");
    expect(orphan!.memberCount).toBe(4);
    expect(orphan!.pendingCount).toBe(2);
  });

  it("reports the gymless user count", async () => {
    const f = facade({
      users: { listWithoutMemberships: async (): Promise<{ items: User[]; total: number }> => ({ items: [], total: 37 }) },
    });
    expect((await f.tree()).noGym.userCount).toBe(37);
  });
});

describe("AdminMembersFacade.gymRoster", () => {
  const rows: GymMembership[] = [
    { id: "m-1", gymId: "g-1", userId: "u-1", status: "active", verifiedMember: true, isHome: true, visibleInRoster: false, joinedAt: "2026-08-01T00:00:00.000Z" } as GymMembership,
    { id: "m-2", gymId: "g-1", userId: "u-missing", status: "pending", verifiedMember: false, isHome: false, visibleInRoster: true, joinedAt: "2026-08-02T00:00:00.000Z" } as GymMembership,
  ];

  it("enriches rows with display name and email", async () => {
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: rows, total: 2 }) },
      users: { findByIds: async (): Promise<User[]> => [{ id: "u-1", email: "d@e.dev", displayName: "Davis", role: "practitioner" } as User] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items[0]!.displayName).toBe("Davis");
    expect(items[0]!.email).toBe("d@e.dev");
    expect(items[0]!.visibleInRoster).toBe(false);
  });

  it("marks an unresolvable user rather than dropping the row", async () => {
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: rows, total: 2 }) },
      users: { findByIds: async (): Promise<User[]> => [] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items).toHaveLength(2);
    expect(items[1]!.unresolved).toBe(true);
    expect(items[1]!.displayName).toBe("u-missing");
  });

  it("defaults a legacy row with no status to active", async () => {
    const legacy = [{ ...rows[0]!, status: undefined }] as GymMembership[];
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: legacy, total: 1 }) },
      users: { findByIds: async (): Promise<User[]> => [{ id: "u-1", email: "d@e.dev", displayName: "Davis", role: "practitioner" } as User] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items[0]!.status).toBe("active");
  });
});
