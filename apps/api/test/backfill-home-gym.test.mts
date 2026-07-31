import { describe, expect, test } from "bun:test";
import {
  applyBackfill,
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
