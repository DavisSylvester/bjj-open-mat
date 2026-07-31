import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MessageReportRepository } from "../src/repositories/message-report.repository.mts";
import type { MessageReport } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_reports");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const rep = (over: Partial<MessageReport>): MessageReport => ({
  id: over.id ?? "r1", reportedUserId: "u2", reporterId: "u1", gymId: over.gymId ?? "g1",
  reason: "spam", status: over.status ?? "open", createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("MessageReportRepository", () => {
  it("lists by gym + status newest-first, updates status", async () => {
    const repo = new MessageReportRepository(db);
    await repo.ensureIndexes();
    await repo.insert(rep({ id: "r1", gymId: "gL", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(rep({ id: "r2", gymId: "gL", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(rep({ id: "r3", gymId: "gOther" }));
    const open = await repo.listByGym("gL", "open");
    expect(open.map((r) => r.id)).toEqual(["r2", "r1"]);
    await repo.updateStatus("r1", "reviewed", "2026-08-03T00:00:00.000Z");
    expect((await repo.findById("r1"))?.status).toBe("reviewed");
    expect((await repo.listByGym("gL", "open")).map((r) => r.id)).toEqual(["r2"]);
  });
});
