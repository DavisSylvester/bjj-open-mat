import { describe, expect, it } from "bun:test";
import { assertActiveMember } from "../src/facades/gym-authz.mts";
import type { Gym, GymMembership } from "@bjj/contract";

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
