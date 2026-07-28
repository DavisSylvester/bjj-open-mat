import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { User, PromoteBeltRequest, UpdateMembershipRequest, UpdateMyMembershipRequest, RosterMember } from "../src/index.mjs";

describe("membership requests + user verified fields", () => {
  it("User accepts verified belt fields", () => {
    expect(Value.Check(User, {
      id: "u1", email: "a@b.co", displayName: "A",
      verifiedBeltRank: "purple", verifiedBeltStripes: 2, verifiedByGymId: "g1",
      verifiedAt: "2026-07-27T00:00:00.000Z",
    })).toBe(true);
  });
  it("PromoteBeltRequest requires belt and bounds stripes", () => {
    expect(Value.Check(PromoteBeltRequest, { beltRank: "brown", beltStripes: 1 })).toBe(true);
    expect(Value.Check(PromoteBeltRequest, { beltStripes: 1 })).toBe(false);
    expect(Value.Check(PromoteBeltRequest, { beltRank: "brown", beltStripes: 9 })).toBe(false);
  });
  it("Update requests are all-optional", () => {
    expect(Value.Check(UpdateMembershipRequest, {})).toBe(true);
    expect(Value.Check(UpdateMyMembershipRequest, { isHome: true })).toBe(true);
  });
  it("RosterMember requires identity + role flags", () => {
    expect(Value.Check(RosterMember, {
      userId: "u1", name: "A", gymRole: "coach", verifiedMember: true, hasProfile: true,
    })).toBe(true);
  });
});
