import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { AdminMembersTree, AdminRosterRow, GymSummary, NoGymUserRow } from "../src/schemas/admin-members.mts";

describe("admin members contract", () => {
  it("GymSummary requires counts and allows an absent state-bearing gym's optional fields", () => {
    const ok = { id: "g-1", name: "G", memberCount: 3, pendingCount: 1 };
    expect(Value.Check(GymSummary, ok)).toBe(true);
    expect(Value.Check(GymSummary, { ...ok, city: "Dallas", ownerId: "u-9" })).toBe(true);
    expect(Value.Check(GymSummary, { id: "g-1", name: "G" })).toBe(false);
  });

  it("AdminMembersTree carries states, noState gyms and a noGym count", () => {
    const tree = {
      states: [{ state: "TX", gyms: [{ id: "g-1", name: "G", memberCount: 1, pendingCount: 0 }] }],
      noState: [],
      noGym: { userCount: 37 },
    };
    expect(Value.Check(AdminMembersTree, tree)).toBe(true);
    expect(Value.Check(AdminMembersTree, { ...tree, noGym: {} })).toBe(false);
  });

  it("AdminRosterRow accepts all four statuses and requires the self-hide flag", () => {
    const base = {
      membershipId: "m-1", gymId: "g-1", userId: "u-1",
      displayName: "Davis", email: "d@e.dev",
      status: "pending" as const, visibleInRoster: true,
      verifiedMember: false, joinedAt: "2026-08-01T00:00:00.000Z",
    };
    for (const status of ["pending", "active", "hidden", "inactive"]) {
      expect(Value.Check(AdminRosterRow, { ...base, status })).toBe(true);
    }
    expect(Value.Check(AdminRosterRow, { ...base, status: "banned" })).toBe(false);
    const { visibleInRoster: _omitted, ...withoutFlag } = base;
    expect(Value.Check(AdminRosterRow, withoutFlag)).toBe(false);
  });

  it("NoGymUserRow carries no status field", () => {
    const row = { userId: "u-1", displayName: "Bob", email: "b@e.dev", createdAt: "2026-08-01T00:00:00.000Z" };
    expect(Value.Check(NoGymUserRow, row)).toBe(true);
  });
});
