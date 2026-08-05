import { describe, expect, it } from "bun:test";
import { assertActiveMember, assertCanManageGym } from "../src/facades/gym-authz.mts";
import type { GymAuthzDeps } from "../src/facades/gym-authz.mts";
import type { Gym, GymMembership, GymRole, MembershipStatus } from "@bjj/contract";

function deps(gym: Gym | null, membership: GymMembership | null): {
  gyms: { findById(): Promise<Gym | null> };
  memberships: { find(): Promise<GymMembership | null> };
} {
  return {
    gyms: { findById: async (): Promise<Gym | null> => gym },
    memberships: { find: async (): Promise<GymMembership | null> => membership },
  };
}
const gym = (ownerId?: string): Gym => ({ id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId });
const active: GymMembership = { id: "m", gymId: "g1", userId: "u", status: "active", verifiedMember: true, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" };

describe("assertActiveMember", () => {
  it("admin passes", async () => { await assertActiveMember(deps(gym(), null), "u", "g1", "admin"); });
  it("gym owner passes", async () => { await assertActiveMember(deps(gym("owner1"), null), "owner1", "g1", "practitioner"); });
  it("active member passes", async () => { await assertActiveMember(deps(gym(), active), "u", "g1", "practitioner"); });
  it("non-member is forbidden", async () => {
    await expect(assertActiveMember(deps(gym(), null), "u", "g1", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });
  it("inactive membership is forbidden", async () => {
    await expect(assertActiveMember(deps(gym(), { ...active, status: "pending" }), "u", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });
  it("missing gym is not_found", async () => {
    await expect(assertActiveMember(deps(null, null), "u", "ghost", "practitioner")).rejects.toMatchObject({ code: "not_found" });
  });
});

describe("gym authz vs membership status", () => {
  const gym_: Gym = { id: "g1", name: "Atos", address: "x", amenities: [], isVerified: true };

  function depsNew(status: MembershipStatus | undefined, gymRole: GymRole = "member"): GymAuthzDeps {
    return {
      gyms: { findById: async (): Promise<Gym | null> => gym_ },
      memberships: {
        find: async (): Promise<GymMembership | null> => ({
          id: "m1", gymId: "g1", userId: "u1", status, verifiedMember: false, gymRole,
          isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t",
        }),
      },
    };
  }

  it("a hidden member keeps member privileges", async () => {
    await expect(assertActiveMember(depsNew("hidden"), "u1", "g1", "practitioner")).resolves.toBeUndefined();
  });

  it("an inactive member loses member privileges", async () => {
    await expect(assertActiveMember(depsNew("inactive"), "u1", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("a hidden coach can still manage the gym", async () => {
    await expect(assertCanManageGym(depsNew("hidden", "coach"), "u1", "g1", "practitioner")).resolves.toBeUndefined();
  });

  it("an inactive coach cannot manage the gym", async () => {
    await expect(assertCanManageGym(depsNew("inactive", "coach"), "u1", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("a member with no status field keeps member privileges (legacy doc, schema default is active)", async () => {
    await expect(assertActiveMember(depsNew(undefined), "u1", "g1", "practitioner")).resolves.toBeUndefined();
  });

  it("a coach with no status field can still manage the gym (legacy doc, schema default is active)", async () => {
    await expect(assertCanManageGym(depsNew(undefined, "coach"), "u1", "g1", "practitioner")).resolves.toBeUndefined();
  });
});
