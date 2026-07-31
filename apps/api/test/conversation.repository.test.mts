import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ConversationRepository } from "../src/repositories/conversation.repository.mts";
import type { Conversation } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_conversations");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const conv = (over: Partial<Conversation>): Conversation => ({
  id: over.id ?? "c1", kind: over.kind ?? "direct", createdBy: "u1",
  createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("ConversationRepository", () => {
  it("find-or-create direct by pairKey", async () => {
    const repo = new ConversationRepository(db);
    await repo.ensureIndexes();
    await repo.insert(conv({ id: "d1", kind: "direct", pairKey: "u1|u2" }));
    const found = await repo.findDirectByPairKey("u1|u2");
    expect(found?.id).toBe("d1");
    expect(await repo.findDirectByPairKey("u1|u9")).toBeNull();
  });

  it("lists gym channels newest-first", async () => {
    const repo = new ConversationRepository(db);
    await repo.insert(conv({ id: "ch-old", kind: "gym_channel", gymId: "gL", title: "Old", lastMessageAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(conv({ id: "ch-new", kind: "gym_channel", gymId: "gL", title: "New", lastMessageAt: "2026-08-05T00:00:00.000Z" }));
    const list = await repo.listChannelsByGym("gL");
    expect(list.map((c) => c.id)).toEqual(["ch-new", "ch-old"]);
  });

  it("updateLastMessage sets at + preview", async () => {
    const repo = new ConversationRepository(db);
    await repo.insert(conv({ id: "c2", kind: "group", gymId: "g1", title: "S" }));
    await repo.updateLastMessage("c2", "2026-08-09T00:00:00.000Z", "hey");
    const c = await repo.findById("c2");
    expect(c?.lastMessagePreview).toBe("hey");
    expect(c?.lastMessageAt).toBe("2026-08-09T00:00:00.000Z");
  });
});
