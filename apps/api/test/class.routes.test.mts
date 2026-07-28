import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import type { GymClass, ClassOccurrence } from "@bjj/contract";
import { classRoutes } from "../src/routes/class.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";
import { registerErrorHandler } from "../src/http/error-handler.mts";
import type { ClassAttendee } from "../src/facades/class.facade.mts";

function testApp(identity: AuthIdentity | null): { app: Elysia; calls: string[] } {
  const calls: string[] = [];
  const gymClass: GymClass = { id: "c1", gymId: "g1", title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00", status: "active" };
  const occurrence: ClassOccurrence = { id: "o1", classId: "c1", gymId: "g1", date: "2026-08-10", status: "cancelled" };
  const classFacade = {
    create: async (u: string, g: string): Promise<GymClass> => { calls.push(`create:${u}:${g}`); return { ...gymClass, gymId: g }; },
    listDefinitions: async (g: string): Promise<GymClass[]> => { calls.push(`defs:${g}`); return []; },
    schedule: async (g: string, from: string, to: string): Promise<[]> => { calls.push(`sched:${g}:${from}:${to}`); return []; },
    update: async (): Promise<GymClass> => gymClass,
    archive: async (): Promise<void> => { calls.push("archive"); },
    overrideOccurrence: async (): Promise<ClassOccurrence> => occurrence,
    rsvp: async (u: string, c: string, d: string): Promise<void> => { calls.push(`rsvp:${u}:${c}:${d}`); },
    unrsvp: async (): Promise<void> => { calls.push("unrsvp"); },
    attendees: async (): Promise<ClassAttendee[]> => [],
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    classFacade,
  } as unknown as Container;
  const base = registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined });
  return { app: base.use(classRoutes(container)), calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("class routes", () => {
  it("GET schedule is public and passes the range", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/schedule?from=2026-08-01&to=2026-08-07"));
    expect(res.status).toBe(200);
    expect(calls).toContain("sched:g1:2026-08-01:2026-08-07");
  });
  it("POST create requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/classes", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST rsvp calls the facade with the caller id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/rsvp", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" },
      body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("rsvp:u1:c1:2026-08-03");
  });
});
