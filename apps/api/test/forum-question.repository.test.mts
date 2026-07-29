import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ForumQuestionRepository } from "../src/repositories/forum-question.repository.mts";
import type { ForumQuestion } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_forum_q");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const q = (over: Partial<ForumQuestion>): ForumQuestion => ({
  id: over.id ?? "q1", gymId: over.gymId ?? "g1", authorId: "u1", category: over.category ?? "general",
  title: "T", body: "B", pinned: over.pinned ?? false, locked: false, answerCount: 0,
  createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("ForumQuestionRepository", () => {
  it("lists pinned first then newest, filters by category", async () => {
    const repo = new ForumQuestionRepository(db);
    await repo.ensureIndexes();
    await repo.insert(q({ id: "old", gymId: "gL", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(q({ id: "new", gymId: "gL", createdAt: "2026-08-05T00:00:00.000Z" }));
    await repo.insert(q({ id: "pin", gymId: "gL", pinned: true, createdAt: "2026-07-01T00:00:00.000Z" }));
    const all = await repo.listByGym("gL", undefined, 0, 20);
    expect(all.items.map((x) => x.id)).toEqual(["pin", "new", "old"]);
    await repo.insert(q({ id: "tech", gymId: "gL", category: "technique" }));
    const tech = await repo.listByGym("gL", "technique", 0, 20);
    expect(tech.items.map((x) => x.id)).toEqual(["tech"]);
  });

  it("incAnswerCount adjusts the count", async () => {
    const repo = new ForumQuestionRepository(db);
    await repo.insert(q({ id: "c", gymId: "gC" }));
    await repo.incAnswerCount("c", 1);
    await repo.incAnswerCount("c", 1);
    await repo.incAnswerCount("c", -1);
    expect((await repo.findById("c"))?.answerCount).toBe(1);
  });
});
