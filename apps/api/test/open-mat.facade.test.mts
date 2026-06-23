import { describe, expect, it } from "bun:test";
import { OpenMatFacade } from "../src/facades/open-mat.facade.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import type { Gym, OpenMatDetail } from "@bjj/contract";

type FakeMatRepo = Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount" | "ensureIndexes">;
type FakeGymRepo = Pick<GymRepository, "findById" | "insert">;
type FakeRsvpRepo = Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">;

function deps(): { matRepo: FakeMatRepo; gymRepo: FakeGymRepo; rsvpRepo: FakeRsvpRepo; counts: Map<string, number>; insertedGyms: Gym[] } {
  const mats = new Map<string, OpenMatDetail>();
  const counts = new Map<string, number>();
  const rsvps: Array<{ k: string; userId: string }> = [];
  const insertedGyms: Gym[] = [];
  const gym: Gym = { id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, location: { lat: 1, lng: 2 }, city: "SD", state: "CA" };
  return {
    matRepo: {
      insert: async (d: OpenMatDetail, _gymOwnerId: string | undefined): Promise<OpenMatDetail> => { mats.set(d.id, d); return d; },
      findById: async (id: string): Promise<OpenMatDetail | null> => mats.get(id) ?? null,
      update: async (id: string, patch: Partial<OpenMatDetail>): Promise<OpenMatDetail | null> => {
        const cur = mats.get(id); if (!cur) return null; const next = { ...cur, ...patch }; mats.set(id, next); return next;
      },
      list: async (): Promise<{ items: OpenMatDetail[]; total: number }> => ({ items: [...mats.values()], total: mats.size }),
      findNearby: async (): Promise<OpenMatDetail[]> => [...mats.values()],
      setAttendeeCount: async (id: string, c: number): Promise<void> => { counts.set(id, c); },
      ensureIndexes: async (): Promise<void> => {},
    },
    gymRepo: {
      findById: async (id: string): Promise<Gym | null> => (id === "g-1" ? gym : null),
      insert: async (g: Gym): Promise<Gym> => { insertedGyms.push(g); return g; },
    },
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
    insertedGyms,
  };
}

describe("OpenMatFacade", () => {
  it("create denormalizes gym name + location", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    const created = await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.gymName).toBe("Atos");
    expect(created.latitude).toBe(1);
    expect(created.giType).toBe("both");
  });

  it("creates an open mat for a gym without a location", async () => {
    const d = deps();
    // override gymRepo to return a location-less gym
    const facade = new OpenMatFacade(
      d.matRepo,
      {
        findById: async (): Promise<Gym> => ({ id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, city: "SD", state: "CA" }),
        insert: async (g: Gym): Promise<Gym> => g,
      },
      d.rsvpRepo,
      () => "om-2",
    );
    const created = await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.id).toBe("om-2");
    expect(created.latitude).toBeUndefined();
  });

  it("rsvp is idempotent and updates attendeeCount", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    const r1 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    const r2 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    expect(r1.attendeeCount).toBe(1);
    expect(r2.attendeeCount).toBe(1);
    expect(d.counts.get("om-1")).toBe(1);
  });

  it("assertOwner resolves for the owning gym owner", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await expect(facade.assertOwner("owner-1", "om-1")).resolves.toBeUndefined();
  });

  it("assertOwner rejects with forbidden for a non-owner", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await expect(facade.assertOwner("intruder", "om-1")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("assertOwner rejects with not_found for a missing mat", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await expect(facade.assertOwner("owner-1", "missing")).rejects.toMatchObject({ code: "not_found" });
  });

  it("non-owner submission is live but unverified", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-x");
    const created = await facade.create("stranger", "practitioner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.verified).toBe(false);
    expect(created.status).toBe("live");
    expect(created.hostId).toBe("stranger");
  });

  it("gym owner submission to own gym is verified", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-y");
    const created = await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.verified).toBe(true);
  });

  it("admin submission is verified", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-z");
    const created = await facade.create("anyadmin", "admin", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.verified).toBe(true);
  });

  it("newGym creates an unverified ownerless gym", async () => {
    const d = deps();
    let n = 0;
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => `id-${++n}`);
    const created = await facade.create("stranger", "practitioner", { newGym: { name: "Fresh BJJ", address: "9 St" }, title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.gymName).toBe("Fresh BJJ");
    expect(created.verified).toBe(false);
    expect(d.insertedGyms.length).toBe(1);
    expect(d.insertedGyms[0].isVerified).toBe(false);
    expect(d.insertedGyms[0].ownerId).toBeUndefined();
  });

  it("verify sets verified=true for the gym owner; rejects others", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-v");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    const v = await facade.verify("owner-1", "gym_owner", "om-v");
    expect(v.verified).toBe(true);
    await expect(facade.verify("intruder", "practitioner", "om-v")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("verify rejects not_found for a missing mat", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-m");
    await expect(facade.verify("owner-1", "gym_owner", "missing")).rejects.toMatchObject({ code: "not_found" });
  });

  it("setHidden(false) returns a session to live", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-u");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await facade.setHidden("owner-1", "gym_owner", "om-u", true);
    const live = await facade.setHidden("owner-1", "gym_owner", "om-u", false);
    expect(live.status).toBe("live");
  });

  it("admin can hide any session", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-h");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    const h = await facade.setHidden("someadmin", "admin", "om-h", true);
    expect(h.status).toBe("hidden");
  });

  it("admin can update a session at a gym they do not own", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-adm");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Original", startTime: "19:00", endTime: "21:00" });
    const updated = await facade.update("some-admin", "admin", "om-adm", { title: "Updated" });
    expect(updated.title).toBe("Updated");
  });

  it("non-owner non-admin update is rejected with forbidden", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-rej");
    await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    await expect(facade.update("intruder", "practitioner", "om-rej", { title: "Hacked" })).rejects.toMatchObject({ code: "forbidden" });
  });
});
