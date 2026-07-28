import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassRepository } from "../src/repositories/class.repository.mts";
import type { GymClass } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_classes");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function c(over: Partial<GymClass>): GymClass {
  return {
    id: over.id ?? "c1",
    gymId: over.gymId ?? "g1",
    title: "Fundamentals",
    classType: "fundamentals",
    giType: "gi",
    skillLevel: "beginner",
    isRecurring: true,
    dayOfWeek: 1,
    startTime: "18:00",
    endTime: "19:00",
    status: "active",
    ...over,
  };
}

describe("ClassRepository", () => {
  it("lists active classes for a gym, excluding archived", async () => {
    const repo = new ClassRepository(db);
    await repo.ensureIndexes();
    await repo.insert(c({ id: "a", gymId: "g9" }));
    await repo.insert(c({ id: "b", gymId: "g9", status: "archived" }));
    const active = await repo.listActiveByGym("g9");
    expect(active.map((x) => x.id)).toEqual(["a"]);
  });

  it("update no-ops on empty patch", async () => {
    const repo = new ClassRepository(db);
    await repo.insert(c({ id: "u", gymId: "gU" }));
    const same = await repo.update("u", {});
    expect(same?.id).toBe("u");
  });
});
