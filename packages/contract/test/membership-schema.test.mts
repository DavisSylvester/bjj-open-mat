import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymMembership, BeltPromotion } from "../src/index.mjs";

describe("GymMembership schema", () => {
  it("parses a minimal membership applying defaults", () => {
    const m = Value.Parse(GymMembership, {
      id: "m1", gymId: "g1", userId: "u1", joinedAt: "2026-07-27T00:00:00.000Z",
    });
    expect(m.gymRole).toBe("member");
    expect(m.status).toBe("active");
    expect(m.verifiedMember).toBe(false);
    expect(m.visibleInRoster).toBe(true);
    expect(m.isHome).toBe(false);
    expect(m.joinMethod).toBe("self");
  });
});

describe("BeltPromotion schema", () => {
  it("rejects stripes above 4", () => {
    expect(Value.Check(BeltPromotion, {
      id: "p1", userId: "u1", gymId: "g1", beltRank: "blue",
      beltStripes: 5, promotedByUserId: "u2", promotedAt: "2026-07-27T00:00:00.000Z",
    })).toBe(false);
  });
});
