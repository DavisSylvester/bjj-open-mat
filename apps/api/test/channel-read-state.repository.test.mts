import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ChannelReadStateRepository } from "../src/repositories/channel-read-state.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_channel_read");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("ChannelReadStateRepository", () => {
  it("lazily creates then updates read state", async () => {
    const repo = new ChannelReadStateRepository(db);
    await repo.ensureIndexes();
    expect(await repo.find("ch1", "u1")).toBeNull();
    await repo.upsertLastReadAt("ch1", "u1", "2026-08-03T00:00:00.000Z", "s-1");
    let row = await repo.find("ch1", "u1");
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z");
    expect(row?.muted).toBe(false);
    await repo.upsertMuted("ch1", "u1", true, "s-2");
    row = await repo.find("ch1", "u1");
    expect(row?.muted).toBe(true);
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z"); // preserved
  });
});
