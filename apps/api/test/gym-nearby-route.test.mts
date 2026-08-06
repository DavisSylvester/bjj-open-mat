import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_gym_nearby_route";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-nearby",
  DEMO_USER_ID: "demo-nearby-user",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "demo-nearby@d.dev",
});
let app: ReturnType<typeof buildApp>;
let base: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("gyms").createIndex({ geo: "2dsphere" });
  await db.collection("gyms").insertOne({
    _id: "g-near" as never,
    name: "Van Alstyne BJJ",
    address: "1 Main St",
    city: "Van Alstyne",
    amenities: [],
    isVerified: true,
    geo: { type: "Point", coordinates: [-96.5486, 33.4292] },
  } as never);
  app = buildApp(createContainer(db, env)).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("GET /api/v1/gyms/nearby", () => {
  it("returns paging meta including effectiveRadiusKm", async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?lat=33.4292&lng=-96.5486&radiusKm=40`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: unknown[]; meta: Record<string, number> };
    expect(body.data).toHaveLength(1);
    expect(body.meta.page).toBe(1);
    expect(body.meta.limit).toBe(20);
    expect(body.meta.total).toBe(1);
    expect(body.meta.effectiveRadiusKm).toBe(40);
  });

  it("400s when neither coordinates nor zip are supplied", async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?radiusKm=40`);
    expect(res.status).toBe(400);
  });

  it("400s on an unresolvable zip", async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=00000&radiusKm=40`);
    expect(res.status).toBe(400);
  });
});
