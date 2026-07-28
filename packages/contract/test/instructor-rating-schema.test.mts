import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { InstructorRating, InstructorRatingSummary, UpsertInstructorRatingRequest } from "../src/index.mts";

describe("InstructorRating", () => {
  it("parses with default anonymous false", () => {
    const r = Value.Parse(InstructorRating, {
      id: "r1", classId: "c1", gymId: "g1", date: "2026-08-03",
      ratedByUserId: "u1", stars: 5,
    });
    expect(r.anonymous).toBe(false);
  });
  it("rejects stars out of range", () => {
    expect(Value.Check(InstructorRating, {
      id: "r1", classId: "c1", gymId: "g1", date: "2026-08-03", ratedByUserId: "u1", stars: 0, anonymous: false,
    })).toBe(false);
  });
});

describe("UpsertInstructorRatingRequest", () => {
  it("requires date + stars", () => {
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03", stars: 4 })).toBe(true);
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03" })).toBe(false);
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03", stars: 6 })).toBe(false);
  });
});

describe("InstructorRatingSummary", () => {
  it("carries avg + count", () => {
    expect(Value.Check(InstructorRatingSummary, { instructorUserId: "i1", avg: 4.5, count: 12 })).toBe(true);
  });
});
