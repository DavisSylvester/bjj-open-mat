import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import type { GymClaim } from "@bjj/contract";
import { registerErrorHandler } from "../src/http/error-handler.mts";
import { gymClaimRoutes } from "../src/routes/gym-claim.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

const pending: GymClaim = {
  id: "c1",
  gymId: "g1",
  claimantId: "u1",
  kind: "claim",
  relationship: "owner",
  contact: "me@gym.com",
  message: "I own this",
  status: "pending",
  createdAt: new Date().toISOString(),
};

function testApp(identity: AuthIdentity | null, adminIdentity?: AuthIdentity): { app: Elysia } {
  const gymClaimFacade = {
    submit: async (_uid: string, gymId: string): Promise<GymClaim> => ({ ...pending, gymId }),
    getMyClaimForGym: async (_uid: string, gymId: string): Promise<GymClaim | null> => ({ ...pending, gymId }),
    cancel: async (): Promise<void> => { return; },
    listMyClaims: async (): Promise<GymClaim[]> => [pending],
    approve: async (_adminId: string, claimId: string): Promise<GymClaim> => ({ ...pending, id: claimId, status: "approved" }),
    reject: async (_adminId: string, claimId: string): Promise<GymClaim> => ({ ...pending, id: claimId, status: "rejected" }),
  };

  const container = {
    verifier: {
      verify: async (t?: string): Promise<AuthIdentity | null> => {
        if (!t) return null;
        // "admin-token" resolves to admin identity; any other token resolves to base identity
        if (t === "admin-token" && adminIdentity) return adminIdentity;
        return identity;
      },
    },
    roleLookup: async (userId: string): Promise<"practitioner" | "admin"> => {
      if (userId === "admin1") return "admin";
      return "practitioner";
    },
    gymClaimFacade,
  } as unknown as Container;

  const app = registerErrorHandler(
    new Elysia(),
    { warn: (): void => undefined, error: (): void => undefined },
  ).use(gymClaimRoutes(container));
  return { app };
}

const userIdentity: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };
const adminIdentity: AuthIdentity = { userId: "admin1", role: "admin", email: "admin@x.co", viaBypass: true };

describe("gym claim routes", () => {
  it("submits a claim for an unowned gym", async () => {
    const { app } = testApp(userIdentity);
    const res = await app.handle(new Request("http://local/api/v1/gyms/g1/claims", {
      method: "POST",
      headers: { authorization: "Bearer test-token", "content-type": "application/json" },
      body: JSON.stringify({ relationship: "owner", contact: "me@gym.com", message: "I own this" }),
    }));
    expect(res.status).toBe(200);
    const json = await res.json() as { data: { kind: string; status?: string } };
    expect(json.data.kind).toBe("claim");
  });

  it("returns my latest claim for a gym", async () => {
    const { app } = testApp(userIdentity);
    const res = await app.handle(new Request("http://local/api/v1/gyms/g1/claims/me", {
      headers: { authorization: "Bearer test-token" },
    }));
    expect(res.status).toBe(200);
    const json = await res.json() as { data: { gymId: string } | null };
    expect(json.data?.gymId).toBe("g1");
  });

  it("blocks a non-admin from the admin queue", async () => {
    // userIdentity has role "practitioner" — not admin -> should get 403
    const { app } = testApp(userIdentity, adminIdentity);
    const res = await app.handle(new Request("http://local/api/v1/admin/gym-claims?status=pending", {
      headers: { authorization: "Bearer test-token" },
    }));
    expect(res.status).toBe(403);
  });
});
