// apps/api/test/user-repository-list.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserRepository } from "../src/repositories/user.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_user_repo_list");

afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("UserRepository.list", () => {
  it("returns paged items and a total count, newest first", async () => {
    const repo = new UserRepository(db);
    await repo.insert({ id: "u-1", email: "a@x.dev", displayName: "A", createdAt: "2026-01-01T00:00:00.000Z" });
    await repo.insert({ id: "u-2", email: "b@x.dev", displayName: "B", createdAt: "2026-02-01T00:00:00.000Z" });
    await repo.insert({ id: "u-3", email: "c@x.dev", displayName: "C", createdAt: "2026-03-01T00:00:00.000Z" });

    const page = await repo.list(0, 2);
    expect(page.total).toBe(3);
    expect(page.items.map((u) => u.id)).toEqual(["u-3", "u-2"]);
  });
});
