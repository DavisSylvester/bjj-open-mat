import { describe, expect, it } from "bun:test";
import { insertSessions, type InsertApi } from "../lib/insert-core.mjs";
import type { ResolvedSession } from "../lib/resolve-core.mjs";

const s: ResolvedSession = {
  title: "Atos Open Mat", startTime: "10:00", endTime: "12:00", dayOfWeek: 0, isRecurring: true,
  giType: "both", skillLevel: "all", feeCents: 0, gymId: "g1", sourceUrl: "u", gymNameForLog: "Atos",
};

describe("insertSessions", () => {
  it("dry run creates nothing and reports the plan", async () => {
    const calls: string[] = [];
    const api: InsertApi = { createSession: async () => { calls.push("post"); return { id: "x", verified: false }; } };
    const log = await insertSessions([s], api, false);
    expect(calls).toHaveLength(0);
    expect(log.planned).toBe(1);
    expect(log.inserted).toHaveLength(0);
  });

  it("commit run POSTs and records id + verified status", async () => {
    const api: InsertApi = { createSession: async () => ({ id: "new1", verified: false }) };
    const log = await insertSessions([s], api, true);
    expect(log.inserted).toEqual([{ id: "new1", verified: false, gymName: "Atos", sourceUrl: "u" }]);
  });

  it("continues past a failed insert and records the error", async () => {
    const api: InsertApi = { createSession: async () => { throw new Error("boom"); } };
    const log = await insertSessions([s], api, true);
    expect(log.inserted).toHaveLength(0);
    expect(log.errors).toHaveLength(1);
    expect(log.errors[0].error).toContain("boom");
  });
});
