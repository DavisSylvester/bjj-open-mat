import { describe, expect, it } from "bun:test";
import { CheckInFacade } from "../src/facades/check-in.facade.mts";
import type { CheckInRepository } from "../src/repositories/check-in.repository.mts";
import type { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { CheckIn, Gym, OpenMatDetail, User } from "@bjj/contract";

type FakeCheckInRepo = Pick<
  CheckInRepository,
  "insert" | "findById" | "setReview" | "listByUser" | "listBySession" | "ensureIndexes" | "ratingStatsForGym" | "listReviews"
>;

function repo(seed: CheckIn[]): FakeCheckInRepo {
  const map = new Map(seed.map((c) => [c.id, c]));
  return {
    insert: async (c: CheckIn): Promise<CheckIn> => { map.set(c.id, c); return c; },
    findById: async (id: string): Promise<CheckIn | null> => map.get(id) ?? null,
    setReview: async (id: string, r: { rating: number; review?: string; categoryRatings: CheckIn["categoryRatings"]; reviewedAt: string }): Promise<CheckIn | null> => {
      const cur = map.get(id); if (!cur) return null; const next = { ...cur, ...r }; map.set(id, next); return next;
    },
    listByUser: async (): Promise<{ items: CheckIn[]; total: number }> => ({ items: [...map.values()], total: map.size }),
    listBySession: async (): Promise<CheckIn[]> => [...map.values()],
    ensureIndexes: async (): Promise<void> => {},
    ratingStatsForGym: async (gymId: string): Promise<{ avg: number; count: number }> => {
      const rated = [...map.values()].filter((c) => c.gymId === gymId && c.rating != null);
      if (!rated.length) return { avg: 0, count: 0 };
      return { avg: rated.reduce((s, c) => s + (c.rating ?? 0), 0) / rated.length, count: rated.length };
    },
    listReviews: async (): Promise<{ items: CheckIn[]; total: number }> => {
      const items = [...map.values()].filter((c) => c.rating != null);
      return { items, total: items.length };
    },
  };
}

function gyms(): Pick<GymRepository, "update"> {
  return { update: async (_id: string, _patch: Partial<Gym>): Promise<Gym | null> => null };
}

const MAT: OpenMatDetail = {
  id: "om-1", gymId: "g-1", title: "Fri Night", startTime: "19:00", endTime: "21:00",
  isRecurring: true, skillLevel: "all", giType: "both", isCancelled: false,
  gymName: "Atos HQ", address: "9587 Distribution Ave", city: "San Diego", state: "CA",
  latitude: 32.901, longitude: -117.213,
} as OpenMatDetail;

function openMats(mat: OpenMatDetail | null = MAT): Pick<OpenMatRepository, "findById"> {
  return { findById: async (): Promise<OpenMatDetail | null> => mat };
}
function users(user: User | null = { id: "u-1", email: "a@b.dev", displayName: "Marcus", beltRank: "purple", settings: { theme: "glass", notifyRsvp: true, notifySessionUpdates: true } } as User): Pick<UserRepository, "findById"> {
  return { findById: async (): Promise<User | null> => user };
}

const ratings = { instruction: 5, cleanliness: 5, variety: 5, worth_returning: 5, overall: 5 };

describe("CheckInFacade", () => {
  it("accepts a review within 48h", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-x", () => now);
    const updated = await facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings });
    expect(updated.rating).toBe(5);
  });

  it("rejects a review after 48h with conflict", async () => {
    const now = new Date("2026-06-25T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-x", () => now);
    await expect(facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "conflict" });
  });

  it("rejects a review from a different user", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-x", () => now);
    await expect(facade.review("c-1", "other", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "forbidden" });
  });
});

describe("CheckInFacade.checkIn", () => {
  it("verifies when GPS is within 500m of the gym", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-1", () => new Date("2026-06-22T19:05:00Z"));
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 32.9012, longitude: -117.2131, note: "5 rounds", rounds: 5, intensity: 4, partners: 3 });
    expect(c.locationStatus).toBe("verified");
    expect(c.distanceM!).toBeLessThan(500);
    expect(c.gymName).toBe("Atos HQ");
    expect(c.gymId).toBe("g-1");
    expect(c.gymCity).toBe("San Diego");
    expect(c.openMatTitle).toBe("Fri Night");
    expect(c.userName).toBe("Marcus");
    expect(c.beltRank).toBe("purple");
    expect(c.rounds).toBe(5);
    expect(c.intensity).toBe(4);
    expect(c.partners).toBe(3);
    expect(c.latitude).toBe(32.9012);
  });
  it("flags far when GPS is beyond 500m", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-2");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 34.05, longitude: -118.24 });
    expect(c.locationStatus).toBe("far");
    expect(c.distanceM!).toBeGreaterThan(500);
  });
  it("no_location when GPS is omitted", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-3");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22" });
    expect(c.locationStatus).toBe("no_location");
    expect(c.distanceM).toBeUndefined();
  });
  it("no_location when the gym has no coordinates", async () => {
    const r = repo([]);
    const matNoGeo = { ...MAT, latitude: undefined, longitude: undefined } as OpenMatDetail;
    const f = new CheckInFacade(r, openMats(matNoGeo), users(), gyms(), () => "c-4");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2 });
    expect(c.locationStatus).toBe("no_location");
  });
  it("falls back to the user's belt when the request omits it", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), gyms(), () => "c-5");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22" });
    expect(c.beltRank).toBe("purple");
  });
  it("throws not_found for a missing open mat", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(null), users(), gyms(), () => "c-6");
    await expect(f.checkIn("missing", "u-1", { sessionDate: "2026-06-22" })).rejects.toMatchObject({ code: "not_found" });
  });
});
