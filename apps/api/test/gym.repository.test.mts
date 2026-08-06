import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { GymRepository } from "../src/repositories/gym.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_gyms");
const repo = new GymRepository(db);

// San Diego. ~0.1 km apart so ordering is driven by rankBoost, not distance.
const ORIGIN = { lat: 32.9, lng: -117.21 };

beforeAll(async () => {
  await db.dropDatabase();
  await repo.ensureIndexes();
  await repo.insert({
    id: "g-1", name: "Atos", address: "9587 Distribution Ave", city: "San Diego",
    amenities: [], isVerified: true, location: { lat: 32.901, lng: -117.213 },
    joinCode: "SECRET1", ownerId: "owner-1",
  });
  await repo.insert({
    id: "g-2", name: "Alliance (North)", address: "100 Main St", city: "Poway",
    amenities: [], isVerified: false, location: { lat: 32.902, lng: -117.214 },
    joinCode: "SECRET2", ownerId: "owner-2",
  });
  // Far away — outside every radius used below.
  await repo.insert({
    id: "g-3", name: "Gracie Barra", address: "1 Far Rd", city: "Phoenix",
    amenities: [], isVerified: false, location: { lat: 33.45, lng: -112.07 },
  });
});

afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("GymRepository.searchNearby", () => {
  it("returns gyms in radius with distanceKm, nearest first", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.total).toBe(2);
    expect(r.items.map((g) => g.id)).toEqual(["g-1", "g-2"]);
    expect(r.items[0]?.distanceKm).toBeGreaterThanOrEqual(0);
  });

  it("excludes gyms outside the radius", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.items.some((g) => g.id === "g-3")).toBe(false);
  });

  it("filters by q on name", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: "atos", skip: 0, limit: 20 });
    expect(r.total).toBe(1);
    expect(r.items[0]?.id).toBe("g-1");
  });

  it("filters by q on city", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: "poway", skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(["g-2"]);
  });

  it("treats regex metacharacters in q as literal text", async () => {
    // Unescaped, "(North)" is a capture group and would match "Atos" too.
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: "Alliance (North)", skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(["g-2"]);
  });

  it("orders a boosted gym ahead of a nearer unboosted one", async () => {
    await repo.update("g-2", { rankBoost: 10 } as never);
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(["g-2", "g-1"]);
    await repo.update("g-2", { rankBoost: 0 } as never);
  });

  it("pages: total is the full count, items is the page", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 1 });
    expect(r.total).toBe(2);
    expect(r.items).toHaveLength(1);
  });

  it("never returns joinCode or ownerId", async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    for (const gym of r.items) {
      expect(gym.joinCode).toBeUndefined();
      expect(gym.ownerId).toBeUndefined();
    }
  });
});
