import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { GymRepository } from "../src/repositories/gym.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_gyms");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("GymRepository", () => {
  it("inserts and finds nearby with distanceKm", async () => {
    const repo = new GymRepository(db);
    await repo.ensureIndexes();
    await repo.insert({
      id: "g-1", name: "Atos", address: "9587 Distribution Ave",
      amenities: [], isVerified: true, location: { lat: 32.901, lng: -117.213 },
    });
    const near = await repo.findNearby(32.9, -117.21, 25);
    expect(near[0]?.id).toBe("g-1");
    expect(near[0]?.distanceKm).toBeGreaterThanOrEqual(0);
  });
});
