import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { MongoClient } from "mongodb";
import { deviceRoutes } from "../src/routes/device.routes.mts";
import { DeviceTokenRepository } from "../src/repositories/device-token.repository.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";
import { registerErrorHandler } from "../src/http/error-handler.mts";

const TEST_URI = process.env["TEST_MONGODB_URI"] ?? "mongodb://localhost:27021";

async function withDb<T>(fn: (deviceTokenRepo: DeviceTokenRepository) => Promise<T>): Promise<T> {
  const client = new MongoClient(TEST_URI);
  await client.connect();
  const db = client.db(`device_routes_test_${Date.now()}`);
  const repo = new DeviceTokenRepository(db);
  await repo.ensureIndexes();
  try {
    return await fn(repo);
  } finally {
    await db.dropDatabase();
    await client.close();
  }
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function testApp(identity: AuthIdentity | null, deviceTokenRepo: DeviceTokenRepository) {
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    deviceTokenRepo,
    id: (): string => `id-${Math.random().toString(36).slice(2)}`,
  } as unknown as Container;
  return registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined }).use(deviceRoutes(container));
}

const callerIdentity: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("device routes", () => {
  it("POST /api/v1/devices upserts a token for the caller", async () => {
    await withDb(async (deviceTokenRepo) => {
      const app = testApp(callerIdentity, deviceTokenRepo);
      const res = await app.handle(new Request("http://localhost/api/v1/devices", {
        method: "POST",
        headers: { authorization: "Bearer t", "content-type": "application/json" },
        body: JSON.stringify({ token: "abc", platform: "ios" }),
      }));
      expect(res.status).toBe(200);
      const rows = await deviceTokenRepo.listByUser("u1");
      expect(rows.map((r) => r.token)).toContain("abc");
    });
  });

  // registerErrorHandler converts Elysia VALIDATION errors from 422 → 400
  it("POST rejects an invalid platform with 400", async () => {
    await withDb(async (deviceTokenRepo) => {
      const app = testApp(callerIdentity, deviceTokenRepo);
      const res = await app.handle(new Request("http://localhost/api/v1/devices", {
        method: "POST",
        headers: { authorization: "Bearer t", "content-type": "application/json" },
        body: JSON.stringify({ token: "abc", platform: "web" }),
      }));
      expect(res.status).toBe(400);
    });
  });

  it("POST /api/v1/devices requires authentication", async () => {
    await withDb(async (deviceTokenRepo) => {
      const app = testApp(null, deviceTokenRepo);
      const res = await app.handle(new Request("http://localhost/api/v1/devices", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ token: "abc", platform: "ios" }),
      }));
      expect(res.status).toBe(401);
    });
  });

  it("DELETE /api/v1/devices/:token removes the token", async () => {
    await withDb(async (deviceTokenRepo) => {
      const app = testApp(callerIdentity, deviceTokenRepo);
      // First register
      await app.handle(new Request("http://localhost/api/v1/devices", {
        method: "POST",
        headers: { authorization: "Bearer t", "content-type": "application/json" },
        body: JSON.stringify({ token: "tok-del", platform: "android" }),
      }));
      // Then delete
      const res = await app.handle(new Request("http://localhost/api/v1/devices/tok-del", {
        method: "DELETE",
        headers: { authorization: "Bearer t" },
      }));
      expect(res.status).toBe(200);
      const body = await res.json() as { data: { registered: boolean } };
      expect(body.data.registered).toBe(false);
      const rows = await deviceTokenRepo.listByUser("u1");
      expect(rows.map((r) => r.token)).not.toContain("tok-del");
    });
  });
});
