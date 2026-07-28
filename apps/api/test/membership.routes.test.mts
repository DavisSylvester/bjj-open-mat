// apps/api/test/membership.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { membershipRoutes } from "../src/routes/membership.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";
import type { GymMembership, RosterMember, BeltPromotion } from "@bjj/contract";
import { registerErrorHandler } from "../src/http/error-handler.mts";

// Minimal fake container: stub verifier so a fixed bearer maps to a known identity,
// roleLookup returns practitioner, and membershipFacade records calls.
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const membershipFacade = {
    join: async (u: string, g: string): Promise<GymMembership> => { calls.push(`join:${u}:${g}`); return { id: "m1", gymId: g, userId: u, status: "active", verifiedMember: false, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }; },
    leave: async (): Promise<void> => { calls.push("leave"); },
    roster: async (g: string): Promise<RosterMember[]> => { calls.push(`roster:${g}`); return []; },
    updateMyMembership: async (): Promise<GymMembership> => ({ id: "m1", gymId: "g1", userId: "u1", status: "active", verifiedMember: false, gymRole: "member", isHome: true, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }),
    updateMembership: async (): Promise<GymMembership> => ({ id: "m1", gymId: "g1", userId: "u2", status: "active", verifiedMember: true, gymRole: "coach", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }),
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
  return { app: base.use(membershipRoutes(container)), calls };
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

  it("GET roster is public", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/members"));
    expect(res.status).toBe(200);
    expect(calls).toContain("roster:g1");
  });
});
