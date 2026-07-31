import { describe, expect, test } from "bun:test";
import { planBackfill } from "../scripts/backfill-home-gym-memberships.mts";

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
