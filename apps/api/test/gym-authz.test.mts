// apps/api/test/gym-authz.test.mts
import { describe, expect, it } from "bun:test";
import { assertCanManageGym } from "../src/facades/gym-authz.mts";
import type { Gym, GymMembership } from "@bjj/contract";

function deps(gym: Gym | null, membership: GymMembership | null): { gyms: { findById(): Promise<Gym | null> }; memberships: { find(): Promise<GymMembership | null> } } {
  return {
    gyms: { findById: async (): Promise<Gym | null> => gym },
    memberships: { find: async (): Promise<GymMembership | null> => membership },
  };
}
const gym = (ownerId?: string): Gym => ({ id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId });
const mem = (role: GymMembership["gymRole"]): GymMembership => ({
  id: "m", gymId: "g1", userId: "u", status: "active", verifiedMember: true, gymRole: role,
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t",
});

describe("assertCanManageGym", () => {
  it("admin passes without a gym", async () => {
    await assertCanManageGym(deps(null, null), "u", "g1", "admin");
  });
  it("gym owner passes", async () => {
    await assertCanManageGym(deps(gym("owner1"), null), "owner1", "g1", "practitioner");
  });
  it("active coach passes", async () => {
    await assertCanManageGym(deps(gym(), mem("coach")), "u", "g1", "practitioner");
  });
  it("plain member is forbidden", async () => {
    await expect(assertCanManageGym(deps(gym(), mem("member")), "u", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });
  it("missing gym for non-admin is not_found", async () => {
    await expect(assertCanManageGym(deps(null, null), "u", "ghost", "practitioner"))
      .rejects.toMatchObject({ code: "not_found" });
  });
});
