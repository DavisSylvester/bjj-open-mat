import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ForumAnswerRepository } from "../src/repositories/forum-answer.repository.mts";
import type { ForumAnswer } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_forum_a");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const a = (over: Partial<ForumAnswer>): ForumAnswer => ({
  id: over.id ?? "a1", questionId: over.questionId ?? "q1", gymId: "g1", authorId: "u1", body: "B",
  accepted: over.accepted ?? false, createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("ForumAnswerRepository", () => {
  it("lists accepted-first then oldest", async () => {
    const repo = new ForumAnswerRepository(db);
    await repo.ensureIndexes();
    await repo.insert(a({ id: "first", questionId: "qX", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(a({ id: "second", questionId: "qX", createdAt: "2026-08-02T00:00:00.000Z", accepted: true }));
    const list = await repo.listByQuestion("qX");
    expect(list.map((x) => x.id)).toEqual(["second", "first"]);
  });

  it("setAcceptedForQuestion accepts one and unsets others", async () => {
    const repo = new ForumAnswerRepository(db);
    await repo.insert(a({ id: "p", questionId: "qY", accepted: true }));
    await repo.insert(a({ id: "n", questionId: "qY" }));
    await repo.setAcceptedForQuestion("qY", "n");
    const list = await repo.listByQuestion("qY");
    expect(list.find((x) => x.id === "n")?.accepted).toBe(true);
    expect(list.find((x) => x.id === "p")?.accepted).toBe(false);
  });
});
