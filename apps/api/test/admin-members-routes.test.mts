import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_admin_members_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });

const adminEnv = loadEnv({
  MONGODB_URI: uri, MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-admin",
  DEMO_USER_ID: "u-admin",
  // Not "admin": env.mts forbids it, so the role is promoted from the seeded
  // u-admin record by authPlugin's roleLookup.
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "admin@e.dev",
});
const memberEnv = loadEnv({
  MONGODB_URI: uri, MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-member",
  DEMO_USER_ID: "u-1",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "u1@e.dev",
});

const adminAuth = { Authorization: "Bearer secret-admin" };
let app: ReturnType<typeof buildApp>;
let memberApp: ReturnType<typeof buildApp>;
let base: string;
let memberBase: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  // Seed both `id` and `_id`: UserRepository.insert writes `{ ...user, _id: user.id }`,
  // and stripId only drops `_id` — it never derives `id`. A fixture with only `_id`
  // does not match production and makes `userId` come back undefined.
  await db.collection("users").insertMany([
    { _id: "u-admin", id: "u-admin", email: "admin@e.dev", displayName: "Admin", role: "admin", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-1", id: "u-1", email: "u1@e.dev", displayName: "One", role: "practitioner", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-orphan", id: "u-orphan", email: "orphan@e.dev", displayName: "Orphan", role: "practitioner", createdAt: "2026-08-02T00:00:00.000Z" },
  ] as never);
  await db.collection("gyms").insertMany([
    { _id: "g-1", id: "g-1", name: "Renzo Dallas", address: "A", state: "TX", amenities: [], isVerified: true },
    { _id: "g-2", id: "g-2", name: "Nowhere BJJ", address: "B", amenities: [], isVerified: false },
    { _id: "g-3", id: "g-3", name: "Empty Gym", address: "C", state: "CA", amenities: [], isVerified: false },
  ] as never);
  await db.collection("gymMemberships").insertMany([
    { _id: "m-1", id: "m-1", gymId: "g-1", userId: "u-1", status: "pending", verifiedMember: false, isHome: false, visibleInRoster: true, joinedAt: "2026-08-01T00:00:00.000Z" },
    { _id: "m-2", id: "m-2", gymId: "g-2", userId: "u-1", status: "active", verifiedMember: false, isHome: true, visibleInRoster: true, joinedAt: "2026-08-01T00:00:00.000Z" },
  ] as never);
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

const PATHS = [
  "/api/v1/admin/members/tree",
  "/api/v1/admin/gyms/g-1/members?page=1&limit=50",
  "/api/v1/admin/members/no-gym?page=1&limit=50",
];

describe("admin members routes are guarded", () => {
  for (const path of PATHS) {
    it(`GET ${path} is 401 without a token`, async () => {
      expect((await fetch(`${base}${path}`)).status).toBe(401);
    });
    it(`GET ${path} is 403 for a practitioner`, async () => {
      const res = await fetch(`${memberBase}${path}`, { headers: { Authorization: "Bearer secret-member" } });
      expect(res.status).toBe(403);
    });
  }
});

describe("GET /api/v1/admin/members/tree", () => {
  it("groups by state, buckets a stateless gym, omits an empty gym", async () => {
    const res = await fetch(`${base}/api/v1/admin/members/tree`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { states: { state: string; gyms: { id: string; memberCount: number; pendingCount: number }[] }[]; noState: { id: string }[]; noGym: { userCount: number } } };
    expect(body.data.states.map((s) => s.state)).toEqual(["TX"]);
    expect(body.data.states[0]!.gyms[0]!.id).toBe("g-1");
    expect(body.data.states[0]!.gyms[0]!.pendingCount).toBe(1);
    expect(body.data.noState.map((g) => g.id)).toEqual(["g-2"]);
    const allIds = [...body.data.states.flatMap((s) => s.gyms.map((g) => g.id)), ...body.data.noState.map((g) => g.id)];
    expect(allIds).not.toContain("g-3");
    expect(body.data.noGym.userCount).toBe(2); // u-admin and u-orphan have no memberships
  });
});

describe("GET /api/v1/admin/gyms/:gymId/members", () => {
  it("returns pending rows enriched with the user's name", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms/g-1/members?page=1&limit=50`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string; displayName: string; status: string }[]; meta: { total: number } };
    expect(body.meta.total).toBe(1);
    expect(body.data[0]!.displayName).toBe("One");
    expect(body.data[0]!.status).toBe("pending");
  });
});

describe("GET /api/v1/admin/members/no-gym", () => {
  it("lists users with no membership anywhere", async () => {
    const res = await fetch(`${base}/api/v1/admin/members/no-gym?page=1&limit=50`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string }[]; meta: { total: number } };
    expect(body.data.map((r) => r.userId).sort()).toEqual(["u-admin", "u-orphan"]);
    expect(body.meta.total).toBe(2);
  });
});
