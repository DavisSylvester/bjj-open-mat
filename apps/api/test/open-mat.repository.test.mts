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
      verified: true, status: "live",
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
      verified: true, status: "live",
    }, "owner-a");
    await repo.insert({
      id: "om-owner-b", gymId: "g-b", title: "B", startTime: "19:00", endTime: "21:00",
      isRecurring: true, skillLevel: "all", giType: "gi", isCancelled: false, dayOfWeek: 2,
      latitude: 32.9, longitude: -117.2, address: "y", city: "SD", state: "CA",
      verified: true, status: "live",
    }, "owner-b");
    const res = await repo.list({ gymOwnerId: "owner-a" }, 0, 20);
    expect(res.total).toBe(1);
    expect(res.items[0]?.id).toBe("om-owner-a");
    const detail = await repo.findById("om-owner-a");
    expect(detail).not.toBeNull();
    expect((detail as unknown as Record<string, unknown>)["gymOwnerId"]).toBeUndefined();
  });

  it("findNearby excludes hidden sessions", async () => {
    const repo = new OpenMatRepository(db);
    await repo.ensureIndexes();
    const base = { startTime: "19:00", endTime: "21:00", isRecurring: true, skillLevel: "all" as const, giType: "both" as const, isCancelled: false, address: "x", city: "SD", state: "CA", gymId: "g-nearby", hostId: "u1", verified: true };
    // San Diego coordinates
    await repo.insert({ ...base, id: "nearby-live", title: "Live", status: "live" as const, latitude: 32.715, longitude: -117.157 }, "owner-near");
    await repo.insert({ ...base, id: "nearby-hidden", title: "Hidden", status: "hidden" as const, latitude: 32.715, longitude: -117.157 }, "owner-near");
    const results = await repo.findNearby(32.715, -117.157, 50);
    expect(results.some((m) => m.id === "nearby-live")).toBe(true);
    expect(results.some((m) => m.id === "nearby-hidden")).toBe(false);
  });

  it("list excludes hidden and filters by verified + hostId", async () => {
    const repo = new OpenMatRepository(db);
    const base = { startTime: "19:00", endTime: "21:00", isRecurring: true, skillLevel: "all", giType: "both", isCancelled: false, address: "x", city: "SD", state: "CA" } as const;
    await repo.insert({ ...base, id: "v1", gymId: "g1", title: "V", verified: true, status: "live" as const, hostId: "u1" }, "owner1");
    await repo.insert({ ...base, id: "u2", gymId: "g1", title: "U", verified: false, status: "live" as const, hostId: "u2" }, undefined);
    await repo.insert({ ...base, id: "h1", gymId: "g1", title: "H", verified: true, status: "hidden" as const, hostId: "u1" }, "owner1");

    const live = await repo.list({ gymId: "g1" }, 0, 50);
    expect(live.items.find((m) => m.id === "h1")).toBeUndefined(); // hidden excluded by default
    expect(live.items.length).toBe(2);

    const unverified = await repo.list({ gymId: "g1", verified: false }, 0, 50);
    expect(unverified.items.every((m) => m.verified === false)).toBe(true);

    const mine = await repo.list({ gymId: "g1", hostId: "u2" }, 0, 50);
    expect(mine.items.map((m) => m.id)).toEqual(["u2"]);
  });
});
