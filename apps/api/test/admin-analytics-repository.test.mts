// apps/api/test/admin-analytics-repository.test.mts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { AdminAnalyticsRepository } from "../src/repositories/admin-analytics.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_admin_analytics");
const NOW = new Date("2026-08-01T12:00:00.000Z");

beforeAll(async () => {
  await db.collection("users").insertMany([
    { _id: "u-today", email: "t@x.dev", displayName: "T", createdAt: "2026-08-01T01:00:00.000Z" },
    { _id: "u-5d", email: "f@x.dev", displayName: "F", createdAt: "2026-07-27T00:00:00.000Z" },
    { _id: "u-old", email: "o@x.dev", displayName: "O", createdAt: "2025-12-01T00:00:00.000Z" },
  ] as never);
  await db.collection("gyms").insertMany([
    { _id: "g-tx", name: "TX Gym", address: "A", state: "TX", amenities: [], isVerified: false },
    { _id: "g-ca", name: "CA Gym", address: "B", state: "CA", amenities: [], isVerified: false },
  ] as never);
  await db.collection("openMats").insertMany([
    { _id: "om-1", gymId: "g-tx", title: "1", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
    { _id: "om-2", gymId: "g-tx", title: "2", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
    { _id: "om-3", gymId: "g-ca", title: "3", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
  ] as never);
});
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("AdminAnalyticsRepository", () => {
  it("counts signups per window relative to now", async () => {
    const repo = new AdminAnalyticsRepository(db);
    const w = await repo.signupWindows(NOW);
    expect(w.today).toBe(1);        // u-today
    expect(w.last3Days).toBe(1);    // u-today only
    expect(w.last7Days).toBe(2);    // u-today + u-5d
    expect(w.last14Days).toBe(2);   // u-today + u-5d (u-5d = Jul 27, within 14 days of Aug 1)
    expect(w.monthToDate).toBe(1);  // u-today only (Aug 1 MTD since 2026-08-01T00:00Z)
    expect(w.yearToDate).toBe(2);   // u-today + u-5d (both in 2026)
  });

  it("returns totals", async () => {
    const repo = new AdminAnalyticsRepository(db);
    expect(await repo.totals()).toEqual({ totalUsers: 3, totalGyms: 2, totalOpenMats: 3 });
  });

  it("returns top states by open-mat count, descending", async () => {
    const repo = new AdminAnalyticsRepository(db);
    const top = await repo.topStates(10);
    expect(top[0]).toEqual({ state: "TX", count: 2 });
    expect(top).toContainEqual({ state: "CA", count: 1 });
  });
});
