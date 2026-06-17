import { describe, expect, it } from "bun:test";
import { OpenMatFacade } from "../src/facades/open-mat.facade.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import type { Gym, OpenMatDetail } from "@bjj/contract";

type FakeMatRepo = Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount" | "ensureIndexes">;
type FakeGymRepo = Pick<GymRepository, "findById">;
type FakeRsvpRepo = Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">;

function deps(): { matRepo: FakeMatRepo; gymRepo: FakeGymRepo; rsvpRepo: FakeRsvpRepo; counts: Map<string, number> } {
  const mats = new Map<string, OpenMatDetail>();
  const counts = new Map<string, number>();
  const rsvps: Array<{ k: string; userId: string }> = [];
  const gym: Gym = { id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, location: { lat: 1, lng: 2 }, city: "SD", state: "CA" };
  return {
    matRepo: {
      insert: async (d: OpenMatDetail, _gymOwnerId: string): Promise<OpenMatDetail> => { mats.set(d.id, d); return d; },
      findById: async (id: string): Promise<OpenMatDetail | null> => mats.get(id) ?? null,
      update: async (id: string, patch: Partial<OpenMatDetail>): Promise<OpenMatDetail | null> => {
        const cur = mats.get(id); if (!cur) return null; const next = { ...cur, ...patch }; mats.set(id, next); return next;
      },
      list: async (): Promise<{ items: OpenMatDetail[]; total: number }> => ({ items: [...mats.values()], total: mats.size }),
      findNearby: async (): Promise<OpenMatDetail[]> => [...mats.values()],
      setAttendeeCount: async (id: string, c: number): Promise<void> => { counts.set(id, c); },
      ensureIndexes: async (): Promise<void> => {},
    },
    gymRepo: { findById: async (id: string): Promise<Gym | null> => (id === "g-1" ? gym : null) },
    rsvpRepo: {
      add: async (omId: string, date: string, userId: string): Promise<void> => {
        const k = `${omId}:${date}`;
        if (!rsvps.some((r) => r.k === k && r.userId === userId)) rsvps.push({ k, userId });
      },
      remove: async (omId: string, date: string, userId: string): Promise<void> => {
        const i = rsvps.findIndex((r) => r.k === `${omId}:${date}` && r.userId === userId); if (i >= 0) rsvps.splice(i, 1);
      },
      count: async (omId: string, date: string): Promise<number> => rsvps.filter((r) => r.k === `${omId}:${date}`).length,
      userIds: async (omId: string, date: string): Promise<string[]> => rsvps.filter((r) => r.k === `${omId}:${date}`).map((r) => r.userId),
    },
    counts,
  };
}

describe("OpenMatFacade", () => {
  it("create denormalizes gym name + location", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    const created = await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.gymName).toBe("Atos");
    expect(created.latitude).toBe(1);
    expect(created.giType).toBe("both");
  });

  it("creates an open mat for a gym without a location", async () => {
    const d = deps();
    // override gymRepo to return a location-less gym
    const facade = new OpenMatFacade(
      d.matRepo,
      { findById: async (): Promise<Gym> => ({ id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, city: "SD", state: "CA" }) },
      d.rsvpRepo,
      () => "om-2",
    );
    const created = await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.id).toBe("om-2");
    expect(created.latitude).toBeUndefined();
  });

  it("rsvp is idempotent and updates attendeeCount", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    const r1 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    const r2 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    expect(r1.attendeeCount).toBe(1);
    expect(r2.attendeeCount).toBe(1);
    expect(d.counts.get("om-1")).toBe(1);
  });

  it("assertOwner resolves for the owning gym owner", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await expect(facade.assertOwner("owner-1", "om-1")).resolves.toBeUndefined();
  });

  it("assertOwner rejects with forbidden for a non-owner", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await expect(facade.assertOwner("intruder", "om-1")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("assertOwner rejects with not_found for a missing mat", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await expect(facade.assertOwner("owner-1", "missing")).rejects.toMatchObject({ code: "not_found" });
  });
});
