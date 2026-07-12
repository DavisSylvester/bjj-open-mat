import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { WaitlistLead, GymLead } from "@bjj/contract";

describe("lead domain schemas", () => {
  it("accepts a valid waitlist lead", () => {
    const lead = {
      id: "w1",
      email: "a@b.com",
      status: "confirmed",
      utm: { source: "ig", medium: "social", campaign: "launch" },
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    expect(Value.Check(WaitlistLead, lead)).toBe(true);
  });

  it("accepts a valid gym lead with optional fields omitted", () => {
    const lead = {
      id: "g1",
      gymName: "Gracie Barra",
      ownerEmail: "coach@gym.com",
      status: "new",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    expect(Value.Check(GymLead, lead)).toBe(true);
  });
});
