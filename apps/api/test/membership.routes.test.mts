// apps/api/test/membership.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { membershipRoutes } from "../src/routes/membership.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";
import type { GymMembership, RosterMember, BeltPromotion, UpdateMembershipRequest } from "@bjj/contract";
import { registerErrorHandler } from "../src/http/error-handler.mts";

// Minimal fake container: stub verifier so a fixed bearer maps to a known identity,
// roleLookup returns practitioner, and membershipFacade records calls.
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const updateMembershipBodies: UpdateMembershipRequest[] = [];
  const membershipFacade = {
    join: async (u: string, g: string): Promise<GymMembership> => { calls.push(`join:${u}:${g}`); return { id: "m1", gymId: g, userId: u, status: "active", verifiedMember: false, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }; },
    leave: async (): Promise<void> => { calls.push("leave"); },
    roster: async (g: string, incl?: boolean, caller?: { userId: string }): Promise<RosterMember[]> => {
      calls.push(`roster:${g}:${String(incl ?? false)}:${caller?.userId ?? "anon"}`);
      return [];
    },
    updateMyMembership: async (): Promise<GymMembership> => ({ id: "m1", gymId: "g1", userId: "u1", status: "active", verifiedMember: false, gymRole: "member", isHome: true, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }),
    updateMembership: async (_callerId: string, _gymId: string, _targetUserId: string, req: UpdateMembershipRequest): Promise<GymMembership> => {
      updateMembershipBodies.push(req);
      return { id: "m1", gymId: "g1", userId: "u2", status: "active", verifiedMember: true, gymRole: "coach", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" };
    },
    promote: async (): Promise<BeltPromotion> => ({ id: "p1", userId: "u2", gymId: "g1", beltRank: "blue", beltStripes: 1, promotedByUserId: "u1", promotedAt: "t" }),
    listPromotions: async (): Promise<BeltPromotion[]> => [],
    listMyMemberships: async (): Promise<GymMembership[]> => [],
  };
  const container = {
    verifier: { verify: async (token?: string): Promise<AuthIdentity | null> => (token ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    membershipFacade,
  } as unknown as Container;
  const base = registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined });
  return { app: base.use(membershipRoutes(container)), calls, updateMembershipBodies };
}

const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("membership routes", () => {
  it("POST join requires auth (401 without token)", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members", { method: "POST" }));
    expect(res.status).toBe(401);
  });

  it("POST join calls the facade with the caller's id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members", {
      method: "POST", headers: { authorization: "Bearer t" },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("join:u1:g1");
  });

  it("GET roster without includeHidden calls the facade in public mode", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members"));
    expect(res.status).toBe(200);
    expect(calls).toContain("roster:g1:false:anon");
  });

  it("GET roster passes includeHidden and the caller through", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members?includeHidden=true", {
      headers: { authorization: "Bearer t" },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("roster:g1:true:u1");
  });

  it("GET roster treats a truthy-looking but non-'true' includeHidden as public", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members?includeHidden=1", {
      headers: { authorization: "Bearer t" },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("roster:g1:false:u1");
  });

  it("PATCH member forwards a status change", async () => {
    const { app, updateMembershipBodies } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members/u2", {
      method: "PATCH",
      headers: { authorization: "Bearer t", "content-type": "application/json" },
      body: JSON.stringify({ status: "hidden" }),
    }));
    expect(res.status).toBe(200);
    expect(updateMembershipBodies).toHaveLength(1);
    expect(updateMembershipBodies[0]).toMatchObject({ status: "hidden" });
  });

  it("PATCH member rejects pending as a status", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members/u2", {
      method: "PATCH",
      headers: { authorization: "Bearer t", "content-type": "application/json" },
      body: JSON.stringify({ status: "pending" }),
    }));
    // NOTE: the brief expected 422 for TypeBox validation failures, but this repo's
    // global error handler (apps/api/src/http/error-handler.mts, out of scope for
    // this task) maps every VALIDATION-coded error to 400. Asserting the app's
    // actual, already-established convention rather than the brief's assumption.
    expect(res.status).toBe(400);
  });
});
