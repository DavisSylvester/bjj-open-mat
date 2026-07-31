import { afterAll, describe, expect, test } from "bun:test";
import { MongoClient, type Collection } from "mongodb";
import {
  applyBackfill,
  createMongoMembershipWriter,
  planBackfill,
  type BackfillPlan,
  type MembershipDoc,
  type MembershipWriter,
} from "../scripts/backfill-home-gym-memberships.mts";

describe("planBackfill", () => {
  const gyms = new Set<string>(["g1", "g2"]);

  test("plans a membership for a user with a home gym and none", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>());
    expect(plan.toCreate).toEqual([{ userId: "u1", gymId: "g1" }]);
    expect(plan.skippedExisting).toHaveLength(0);
    expect(plan.skippedMissingGym).toHaveLength(0);
  });

  test("skips a user who already has that membership", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>(["g1::u1"]));
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedExisting).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("reports rather than fails on a home gym that no longer exists", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "gone" }], gyms, new Set<string>());
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedMissingGym).toEqual([{ userId: "u1", gymId: "gone" }]);
  });

  test("ignores users with no home gym", () => {
    const plan = planBackfill([{ id: "u1" }], gyms, new Set<string>());
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedExisting).toHaveLength(0);
    expect(plan.skippedMissingGym).toHaveLength(0);
  });

  test("is idempotent — a second run over its own output plans nothing", () => {
    const first = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>());
    const after = new Set<string>(first.toCreate.map((c) => `${c.gymId}::${c.userId}`));
    const second = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, after);
    expect(second.toCreate).toHaveLength(0);
  });
});

describe("applyBackfill", () => {
  // The pure planner has no concept of writes, so the single-home-gym
  // invariant (MembershipRepository.setHome clears isHome on a user's other
  // memberships before setting the new one) can only be asserted against the
  // write-branch logic. This fakes MembershipWriter to record call order and
  // arguments without touching a live database.
  test("clears the user's other home memberships before inserting the new one", async () => {
    const calls: string[] = [];
    const inserted: MembershipDoc[] = [];
    const writer: MembershipWriter = {
      clearOtherHomes: async (userId: string, gymId: string): Promise<void> => {
        calls.push(`clear:${userId}:${gymId}`);
      },
      insertMembership: async (doc: MembershipDoc): Promise<void> => {
        calls.push(`insert:${doc.userId}:${doc.gymId}`);
        inserted.push(doc);
      },
    };
    const plan: BackfillPlan = {
      toCreate: [{ userId: "u1", gymId: "g1" }],
      skippedExisting: [],
      skippedMissingGym: [],
    };

    await applyBackfill(plan, writer, "2026-01-01T00:00:00.000Z");

    expect(calls).toEqual(["clear:u1:g1", "insert:u1:g1"]);
    expect(inserted).toHaveLength(1);
    expect(inserted[0]?.isHome).toBe(true);
    expect(inserted[0]?._id).toBe(inserted[0]?.id);
  });

  test("clears and inserts independently for each pair in the plan", async () => {
    const calls: string[] = [];
    const writer: MembershipWriter = {
      clearOtherHomes: async (userId: string, gymId: string): Promise<void> => {
        calls.push(`clear:${userId}:${gymId}`);
      },
      insertMembership: async (doc: MembershipDoc): Promise<void> => {
        calls.push(`insert:${doc.userId}:${doc.gymId}`);
      },
    };
    const plan: BackfillPlan = {
      toCreate: [
        { userId: "u1", gymId: "g1" },
        { userId: "u2", gymId: "g2" },
      ],
      skippedExisting: [],
      skippedMissingGym: [],
    };

    await applyBackfill(plan, writer, "2026-01-01T00:00:00.000Z");

    expect(calls).toEqual(["clear:u1:g1", "insert:u1:g1", "clear:u2:g2", "insert:u2:g2"]);
  });
});

describe("createMongoMembershipWriter", () => {
  // Proves the fix for the mid-run E11000 abort: the API stays up during the
  // backfill, so a user can save their profile and create this exact
  // {gymId, userId} pair (unique-indexed in membership.repository.mts:19)
  // between the plan read and this write. insertMembership must be an upsert
  // that neither throws nor clobbers the concurrently-created document.
  const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
  const db = client.db("bjj_test_backfill_writer");
  afterAll(async () => {
    await db.dropDatabase();
    await client.close();
  });

  test("a concurrently-created pair does not throw and is not overwritten", async () => {
    const col: Collection<MembershipDoc> = db.collection<MembershipDoc>("gymMemberships");
    await col.createIndex({ gymId: 1, userId: 1 }, { unique: true });

    // Simulates the concurrent write: a user joins for real (via the app's
    // own path) between the backfill's plan read and its write, with a
    // gymRole/joinedAt the backfill must not clobber.
    const concurrentlyCreated: MembershipDoc = {
      _id: "concurrent-1",
      id: "concurrent-1",
      gymId: "g1",
      userId: "u1",
      status: "active",
      verifiedMember: true,
      gymRole: "coach",
      isHome: true,
      visibleInRoster: true,
      joinMethod: "self",
      joinedAt: "2020-01-01T00:00:00.000Z",
      createdAt: "2020-01-01T00:00:00.000Z",
    };
    await col.insertOne(concurrentlyCreated);

    const writer: MembershipWriter = createMongoMembershipWriter(col);

    // Await directly rather than `expect(...).resolves`: Bun's `.resolves`
    // matcher hangs on a mongodb op that carries a client-wide CSOT
    // (`timeoutMS: 4000` above), waiting out the full deadline instead of
    // resolving. A direct await completes in ~2ms; production awaits it the
    // same way. The assertion (resolves to undefined) is unchanged.
    const result: void = await writer.insertMembership({
      _id: "backfill-1",
      id: "backfill-1",
      gymId: "g1",
      userId: "u1",
      status: "active",
      verifiedMember: false,
      gymRole: "member",
      isHome: true,
      visibleInRoster: true,
      joinMethod: "self",
      joinedAt: "2026-07-30T00:00:00.000Z",
      createdAt: "2026-07-30T00:00:00.000Z",
    });
    expect(result).toBeUndefined();

    const docs = await col.find({ gymId: "g1", userId: "u1" }).toArray();
    expect(docs).toHaveLength(1);
    expect(docs[0]?.id).toBe("concurrent-1");
    expect(docs[0]?.gymRole).toBe("coach");
    expect(docs[0]?.joinedAt).toBe("2020-01-01T00:00:00.000Z");
  });
});
