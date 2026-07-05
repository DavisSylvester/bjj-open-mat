import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import { CheckInRepository } from "../src/repositories/check-in.repository.mts";
import { FavoriteRepository } from "../src/repositories/favorite.repository.mts";
import { NotificationRepository } from "../src/repositories/notification.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_secondary");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("secondary repositories", () => {
  it("rsvp is idempotent per (openMat, date, user)", async () => {
    const repo = new RsvpRepository(db);
    await repo.ensureIndexes();
    await repo.add("om-1", "2026-06-20", "u-1");
    await repo.add("om-1", "2026-06-20", "u-1");
    expect(await repo.count("om-1", "2026-06-20")).toBe(1);
    await repo.remove("om-1", "2026-06-20", "u-1");
    expect(await repo.count("om-1", "2026-06-20")).toBe(0);
  });

  it("favorites toggle and list", async () => {
    const repo = new FavoriteRepository(db);
    await repo.ensureIndexes();
    await repo.add("u-1", "g-1");
    expect((await repo.listGymIds("u-1"))).toContain("g-1");
    await repo.remove("u-1", "g-1");
    expect((await repo.listGymIds("u-1"))).toHaveLength(0);
  });

  it("checkins insert + review update", async () => {
    const repo = new CheckInRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: new Date().toISOString() });
    await repo.setReview("c-1", { rating: 5, categoryRatings: { instruction: 5, cleanliness: 5, variety: 5, worth_returning: 5, overall: 5 } , reviewedAt: new Date().toISOString() });
    const mine = await repo.listByUser("u-1", 0, 20);
    expect(mine.items[0]?.rating).toBe(5);
  });

  it("notifications list + mark read", async () => {
    const repo = new NotificationRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "n-1", userId: "u-1", type: "system", title: "hi", body: "b", read: false, createdAt: new Date().toISOString() });
    await repo.markRead("n-1", "u-1");
    const res = await repo.listByUser("u-1", false, 0, 20);
    expect(res.items[0]?.read).toBe(true);
  });
});
