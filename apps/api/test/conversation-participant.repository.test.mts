import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ConversationParticipantRepository } from "../src/repositories/conversation-participant.repository.mts";
import type { ConversationParticipant } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_participants");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const p = (over: Partial<ConversationParticipant>): ConversationParticipant => ({
  id: over.id ?? "p1", conversationId: over.conversationId ?? "c1", userId: over.userId ?? "u1",
  role: over.role ?? "member", muted: over.muted ?? false, ...over,
});

describe("ConversationParticipantRepository", () => {
  it("lists active-for-user excluding left", async () => {
    const repo = new ConversationParticipantRepository(db);
    await repo.ensureIndexes();
    await repo.insertMany([p({ id: "p1", conversationId: "cA", userId: "uX" }), p({ id: "p2", conversationId: "cB", userId: "uX" })]);
    await repo.setLeftAt("cB", "uX", "2026-08-02T00:00:00.000Z");
    const active = await repo.listActiveForUser("uX");
    expect(active.map((x) => x.conversationId)).toEqual(["cA"]);
  });

  it("setLastReadAt + setMuted persist", async () => {
    const repo = new ConversationParticipantRepository(db);
    await repo.insertMany([p({ id: "p3", conversationId: "cC", userId: "uY" })]);
    await repo.setLastReadAt("cC", "uY", "2026-08-03T00:00:00.000Z");
    await repo.setMuted("cC", "uY", true);
    const row = await repo.find("cC", "uY");
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z");
    expect(row?.muted).toBe(true);
  });
});
