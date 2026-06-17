import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserRepository } from "../src/repositories/user.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_users");

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("UserRepository", () => {
  it("upserts by auth0Id and reads back", async () => {
    const repo = new UserRepository(db);
    await repo.ensureIndexes();
    const created = await repo.upsertByAuth0Id("auth0|1", {
      id: "u-1",
      email: "a@b.dev",
      displayName: "A",
      role: "practitioner",
    });
    expect(created.id).toBe("u-1");
    const found = await repo.findById("u-1");
    expect(found?.email).toBe("a@b.dev");
  });
});
