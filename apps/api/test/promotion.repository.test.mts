import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { PromotionRepository } from "../src/repositories/promotion.repository.mts";
import type { BeltPromotion } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_promotions");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function p(id: string, at: string): BeltPromotion {
  return { id, userId: "u1", gymId: "g1", beltRank: "blue", beltStripes: 0, promotedByUserId: "c1", promotedAt: at };
}

describe("PromotionRepository", () => {
  it("lists newest first and returns latest", async () => {
    const repo = new PromotionRepository(db);
    await repo.ensureIndexes();
    await repo.insert(p("old", "2020-01-01T00:00:00.000Z"));
    await repo.insert(p("new", "2026-07-27T00:00:00.000Z"));
    const list = await repo.listByUser("u1");
    expect(list[0]?.id).toBe("new");
    expect((await repo.latestForUser("u1"))?.id).toBe("new");
  });
});
