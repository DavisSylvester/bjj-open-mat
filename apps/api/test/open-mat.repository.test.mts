import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_openmats");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("OpenMatRepository", () => {
  it("inserts a detail doc and filters by dayOfWeek", async () => {
    const repo = new OpenMatRepository(db);
    await repo.ensureIndexes();
    await repo.insert({
      id: "om-1", gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00",
      isRecurring: true, skillLevel: "all", giType: "gi", isCancelled: false, dayOfWeek: 5,
      latitude: 32.9, longitude: -117.2, address: "x", city: "SD", state: "CA",
    }, "owner-1");
    const res = await repo.list({ dayOfWeek: 5 }, 0, 20);
    expect(res.total).toBe(1);
    expect(res.items[0]?.giType).toBe("gi");
    const detail = await repo.findById("om-1");
    expect(detail?.address).toBe("x");
  });

  it("filters by gymOwnerId returning only that owner's mats", async () => {
    const repo = new OpenMatRepository(db);
    await repo.ensureIndexes();
    await repo.insert({
      id: "om-owner-a", gymId: "g-a", title: "A", startTime: "19:00", endTime: "21:00",
      isRecurring: true, skillLevel: "all", giType: "gi", isCancelled: false, dayOfWeek: 1,
      latitude: 32.9, longitude: -117.2, address: "x", city: "SD", state: "CA",
    }, "owner-a");
    await repo.insert({
      id: "om-owner-b", gymId: "g-b", title: "B", startTime: "19:00", endTime: "21:00",
      isRecurring: true, skillLevel: "all", giType: "gi", isCancelled: false, dayOfWeek: 2,
      latitude: 32.9, longitude: -117.2, address: "y", city: "SD", state: "CA",
    }, "owner-b");
    const res = await repo.list({ gymOwnerId: "owner-a" }, 0, 20);
    expect(res.total).toBe(1);
    expect(res.items[0]?.id).toBe("om-owner-a");
    const detail = await repo.findById("om-owner-a");
    expect(detail).not.toBeNull();
    expect((detail as unknown as Record<string, unknown>)["gymOwnerId"]).toBeUndefined();
  });
});
