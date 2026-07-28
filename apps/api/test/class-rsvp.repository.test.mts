import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassRsvpRepository } from "../src/repositories/class-rsvp.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_rsvp");
afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("ClassRsvpRepository", () => {
  it("add is idempotent per (class,date,user) and refreshes isMember", async () => {
    const repo = new ClassRsvpRepository(db);
    await repo.ensureIndexes();
    await repo.add("c1", "2026-08-03", "u1", false);
    await repo.add("c1", "2026-08-03", "u1", true); // re-rsvp, now a member
    expect(await repo.count("c1", "2026-08-03")).toBe(1);
    const list = await repo.list("c1", "2026-08-03");
    expect(list[0]?.isMember).toBe(true);
  });

  it("countsForClassDates groups by date", async () => {
    const repo = new ClassRsvpRepository(db);
    await repo.add("c2", "2026-08-04", "a", true);
    await repo.add("c2", "2026-08-04", "b", false);
    await repo.add("c2", "2026-08-11", "a", true);
    const counts = await repo.countsForClassDates("c2", ["2026-08-04", "2026-08-11"]);
    expect(counts["2026-08-04"]).toBe(2);
    expect(counts["2026-08-11"]).toBe(1);
  });
});
