import { describe, expect, it } from "bun:test";
import { OpenMatFacade } from "../src/facades/open-mat.facade.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import type { Gym, OpenMatDetail } from "@bjj/contract";
import { nullGeocoder } from "./fakes/geocoder.fake.mts";

type FakeMatRepo = Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount">;
type FakeGymRepo = Pick<GymRepository, "findById" | "insert">;
type FakeRsvpRepo = Pick<RsvpRepository, "add" | "remove" | "count" | "userIds" | "countAttendees">;

const OM_ID = "om-page";
const SESSION_DATE = "2026-07-05";

function buildFacade(): OpenMatFacade {
  const mats = new Map<string, OpenMatDetail>();
  const rsvps: Array<{ k: string; userId: string }> = [];
  const gym: Gym = { id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true };

  // seed 25 attendees for one (openMatId, sessionDate)
  const k = `${OM_ID}:${SESSION_DATE}`;
  for (let i = 1; i <= 25; i += 1) rsvps.push({ k, userId: `u-${i}` });

  const matRepo: FakeMatRepo = {
    insert: async (d: OpenMatDetail): Promise<OpenMatDetail> => { mats.set(d.id, d); return d; },
    findById: async (id: string): Promise<OpenMatDetail | null> => mats.get(id) ?? null,
    update: async (id: string, patch: Partial<OpenMatDetail>): Promise<OpenMatDetail | null> => {
      const cur = mats.get(id); if (!cur) return null; const next = { ...cur, ...patch }; mats.set(id, next); return next;
    },
    list: async (): Promise<{ items: OpenMatDetail[]; total: number }> => ({ items: [...mats.values()], total: mats.size }),
    findNearby: async (): Promise<OpenMatDetail[]> => [...mats.values()],
    setAttendeeCount: async (): Promise<void> => {},
  };
  const gymRepo: FakeGymRepo = {
    findById: async (id: string): Promise<Gym | null> => (id === "g-1" ? gym : null),
    insert: async (g: Gym): Promise<Gym> => g,
  };
  const rsvpRepo: FakeRsvpRepo = {
    add: async (): Promise<void> => {},
    remove: async (): Promise<void> => {},
    count: async (omId: string, date: string): Promise<number> => rsvps.filter((r) => r.k === `${omId}:${date}`).length,
    countAttendees: async (omId: string, date: string): Promise<number> => rsvps.filter((r) => r.k === `${omId}:${date}`).length,
    userIds: async (omId: string, date: string, skip = 0, limit?: number): Promise<string[]> => {
      const all = rsvps.filter((r) => r.k === `${omId}:${date}`).map((r) => r.userId);
      return limit === undefined ? all.slice(skip) : all.slice(skip, skip + limit);
    },
  };
  return new OpenMatFacade(matRepo, gymRepo, rsvpRepo, () => "om-1", nullGeocoder);
}

describe("attendee pagination", () => {
  it("page 1 (limit 12) returns 12 ids and total 25", async () => {
    const facade = buildFacade();
    const { ids, total } = await facade.attendeeUserIds(OM_ID, SESSION_DATE, { skip: 0, limit: 12 });
    expect(ids).toHaveLength(12);
    expect(total).toBe(25);
    expect(ids[0]).toBe("u-1");
  });

  it("page 3 (limit 12) returns the last 1 id and total 25", async () => {
    const facade = buildFacade();
    const { ids, total } = await facade.attendeeUserIds(OM_ID, SESSION_DATE, { skip: 24, limit: 12 });
    expect(ids).toHaveLength(1);
    expect(total).toBe(25);
    expect(ids[0]).toBe("u-25");
  });
});
