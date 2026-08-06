/**
 * End-to-end gate for gym search. Boots the real app against a real MongoDB and
 * drives it over HTTP — no stubs — because the behaviour under test spans ZIP
 * geocoding, the geo pipeline, and the widening policy, and a stub at any of
 * those seams would prove nothing.
 *
 * The required scenario: search ZIP 75495 (Van Alstyne, TX) at 25 miles, find
 * nothing, and auto-expand to 50 miles.
 */
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_gym_search_e2e";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-gym-search-e2e",
  DEMO_USER_ID: "demo-gym-search-user",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "demo-gym-search@d.dev",
});

// 75495 → Van Alstyne, TX. Same fix the mobile e2e mocks.
const RADIUS_25_MI_KM = 40;

let app: ReturnType<typeof buildApp>;
let base: string;

interface SearchBody {
  data: { id: string; name: string; distanceKm: number; joinCode?: string; ownerId?: string }[];
  meta: { page: number; limit: number; total: number; effectiveRadiusKm: number };
}

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.dropDatabase();
  await db.collection("gyms").createIndex({ geo: "2dsphere" });
  await db.collection("gyms").insertMany([
    {
      // Plano, TX — ~62 km from Van Alstyne. Outside 25 mi, inside 50 mi.
      _id: "g-plano" as never,
      name: "Plano Jiu-Jitsu",
      address: "1000 Legacy Dr",
      city: "Plano",
      amenities: ["showers"],
      isVerified: true,
      joinCode: "PLANO-SECRET",
      ownerId: "owner-plano",
      geo: { type: "Point", coordinates: [-96.6989, 33.0198] },
    },
    {
      // Austin, TX — ~330 km away. Outside every rung of the ladder.
      _id: "g-austin" as never,
      name: "Austin BJJ",
      address: "1 Congress Ave",
      city: "Austin",
      amenities: [],
      isVerified: false,
      geo: { type: "Point", coordinates: [-97.7431, 30.2672] },
    },
  ] as never);
  app = buildApp(createContainer(db, env)).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("gym search E2E — ZIP 75495", () => {
  it("expands from 25 to 50 miles to find the nearest gym", async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=75495&radiusKm=${RADIUS_25_MI_KM}`);
    expect(res.status).toBe(200);

    const body = await res.json() as SearchBody;

    // The search widened: 40 km found nothing, 80 km did.
    expect(body.meta.effectiveRadiusKm).toBe(80);

    const ids = body.data.map((g) => g.id);
    expect(ids).toContain("g-plano");
    expect(ids).not.toContain("g-austin");

    const plano = body.data.find((g) => g.id === "g-plano");
    expect(plano?.distanceKm).toBeGreaterThan(RADIUS_25_MI_KM);
    expect(plano?.distanceKm).toBeLessThan(80);

    // The public search projection must never leak the roster-join secret.
    expect(plano?.joinCode).toBeUndefined();
    expect(plano?.ownerId).toBeUndefined();
  });

  it("exhausts the ladder and returns empty when nothing is in range", async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=75495&radiusKm=${RADIUS_25_MI_KM}&q=nonexistent-gym`);
    expect(res.status).toBe(200);

    const body = await res.json() as SearchBody;
    expect(body.data).toHaveLength(0);
    expect(body.meta.total).toBe(0);
    expect(body.meta.effectiveRadiusKm).toBe(160);
  });
});
