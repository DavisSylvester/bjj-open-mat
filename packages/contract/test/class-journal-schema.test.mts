import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ClassJournalEntry, UpsertJournalRequest } from "../src/index.mts";

describe("ClassJournalEntry schema", () => {
  it("parses a minimal entry with defaults", () => {
    const e = Value.Parse(ClassJournalEntry, {
      id: "j1", classId: "c1", gymId: "g1", userId: "u1", date: "2026-08-03",
    });
    expect(e.techniqueTags).toEqual([]);
    expect(e.shared).toBe(false);
  });
  it("rejects intensity above 5", () => {
    expect(Value.Check(ClassJournalEntry, {
      id: "j1", classId: "c1", gymId: "g1", userId: "u1", date: "2026-08-03",
      techniqueTags: [], shared: false, intensity: 6,
    })).toBe(false);
  });
});

describe("UpsertJournalRequest", () => {
  it("requires date, everything else optional", () => {
    expect(Value.Check(UpsertJournalRequest, { date: "2026-08-03" })).toBe(true);
    expect(Value.Check(UpsertJournalRequest, {})).toBe(false);
    expect(Value.Check(UpsertJournalRequest, { date: "2026-08-03", techniqueTags: ["armbar"], shared: true })).toBe(true);
  });
});
