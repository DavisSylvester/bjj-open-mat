// apps/api/test/class-journal.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import type { ClassJournalEntry, InstructorRating, InstructorRatingSummary, InstructorFeedbackItem } from "@bjj/contract";
import { classJournalRoutes } from "../src/routes/class-journal.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null): { app: Elysia; calls: string[] } {
  const calls: string[] = [];
  const classJournalFacade = {
    upsertJournal: async (u: string, c: string): Promise<ClassJournalEntry> => { calls.push(`journal:${u}:${c}`); return { id: "j1", classId: c, gymId: "g1", userId: u, date: "2026-08-03", techniqueTags: [], shared: false }; },
    myJournal: async (): Promise<ClassJournalEntry[]> => [],
    sharedForOccurrence: async (): Promise<ClassJournalEntry[]> => [],
    rateInstructor: async (u: string, c: string): Promise<InstructorRating> => { calls.push(`rate:${u}:${c}`); return { id: "r1", classId: c, gymId: "g1", date: "2026-08-03", ratedByUserId: u, stars: 5, anonymous: false }; },
    instructorSummary: async (id: string): Promise<InstructorRatingSummary> => { calls.push(`summary:${id}`); return { instructorUserId: id, avg: 0, count: 0 }; },
    gymInstructorFeedback: async (): Promise<InstructorFeedbackItem[]> => [],
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    classJournalFacade,
  } as unknown as Container;
  return { app: new Elysia().use(classJournalRoutes(container)), calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("class journal routes", () => {
  it("GET instructor-rating summary is public", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/users/inst1/instructor-rating"));
    expect(res.status).toBe(200);
    expect(calls).toContain("summary:inst1");
  });
  it("POST journal requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/journal", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST journal calls facade with caller id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/journal", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("journal:u1:c1");
  });
}
);
