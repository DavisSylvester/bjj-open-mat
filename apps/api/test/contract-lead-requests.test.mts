import "../src/config/formats.mts";
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { WaitlistLeadRequest, GymLeadRequest, LeadResponse } from "@bjj/contract";

describe("lead request schemas", () => {
  it("rejects a waitlist request with a bad email", () => {
    expect(Value.Check(WaitlistLeadRequest, { email: "nope" })).toBe(false);
  });

  it("accepts a waitlist request with utm + honeypot", () => {
    expect(
      Value.Check(WaitlistLeadRequest, { email: "a@b.com", utm: { source: "ig" }, hp: "" }),
    ).toBe(true);
  });

  it("requires gymName and ownerEmail on a gym request", () => {
    expect(Value.Check(GymLeadRequest, { ownerEmail: "a@b.com" })).toBe(false);
    expect(Value.Check(GymLeadRequest, { gymName: "GB", ownerEmail: "a@b.com" })).toBe(true);
  });

  it("shapes the lead response", () => {
    expect(Value.Check(LeadResponse, { status: "confirmed" })).toBe(true);
  });
});
