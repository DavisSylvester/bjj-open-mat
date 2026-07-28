import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassOccurrenceRepository } from "../src/repositories/class-occurrence.repository.mts";
import type { ClassOccurrence } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_occ");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const occ = (over: Partial<ClassOccurrence>): ClassOccurrence =>
  ({ id: "o1", classId: "c1", gymId: "g1", date: "2026-08-03", status: "scheduled", ...over });

describe("ClassOccurrenceRepository", () => {
  it("upsert is keyed by (classId,date) and merges overrides", async () => {
    const repo = new ClassOccurrenceRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(occ({ id: "first", note: "n1" }));
    await repo.upsert(occ({ id: "second", status: "cancelled" })); // same class+date
    const found = await repo.find("c1", "2026-08-03");
    expect(found?.status).toBe("cancelled");
    expect(found?.note).toBe("n1"); // prior field preserved
    expect(found?.id).toBe("first"); // id set on insert only
  });

  it("listByGymRange filters by date window", async () => {
    const repo = new ClassOccurrenceRepository(db);
    await repo.upsert(occ({ id: "in", classId: "c2", gymId: "gR", date: "2026-08-05" }));
    await repo.upsert(occ({ id: "out", classId: "c3", gymId: "gR", date: "2026-09-01" }));
    const rows = await repo.listByGymRange("gR", "2026-08-01", "2026-08-31");
    expect(rows.map((r) => r.classId)).toEqual(["c2"]);
  });
});
