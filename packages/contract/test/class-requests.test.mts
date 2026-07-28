import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CreateClassRequest, OccurrenceOverrideRequest, ScheduleQuery, ScheduledClass } from "../src/index.mjs";

describe("class requests", () => {
  it("CreateClassRequest requires core fields", () => {
    expect(Value.Check(CreateClassRequest, {
      title: "Fundamentals", classType: "fundamentals", giType: "gi", skillLevel: "beginner",
      dayOfWeek: 1, startTime: "18:00", endTime: "19:00",
    })).toBe(true);
    expect(Value.Check(CreateClassRequest, { classType: "gi" })).toBe(false); // missing title/times
  });
  it("OccurrenceOverrideRequest is all-optional", () => {
    expect(Value.Check(OccurrenceOverrideRequest, {})).toBe(true);
    expect(Value.Check(OccurrenceOverrideRequest, { status: "cancelled" })).toBe(true);
  });
  it("ScheduleQuery requires from and to", () => {
    expect(Value.Check(ScheduleQuery, { from: "2026-08-01", to: "2026-08-07" })).toBe(true);
    expect(Value.Check(ScheduleQuery, { from: "2026-08-01" })).toBe(false);
  });
  it("ScheduledClass carries goingCount", () => {
    expect(Value.Check(ScheduledClass, {
      classId: "c1", gymId: "g1", date: "2026-08-03", title: "F", classType: "gi",
      giType: "gi", skillLevel: "all", startTime: "18:00", endTime: "19:00",
      status: "scheduled", goingCount: 3,
    })).toBe(true);
  });
});
