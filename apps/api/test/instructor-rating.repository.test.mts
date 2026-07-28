import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { InstructorRatingRepository } from "../src/repositories/instructor-rating.repository.mts";
import type { InstructorRating } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_instructor_rating");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const r = (over: Partial<InstructorRating>): InstructorRating => ({
  id: over.id ?? "r1", classId: over.classId ?? "c1", gymId: "g1", date: over.date ?? "2026-08-03",
  instructorUserId: over.instructorUserId ?? "inst1", ratedByUserId: over.ratedByUserId ?? "u1",
  stars: over.stars ?? 5, anonymous: over.anonymous ?? false, createdAt: "t", ...over,
});

describe("InstructorRatingRepository", () => {
  it("upsert idempotent per (class,date,rater), summary averages", async () => {
    const repo = new InstructorRatingRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(r({ id: "a", ratedByUserId: "u1", stars: 4 }));
    await repo.upsert(r({ id: "b", ratedByUserId: "u1", stars: 2 })); // same rater+occurrence -> update
    await repo.upsert(r({ id: "c", ratedByUserId: "u2", stars: 4 }));
    const s = await repo.summaryForInstructor("inst1");
    expect(s.count).toBe(2);          // two distinct raters
    expect(s.avg).toBe(3);            // (2 + 4) / 2
  });

  it("summary is zero for an unrated instructor", async () => {
    const repo = new InstructorRatingRepository(db);
    expect(await repo.summaryForInstructor("nobody")).toEqual({ avg: 0, count: 0 });
  });
});
