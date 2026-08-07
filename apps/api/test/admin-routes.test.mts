import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_admin_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });

// Two apps over one database, because a verifier holds a single bypass secret
// and therefore a single demo identity. One app authenticates as an admin, the
// other as a practitioner, which is what lets the 401/403/200 ladder be tested
// against the same seeded data.
const adminEnv = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-admin",
  DEMO_USER_ID: "u-admin",
  // Not "admin": the env schema deliberately excludes it, so the bypass secret
  // alone cannot mint an admin. The role is promoted by authPlugin's roleLookup
  // from the seeded u-admin user record, which is where admin actually lives.
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "demo-admin@d.dev",
});
const memberEnv = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-member",
  DEMO_USER_ID: "u-1",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "a@b.dev",
});

const adminAuth = { Authorization: "Bearer secret-admin" };
const adminJson = { ...adminAuth, "content-type": "application/json" };

let app: ReturnType<typeof buildApp>;
let memberApp: ReturnType<typeof buildApp>;
let base: string;
let memberBase: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("users").insertOne({
    _id: "u-1" as never,
    email: "a@b.dev",
    displayName: "A",
    role: "practitioner",
    createdAt: "2026-08-01T00:00:00.000Z",
  } as never);
  await db.collection("users").insertOne({
    _id: "u-admin" as never,
    email: "demo-admin@d.dev",
    displayName: "Admin",
    role: "admin",
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
  app = buildApp(createContainer(db, adminEnv)).listen(0);
  memberApp = buildApp(createContainer(db, memberEnv)).listen(0);
  base = `http://localhost:${app.server?.port}`;
  memberBase = `http://localhost:${memberApp.server?.port}`;
});

afterAll(async () => {
  app.stop();
  memberApp.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

// Every /api/v1/admin/* route must be closed to anonymous callers. These ran
// unauthenticated in production until 2026-08-06: the router was mounted in
// app.mts without authPlugin, so the whole surface — including the user list
// and every write — was reachable with no token at all.
describe("admin routes reject unauthenticated callers", () => {
  const routes: ReadonlyArray<readonly [string, string, unknown?]> = [
    ["GET", "/api/v1/admin/stats/overview"],
    ["GET", "/api/v1/admin/stats/open-mats-by-state"],
    ["GET", "/api/v1/admin/users?page=1&limit=20"],
    ["GET", "/api/v1/admin/gyms?page=1&limit=20"],
    ["GET", "/api/v1/admin/open-mats?page=1&limit=20"],
    ["GET", "/api/v1/admin/memberships?page=1&limit=20"],
    ["POST", "/api/v1/admin/gyms", { name: "X", address: "Y" }],
    ["PUT", "/api/v1/admin/gyms/g-1", { name: "X" }],
    ["POST", "/api/v1/admin/gyms/g-1/verify"],
    ["POST", "/api/v1/admin/gyms/g-1/owner", { userId: "u-1" }],
    ["POST", "/api/v1/admin/gyms/g-1/invite", { emails: ["x@y.dev"] }],
    ["PATCH", "/api/v1/admin/memberships/g-1/u-1", { status: "hidden" }],
    ["PUT", "/api/v1/admin/open-mats/om-1", { title: "X" }],
  ];

  for (const [method, path, body] of routes) {
    it(`${method} ${path} is 401 without a token`, async () => {
      const res = await fetch(`${base}${path}`, {
        method,
        ...(body === undefined
          ? {}
          : { headers: { "content-type": "application/json" }, body: JSON.stringify(body) }),
      });
      expect(res.status).toBe(401);
    });
  }
});

describe("admin routes reject authenticated non-admins", () => {
  it("GET /api/v1/admin/users is 403 for a practitioner", async () => {
    const res = await fetch(`${memberBase}/api/v1/admin/users?page=1&limit=20`, {
      headers: { Authorization: "Bearer secret-member" },
    });
    expect(res.status).toBe(403);
  });

  it("PATCH /api/v1/admin/memberships is 403 for a practitioner", async () => {
    const res = await fetch(`${memberBase}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: { Authorization: "Bearer secret-member", "content-type": "application/json" },
      body: JSON.stringify({ status: "hidden" }),
    });
    expect(res.status).toBe(403);
  });

  it("an invalid token is 401, not 500", async () => {
    const res = await fetch(`${base}/api/v1/admin/users?page=1&limit=20`, {
      headers: { Authorization: "Bearer not-the-secret" },
    });
    expect(res.status).toBe(401);
  });
});

describe("admin routes serve an admin identity", () => {
  it("GET /api/v1/admin/stats/overview returns totals", async () => {
    const res = await fetch(`${base}/api/v1/admin/stats/overview`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { totalGyms: number } };
    expect(body.data.totalGyms).toBe(1);
  });

  it("GET /api/v1/admin/users returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/users?page=1&limit=20`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("GET /api/v1/admin/gyms returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms?page=1&limit=20`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("POST /api/v1/admin/gyms/:id/verify sets isVerified", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms/g-1/verify`, {
      method: "POST",
      headers: adminAuth,
    });
    const body = await res.json() as { data: { isVerified: boolean } };
    expect(body.data.isVerified).toBe(true);
  });

  it("GET /api/v1/admin/memberships returns a non-empty list", async () => {
    const res = await fetch(`${base}/api/v1/admin/memberships?page=1&limit=20`, {
      headers: adminAuth,
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[] };
    expect(body.data.length).toBeGreaterThan(0);
  });

  it("PATCH /api/v1/admin/memberships/:gymId/:userId sets status", async () => {
    // Relies on seeded gym g-1 having no ownerId, so the owner guard rail
    // (a gym's owner cannot be hidden/deactivated) does not fire for u-1.
    const res = await fetch(`${base}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: adminJson,
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
      headers: adminJson,
      body: JSON.stringify({ status: "pending" }),
    });
    // The app's global error handler normalizes every VALIDATION failure to 400
    // (apps/api/src/http/error-handler.mts:17), not 422.
    expect(res.status).toBe(400);
  });
});

describe("public roster still reflects admin-set status", () => {
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
