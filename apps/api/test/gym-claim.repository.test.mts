import { afterAll, beforeEach, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import type { GymClaim } from "@bjj/contract";
import { GymClaimRepository } from "../src/repositories/gym-claim.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27021", { timeoutMS: 4000 });
const db = client.db("bjj_test_gym_claims");
const repo = new GymClaimRepository(db);

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

beforeEach(async () => {
  await db.collection("gymClaims").deleteMany({});
});

function claim(over: Partial<GymClaim> = {}): GymClaim {
  return {
    id: "c1",
    gymId: "g1",
    claimantId: "u1",
    kind: "claim",
    relationship: "owner",
    contact: "u1@gym.com",
    message: "mine",
    status: "pending",
    createdAt: "2026-07-30T00:00:00.000Z",
    ...over,
  };
}

describe("GymClaimRepository", () => {
  it("inserts and finds by id", async () => {
    await repo.insert(claim());
    const found = await repo.findById("c1");
    expect(found?.gymId).toBe("g1");
    expect((found as { _id?: unknown })._id).toBeUndefined();
  });

  it("finds a pending claim by gym + claimant, ignoring decided ones", async () => {
    await repo.insert(claim({ id: "c1", status: "rejected" }));
    expect(await repo.findPendingByGymAndClaimant("g1", "u1")).toBeNull();
    await repo.insert(claim({ id: "c2", status: "pending" }));
    const pending = await repo.findPendingByGymAndClaimant("g1", "u1");
    expect(pending?.id).toBe("c2");
  });

  it("returns the most recent claim for gym + claimant", async () => {
    await repo.insert(claim({ id: "c1", status: "rejected", createdAt: "2026-07-01T00:00:00.000Z" }));
    await repo.insert(claim({ id: "c2", status: "pending", createdAt: "2026-07-30T00:00:00.000Z" }));
    const latest = await repo.findLatestByGymAndClaimant("g1", "u1");
    expect(latest?.id).toBe("c2");
  });

  it("lists by status and by claimant and pending-by-gym", async () => {
    await repo.insert(claim({ id: "c1", status: "pending" }));
    await repo.insert(claim({ id: "c2", claimantId: "u2", contact: "u2@gym.com", status: "pending" }));
    await repo.insert(claim({ id: "c3", status: "approved" }));
    expect((await repo.listByStatus("pending")).map((c) => c.id).sort()).toEqual(["c1", "c2"]);
    expect((await repo.listByClaimant("u1")).map((c) => c.id).sort()).toEqual(["c1", "c3"]);
    expect((await repo.listPendingByGym("g1")).map((c) => c.id).sort()).toEqual(["c1", "c2"]);
  });

  it("updates status fields", async () => {
    await repo.insert(claim());
    const updated = await repo.updateStatus("c1", { status: "approved", decidedBy: "admin1" });
    expect(updated?.status).toBe("approved");
    expect(updated?.decidedBy).toBe("admin1");
  });
});
