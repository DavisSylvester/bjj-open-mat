import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserBlockRepository } from "../src/repositories/user-block.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_blocks");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("UserBlockRepository", () => {
  it("existsEitherWay detects both directions; listBlockedBy returns targets", async () => {
    const repo = new UserBlockRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "b1", blockerId: "u1", blockedId: "u2" });
    expect(await repo.existsEitherWay("u1", "u2")).toBe(true);
    expect(await repo.existsEitherWay("u2", "u1")).toBe(true);
    expect(await repo.existsEitherWay("u1", "u9")).toBe(false);
    expect(await repo.listBlockedBy("u1")).toEqual(["u2"]);
  });

  it("deleteByBlocked removes the block by blockerId + blockedId", async () => {
    const repo = new UserBlockRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "b2", blockerId: "u3", blockedId: "u4" });
    expect(await repo.existsEitherWay("u3", "u4")).toBe(true);
    await repo.deleteByBlocked("u3", "u4");
    expect(await repo.existsEitherWay("u3", "u4")).toBe(false);
  });
});
