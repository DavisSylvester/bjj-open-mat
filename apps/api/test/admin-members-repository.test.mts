import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MembershipRepository } from "../src/repositories/membership.repository.mts";
import { UserRepository } from "../src/repositories/user.repository.mts";

const TEST_DB = "bjj_test_admin_members_repo";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
let memberships: MembershipRepository;
let users: UserRepository;

function membership(id: string, gymId: string, userId: string, status?: string): Record<string, unknown> {
  return {
    _id: id, id, gymId, userId,
    ...(status === undefined ? {} : { status }),
    verifiedMember: false, isHome: false, visibleInRoster: true,
    joinedAt: "2026-08-01T00:00:00.000Z",
  };
}

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("users").insertMany([
    { _id: "u-1", id: "u-1", email: "u1@e.dev", displayName: "One", role: "practitioner", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-2", id: "u-2", email: "u2@e.dev", displayName: "Two", role: "practitioner", createdAt: "2026-08-02T00:00:00.000Z" },
    { _id: "u-3", id: "u-3", email: "u3@e.dev", displayName: "Three", role: "practitioner", createdAt: "2026-08-03T00:00:00.000Z" },
    { _id: "u-orphan", id: "u-orphan", email: "orphan@e.dev", displayName: "Orphan", role: "practitioner", createdAt: "2026-08-04T00:00:00.000Z" },
  ] as never);
  await db.collection("gymMemberships").insertMany([
    membership("m-1", "g-1", "u-1", "active"),
    membership("m-2", "g-1", "u-2", "pending"),
    membership("m-3", "g-1", "u-3"),                 // legacy row, no status
    membership("m-4", "g-2", "u-1", "inactive"),
    membership("m-5", "g-3", "u-2", "pending"),
    membership("m-6", "g-3", "u-3", "pending"),
  ] as never);
  memberships = new MembershipRepository(db);
  users = new UserRepository(db);
});

afterAll(async () => {
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("MembershipRepository.countsByGym", () => {
  it("counts every membership including pending and status-less legacy rows", async () => {
    const rows = await memberships.countsByGym();
    const g1 = rows.find((r) => r.gymId === "g-1");
    expect(g1).toEqual({ gymId: "g-1", memberCount: 3, pendingCount: 1 });
  });

  it("counts a gym whose memberships are all pending", async () => {
    const rows = await memberships.countsByGym();
    expect(rows.find((r) => r.gymId === "g-3")).toEqual({ gymId: "g-3", memberCount: 2, pendingCount: 2 });
  });

  it("omits gyms with no memberships rather than reporting zero", async () => {
    const rows = await memberships.countsByGym();
    expect(rows.find((r) => r.gymId === "g-nonexistent")).toBeUndefined();
  });
});

describe("MembershipRepository.listByGymForAdmin", () => {
  it("includes pending rows, which listByGym excludes", async () => {
    const { items } = await memberships.listByGymForAdmin("g-1", 0, 50);
    expect(items.map((i) => i.id).sort()).toEqual(["m-1", "m-2", "m-3"]);
  });

  it("its total matches countsByGym for the same gym", async () => {
    const { total } = await memberships.listByGymForAdmin("g-1", 0, 50);
    const counts = await memberships.countsByGym();
    expect(total).toBe(counts.find((r) => r.gymId === "g-1")!.memberCount);
  });

  it("pages without overlap", async () => {
    const first = await memberships.listByGymForAdmin("g-1", 0, 2);
    const second = await memberships.listByGymForAdmin("g-1", 2, 2);
    expect(first.items).toHaveLength(2);
    expect(second.items).toHaveLength(1);
    const ids = [...first.items, ...second.items].map((i) => i.id);
    expect(new Set(ids).size).toBe(3);
  });
});

describe("UserRepository.listWithoutMemberships", () => {
  it("returns only users with zero memberships", async () => {
    const { items, total } = await users.listWithoutMemberships(0, 50);
    expect(items.map((u) => u.id)).toEqual(["u-orphan"]);
    expect(total).toBe(1);
  });

  it("excludes a user who belongs to two gyms", async () => {
    const { items } = await users.listWithoutMemberships(0, 50);
    expect(items.map((u) => u.id)).not.toContain("u-1");
  });
});
