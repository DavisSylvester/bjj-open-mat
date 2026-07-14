import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CreateOpenMatRequest, OpenMat, OpenMatListQuery, UserRole } from "@bjj/contract";

describe("contract: community submissions", () => {
  it("UserRole accepts admin", () => {
    expect(Value.Check(UserRole, "admin")).toBe(true);
  });
  it("OpenMat carries verified + status", () => {
    const om = Value.Create(OpenMat);
    expect(om).toHaveProperty("verified");
    expect(om).toHaveProperty("status");
  });
  it("CreateOpenMatRequest allows newGym instead of gymId", () => {
    const req = { newGym: { name: "New BJJ", address: "1 Main St" }, title: "Open Mat", startTime: "19:00", endTime: "21:00" };
    expect(Value.Check(CreateOpenMatRequest, req)).toBe(true);
  });
  it("OpenMatListQuery accepts status + verified filters", () => {
    expect(Value.Check(OpenMatListQuery, { status: "hidden", verified: false, submittedByMe: true })).toBe(true);
  });
  it("OpenMatListQuery accepts a gymId filter", () => {
    expect(Value.Check(OpenMatListQuery, { gymId: "g-123" })).toBe(true);
  });
});
