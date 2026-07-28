import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymRole, MembershipStatus, JoinMethod } from "../src/index.mjs";

describe("membership enums", () => {
  it("accepts valid members", () => {
    expect(Value.Check(GymRole, "coach")).toBe(true);
    expect(Value.Check(MembershipStatus, "active")).toBe(true);
    expect(Value.Check(JoinMethod, "self")).toBe(true);
  });
  it("rejects invalid members", () => {
    expect(Value.Check(GymRole, "instructor")).toBe(false);
    expect(Value.Check(MembershipStatus, "banned")).toBe(false);
    expect(Value.Check(JoinMethod, "qr")).toBe(false);
  });
});
