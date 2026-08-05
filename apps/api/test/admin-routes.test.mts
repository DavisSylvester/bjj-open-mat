import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_admin_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-admin",
  DEMO_USER_ID: "demo-admin-user",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "demo-admin@d.dev",
});
let app: ReturnType<typeof buildApp>;
let base: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("users").insertOne({
    _id: "u-1" as never,
    email: "a@b.dev",
    displayName: "A",
    createdAt: "2026-08-01T00:00:00.000Z",
  } as never);
  await db.collection("gyms").insertOne({
    _id: "g-1" as never,
    name: "G",
    address: "A",
    state: "TX",
    amenities: [],
    isVerified: false,
  } as never);
  await db.collection("gymMemberships").insertOne({
    _id: "m-1" as never,
    id: "m-1",
    gymId: "g-1",
    userId: "u-1",
    verifiedMember: false,
    isHome: true,
    visibleInRoster: true,
    joinedAt: "2026-08-01T00:00:00.000Z",
  } as never);
  const c = createContainer(db, env);
  app = buildApp(c).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("admin routes (unauthenticated)", () => {
  it("GET /api/v1/admin/stats/overview returns totals without auth", async () => {
    const res = await fetch(`${base}/api/v1/admin/stats/overview`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { totalGyms: number } };
    expect(body.data.totalGyms).toBe(1);
  });

  it("GET /api/v1/admin/users returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/users?page=1&limit=20`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("GET /api/v1/admin/gyms returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms?page=1&limit=20`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("POST /api/v1/admin/gyms/:id/verify sets isVerified", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms/g-1/verify`, { method: "POST" });
    const body = await res.json() as { data: { isVerified: boolean } };
    expect(body.data.isVerified).toBe(true);
  });

  it("GET /api/v1/admin/memberships returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/memberships?page=1&limit=20`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("PATCH /api/v1/admin/memberships/:gymId/:userId sets status", async () => {
    // Relies on seeded gym g-1 having no ownerId, so the owner guard rail
    // (a gym's owner cannot be hidden/deactivated) does not fire for u-1.
    const res = await fetch(`${base}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ status: "hidden" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { status: string; statusUpdatedBy: string } };
    expect(body.data.status).toBe("hidden");
    expect(body.data.statusUpdatedBy).toBe("admin");
  });

  it("PATCH /api/v1/admin/memberships rejects pending", async () => {
    const res = await fetch(`${base}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ status: "pending" }),
    });
    // The app's global error handler normalizes every VALIDATION failure to 400
    // (apps/api/src/http/error-handler.mts:17), not 422.
    expect(res.status).toBe(400);
  });

  it("a hidden member drops out of the public roster", async () => {
    // Runs after the PATCH above, which set m-1 to hidden.
    const res = await fetch(`${base}/api/v1/gyms/g-1/members`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string }[] };
    expect(body.data.map((r) => r.userId)).not.toContain("u-1");
  });

  it("includeHidden without a manager token is refused", async () => {
    const res = await fetch(`${base}/api/v1/gyms/g-1/members?includeHidden=true`);
    expect(res.status).toBe(401);
  });
});
