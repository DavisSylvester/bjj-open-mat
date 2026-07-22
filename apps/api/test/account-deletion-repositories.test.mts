import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserRepository } from "../src/repositories/user.repository.mts";
import { CheckInRepository } from "../src/repositories/check-in.repository.mts";
import { FavoriteRepository } from "../src/repositories/favorite.repository.mts";
import { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import { NotificationRepository } from "../src/repositories/notification.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_account_deletion_repos");

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("UserRepository.remove", () => {
  it("deletes the user document by id", async () => {
    const repo = new UserRepository(db);
    await repo.insert({
      id: "u-remove-1",
      email: "remove1@x.dev",
      displayName: "Remove Me",
      settings: { theme: "glass", notifyRsvp: true, notifySessionUpdates: true },
      createdAt: new Date().toISOString(),
    });
    expect(await repo.findById("u-remove-1")).not.toBeNull();

    await repo.remove("u-remove-1");

    expect(await repo.findById("u-remove-1")).toBeNull();
  });
});

describe("cascading deleteByUserId on owned-data repositories", () => {
  it("CheckInRepository removes only the target user's check-ins", async () => {
    const repo = new CheckInRepository(db);
    await repo.insert({ id: "ci-1", userId: "u-a", gymId: "g-1", openMatId: "om-1", sessionDate: "2026-01-01", checkedInAt: new Date().toISOString() } as never);
    await repo.insert({ id: "ci-2", userId: "u-b", gymId: "g-1", openMatId: "om-1", sessionDate: "2026-01-01", checkedInAt: new Date().toISOString() } as never);

    await repo.deleteByUserId("u-a");

    expect(await repo.findById("ci-1")).toBeNull();
    expect(await repo.findById("ci-2")).not.toBeNull();
  });

  it("FavoriteRepository removes only the target user's favorites", async () => {
    const repo = new FavoriteRepository(db);
    await repo.add("u-a", "g-1");
    await repo.add("u-b", "g-1");

    await repo.deleteByUserId("u-a");

    expect(await repo.listGymIds("u-a")).toEqual([]);
    expect(await repo.listGymIds("u-b")).toEqual(["g-1"]);
  });

  it("RsvpRepository removes only the target user's rsvps", async () => {
    const repo = new RsvpRepository(db);
    await repo.add("om-1", "2026-01-01", "u-a");
    await repo.add("om-1", "2026-01-01", "u-b");

    await repo.deleteByUserId("u-a");

    const remaining = await repo.userIds("om-1", "2026-01-01");
    expect(remaining).toEqual(["u-b"]);
  });

  it("NotificationRepository removes only the target user's notifications", async () => {
    const repo = new NotificationRepository(db);
    await repo.insert({ id: "n-1", userId: "u-a", type: "rsvp", title: "t", body: "b", read: false, createdAt: new Date().toISOString() } as never);
    await repo.insert({ id: "n-2", userId: "u-b", type: "rsvp", title: "t", body: "b", read: false, createdAt: new Date().toISOString() } as never);

    await repo.deleteByUserId("u-a");

    const { items: aItems } = await repo.listByUser("u-a", false, 0, 10);
    const { items: bItems } = await repo.listByUser("u-b", false, 0, 10);
    expect(aItems).toEqual([]);
    expect(bItems).toHaveLength(1);
  });
});
