import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymClaim } from "../src/index.mts";

describe("GymClaim schema", () => {
  const base = {
    id: "c1",
    gymId: "g1",
    claimantId: "u1",
    kind: "claim",
    relationship: "owner",
    contact: "owner@gym.com",
    message: "I own this gym",
    status: "pending",
    createdAt: "2026-07-30T00:00:00.000Z",
  };

  it("accepts a minimal valid pending claim", () => {
    expect(Value.Check(GymClaim, base)).toBe(true);
  });

  it("accepts an approved claim with decision + previousOwner fields", () => {
    const approved = {
      ...base,
      status: "approved",
      previousOwnerId: "u0",
      decidedAt: "2026-07-31T00:00:00.000Z",
      decidedBy: "admin1",
      decisionNote: "verified by phone",
    };
    expect(Value.Check(GymClaim, approved)).toBe(true);
  });

  it("rejects an invalid relationship", () => {
    expect(Value.Check(GymClaim, { ...base, relationship: "janitor" })).toBe(false);
  });

  it("rejects a missing required field (contact)", () => {
    const { contact, ...withoutContact } = base;
    expect(Value.Check(GymClaim, withoutContact)).toBe(false);
  });
});
