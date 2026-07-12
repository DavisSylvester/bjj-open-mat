import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient, type Db } from "mongodb";
import { WaitlistLeadRepository } from "../src/repositories/waitlist-lead.repository.mts";
import { GymLeadRepository } from "../src/repositories/gym-lead.repository.mts";
import type { WaitlistLead, GymLead } from "@bjj/contract";

const URI = process.env.MONGODB_URI ?? "mongodb://localhost:27017";
let client: MongoClient;
let db: Db;

beforeAll(async () => {
  client = new MongoClient(URI);
  await client.connect();
  db = client.db("bjj_open_mat_test_leads");
});

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("WaitlistLeadRepository", () => {
  it("upserts idempotently on email (no duplicates)", async () => {
    const repo = new WaitlistLeadRepository(db);
    await repo.ensureIndexes();
    const base: WaitlistLead = {
      id: "w1",
      email: "dup@b.com",
      status: "confirmed",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    const first = await repo.upsertByEmail(base);
    const second = await repo.upsertByEmail({ ...base, id: "w2" });
    expect(first).toBe(true);
    expect(second).toBe(false);
    const count = await db.collection("waitlistLeads").countDocuments({ email: "dup@b.com" });
    expect(count).toBe(1);
    const doc = await db.collection<{ _id: string; email: string }>("waitlistLeads").findOne({ email: "dup@b.com" });
    expect(doc?._id).toBe("w1");
  });
});

describe("GymLeadRepository", () => {
  it("inserts a gym lead", async () => {
    const repo = new GymLeadRepository(db);
    await repo.ensureIndexes();
    const lead: GymLead = {
      id: "g1",
      gymName: "GB",
      ownerEmail: "coach@gym.com",
      status: "new",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    await repo.insert(lead);
    const found = await db.collection("gymLeads").findOne({ id: "g1" });
    expect(found?.gymName).toBe("GB");
  });
});
