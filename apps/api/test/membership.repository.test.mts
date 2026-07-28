// apps/api/test/membership.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MembershipRepository } from "../src/repositories/membership.repository.mts";
import type { GymMembership } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_memberships");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function m(over: Partial<GymMembership>): GymMembership {
  return {
    id: over.id ?? "m1", gymId: over.gymId ?? "g1", userId: over.userId ?? "u1",
    status: "active", verifiedMember: false, gymRole: "member",
    isHome: over.isHome ?? false, visibleInRoster: over.visibleInRoster ?? true,
    joinMethod: "self", joinedAt: "2026-07-27T00:00:00.000Z", ...over,
  };
}

describe("MembershipRepository", () => {
  it("upsertJoin is idempotent per (gym,user)", async () => {
    const repo = new MembershipRepository(db);
    await repo.ensureIndexes();
    const first = await repo.upsertJoin(m({ id: "a" }));
    const second = await repo.upsertJoin(m({ id: "b" })); // same gym+user, different id
    expect(second.id).toBe(first.id);
    const all = await repo.listByUser("u1");
    expect(all.length).toBe(1);
  });

  it("listByGym hides visibleInRoster:false unless includeHidden", async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: "v", gymId: "g2", userId: "vis", visibleInRoster: true }));
    await repo.upsertJoin(m({ id: "h", gymId: "g2", userId: "hid", visibleInRoster: false }));
    expect((await repo.listByGym("g2", false)).map((x) => x.userId)).toEqual(["vis"]);
    expect((await repo.listByGym("g2", true)).length).toBe(2);
  });

  it("setHome makes exactly one membership home for a user", async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: "h1", gymId: "gA", userId: "uH", isHome: true }));
    await repo.upsertJoin(m({ id: "h2", gymId: "gB", userId: "uH" }));
    await repo.setHome("uH", "gB");
    const list = await repo.listByUser("uH");
    expect(list.filter((x) => x.isHome).map((x) => x.gymId)).toEqual(["gB"]);
  });
});
