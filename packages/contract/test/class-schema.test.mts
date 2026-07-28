import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymClass, ClassOccurrence } from "../src/index.mjs";

describe("GymClass schema", () => {
  it("parses a recurring class with defaults", () => {
    const c = Value.Parse(GymClass, {
      id: "c1", gymId: "g1", title: "Fundamentals", classType: "fundamentals",
      giType: "gi", skillLevel: "beginner", dayOfWeek: 1, startTime: "18:00", endTime: "19:00",
    });
    expect(c.isRecurring).toBe(true);
    expect(c.status).toBe("active");
  });
  it("rejects dayOfWeek out of range", () => {
    expect(Value.Check(GymClass, {
      id: "c1", gymId: "g1", title: "x", classType: "gi", giType: "gi", skillLevel: "all",
      dayOfWeek: 7, startTime: "18:00", endTime: "19:00",
    })).toBe(false);
  });
});

describe("ClassOccurrence schema", () => {
  it("defaults status to scheduled", () => {
    const o = Value.Parse(ClassOccurrence, { id: "o1", classId: "c1", gymId: "g1", date: "2026-08-03" });
    expect(o.status).toBe("scheduled");
  });
});
