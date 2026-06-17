import { describe, expect, it } from "bun:test";
import { CheckInFacade } from "../src/facades/check-in.facade.mts";
import type { CheckInRepository } from "../src/repositories/check-in.repository.mts";
import type { CheckIn } from "@bjj/contract";

type FakeCheckInRepo = Pick<CheckInRepository, "insert" | "findById" | "setReview" | "listByUser" | "listBySession" | "ensureIndexes">;

function repo(seed: CheckIn[]): FakeCheckInRepo {
  const map = new Map(seed.map((c) => [c.id, c]));
  return {
    insert: async (c: CheckIn): Promise<CheckIn> => { map.set(c.id, c); return c; },
    findById: async (id: string): Promise<CheckIn | null> => map.get(id) ?? null,
    setReview: async (id: string, r: { rating: number; review?: string; categoryRatings: CheckIn["categoryRatings"] }): Promise<CheckIn | null> => {
      const cur = map.get(id); if (!cur) return null; const next = { ...cur, ...r }; map.set(id, next); return next;
    },
    listByUser: async (): Promise<{ items: CheckIn[]; total: number }> => ({ items: [...map.values()], total: map.size }),
    listBySession: async (): Promise<CheckIn[]> => [...map.values()],
    ensureIndexes: async (): Promise<void> => {},
  };
}

const ratings = { instruction: 5, cleanliness: 5, variety: 5, worth_returning: 5, overall: 5 };

describe("CheckInFacade", () => {
  it("accepts a review within 48h", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    const updated = await facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings });
    expect(updated.rating).toBe(5);
  });

  it("rejects a review after 48h with conflict", async () => {
    const now = new Date("2026-06-25T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    await expect(facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "conflict" });
  });

  it("rejects a review from a different user", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    await expect(facade.review("c-1", "other", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "forbidden" });
  });
});
