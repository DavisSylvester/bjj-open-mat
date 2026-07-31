import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MessageRepository } from "../src/repositories/message.repository.mts";
import type { Message } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_messages");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const msg = (over: Partial<Message>): Message => ({
  id: over.id ?? "m1", conversationId: over.conversationId ?? "c1", authorId: over.authorId ?? "u1",
  body: over.body ?? "B", createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("MessageRepository", () => {
  it("lists newest-first and honors before cursor", async () => {
    const repo = new MessageRepository(db);
    await repo.ensureIndexes();
    await repo.insert(msg({ id: "m1", conversationId: "cX", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(msg({ id: "m2", conversationId: "cX", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(msg({ id: "m3", conversationId: "cX", createdAt: "2026-08-03T00:00:00.000Z" }));
    const all = await repo.listByConversation("cX", undefined, 10);
    expect(all.map((m) => m.id)).toEqual(["m3", "m2", "m1"]);
    const older = await repo.listByConversation("cX", "2026-08-03T00:00:00.000Z", 10);
    expect(older.map((m) => m.id)).toEqual(["m2", "m1"]);
  });

  it("countAfter counts messages strictly newer, excluding deleted", async () => {
    const repo = new MessageRepository(db);
    await repo.insert(msg({ id: "a", conversationId: "cY", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(msg({ id: "b", conversationId: "cY", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(msg({ id: "c", conversationId: "cY", createdAt: "2026-08-03T00:00:00.000Z" }));
    await repo.softDelete("c", "2026-08-04T00:00:00.000Z");
    expect(await repo.countAfter("cY", "2026-08-01T00:00:00.000Z")).toBe(1); // only b (c deleted)
    expect(await repo.countAfter("cY", undefined)).toBe(2); // a + b (c deleted)
  });
});
