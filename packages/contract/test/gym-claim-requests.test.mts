import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  SubmitGymClaimRequest,
  RejectGymClaimRequest,
  AdminGymClaimsQuery,
} from "../src/index.mts";

describe("gym claim request schemas", () => {
  it("SubmitGymClaimRequest requires relationship, contact, message", () => {
    expect(
      Value.Check(SubmitGymClaimRequest, {
        relationship: "owner",
        contact: "me@gym.com",
        message: "hi",
      }),
    ).toBe(true);
    expect(Value.Check(SubmitGymClaimRequest, { relationship: "owner" })).toBe(false);
    expect(
      Value.Check(SubmitGymClaimRequest, { relationship: "owner", contact: "", message: "x" }),
    ).toBe(false);
  });

  it("RejectGymClaimRequest allows an optional note", () => {
    expect(Value.Check(RejectGymClaimRequest, {})).toBe(true);
    expect(Value.Check(RejectGymClaimRequest, { note: "not verified" })).toBe(true);
  });

  it("AdminGymClaimsQuery allows an optional status", () => {
    expect(Value.Check(AdminGymClaimsQuery, {})).toBe(true);
    expect(Value.Check(AdminGymClaimsQuery, { status: "pending" })).toBe(true);
    expect(Value.Check(AdminGymClaimsQuery, { status: "bogus" })).toBe(false);
  });
});
