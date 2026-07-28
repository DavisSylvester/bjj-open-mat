import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassJournalRepository } from "../src/repositories/class-journal.repository.mts";
import type { ClassJournalEntry } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_journal");
afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

const e = (over: Partial<ClassJournalEntry>): ClassJournalEntry => ({
  id: over.id ?? "j1",
  classId: over.classId ?? "c1",
  gymId: "g1",
  userId: over.userId ?? "u1",
  date: over.date ?? "2026-08-03",
  techniqueTags: over.techniqueTags ?? [],
  shared: over.shared ?? false,
  createdAt: "t",
  ...over,
});

describe("ClassJournalRepository", () => {
  it("upsert is idempotent per (class,date,user) and updates fields", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(e({ id: "first", whatWasTaught: "guard" }));
    await repo.upsert(e({ id: "second", whatWasTaught: "mount", shared: true }));
    const mine = await repo.findMine("c1", "2026-08-03", "u1");
    expect(mine?.id).toBe("first"); // id set on insert only
    expect(mine?.whatWasTaught).toBe("mount"); // field updated
    expect(mine?.shared).toBe(true);
  });

  it("listSharedForOccurrence returns only shared entries", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.upsert(e({ id: "s", classId: "c2", userId: "a", shared: true }));
    await repo.upsert(e({ id: "p", classId: "c2", userId: "b", shared: false }));
    const shared = await repo.listSharedForOccurrence("c2", "2026-08-03");
    expect(shared.map((x) => x.userId)).toEqual(["a"]);
  });

  it("listByUserRange filters by date window newest-first", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.upsert(e({ id: "old", classId: "c3", userId: "r", date: "2026-08-01" }));
    await repo.upsert(e({ id: "new", classId: "c4", userId: "r", date: "2026-08-20" }));
    const rows = await repo.listByUserRange("r", "2026-08-01", "2026-08-31");
    expect(rows.map((x) => x.date)).toEqual(["2026-08-20", "2026-08-01"]);
  });
});
