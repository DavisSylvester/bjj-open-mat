// apps/api/test/class.facade.test.mts
import { describe, expect, it } from "bun:test";
import { ClassFacade } from "../src/facades/class.facade.mts";
import type { GymClass, ClassOccurrence, Gym, GymMembership, User } from "@bjj/contract";

interface FacadeSeed {
  classes?: GymClass[];
  occurrences?: ClassOccurrence[];
  gymOwnerId?: string;
  memberships?: GymMembership[];
  users?: User[];
}

interface FacadeResult {
  f: ClassFacade;
  classes: Map<string, GymClass>;
  occ: Map<string, ClassOccurrence>;
  rsvps: Array<{ classId: string; date: string; userId: string; isMember: boolean; rsvpAt: string }>;
}

function facade(seed?: FacadeSeed): FacadeResult {
  const classes = new Map<string, GymClass>();
  (seed?.classes ?? []).forEach((c) => classes.set(c.id, c));
  const occ = new Map<string, ClassOccurrence>(); // key `${classId}:${date}`
  (seed?.occurrences ?? []).forEach((o) => occ.set(`${o.classId}:${o.date}`, o));
  const rsvps: Array<{ classId: string; date: string; userId: string; isMember: boolean; rsvpAt: string }> = [];
  const members = new Map<string, GymMembership>();
  (seed?.memberships ?? []).forEach((m) => members.set(`${m.gymId}:${m.userId}`, m));
  const users = new Map<string, User>();
  (seed?.users ?? []).forEach((u) => users.set(u.id, u));
  const gyms = new Map<string, Gym>([["g1", { id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }]]);

  const classRepo = {
    insert: async (c: GymClass): Promise<GymClass> => { classes.set(c.id, c); return c; },
    findById: async (id: string): Promise<GymClass | null> => classes.get(id) ?? null,
    listActiveByGym: async (g: string): Promise<GymClass[]> => [...classes.values()].filter((c) => c.gymId === g && c.status !== "archived"),
    update: async (id: string, patch: Partial<GymClass>): Promise<GymClass | null> => {
      const cur = classes.get(id); if (!cur) return null; const n = { ...cur, ...patch }; classes.set(id, n); return n;
    },
  };
  const occRepo = {
    upsert: async (o: ClassOccurrence): Promise<ClassOccurrence> => { occ.set(`${o.classId}:${o.date}`, o); return o; },
    find: async (c: string, d: string): Promise<ClassOccurrence | null> => occ.get(`${c}:${d}`) ?? null,
    listByGymRange: async (g: string, from: string, to: string): Promise<ClassOccurrence[]> =>
      [...occ.values()].filter((o) => o.gymId === g && o.date >= from && o.date <= to),
  };
  const rsvpRepo = {
    add: async (c: string, d: string, u: string, isMember: boolean): Promise<void> => {
      if (!rsvps.find((r) => r.classId === c && r.date === d && r.userId === u)) rsvps.push({ classId: c, date: d, userId: u, isMember, rsvpAt: "t" });
    },
    remove: async (c: string, d: string, u: string): Promise<void> => {
      const i = rsvps.findIndex((r) => r.classId === c && r.date === d && r.userId === u); if (i >= 0) rsvps.splice(i, 1);
    },
    count: async (c: string, d: string): Promise<number> => rsvps.filter((r) => r.classId === c && r.date === d).length,
    countsForClassDates: async (c: string, dates: string[]): Promise<Record<string, number>> => {
      const o: Record<string, number> = {};
      for (const d of dates) o[d] = rsvps.filter((r) => r.classId === c && r.date === d).length;
      return o;
    },
    list: async (c: string, d: string): Promise<Array<{ userId: string; isMember: boolean; rsvpAt: string }>> => rsvps.filter((r) => r.classId === c && r.date === d).map((r) => ({ userId: r.userId, isMember: r.isMember, rsvpAt: r.rsvpAt })),
  };
  const memberRepo = { find: async (g: string, u: string): Promise<GymMembership | null> => members.get(`${g}:${u}`) ?? null };
  const gymRepo = { findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null };
  const userRepo = { findById: async (id: string): Promise<User | null> => users.get(id) ?? null };
  let n = 0;
  return { f: new ClassFacade(classRepo, occRepo, rsvpRepo, memberRepo, gymRepo, userRepo, () => `id-${n++}`), classes, occ, rsvps };
}

const recur = (over: Partial<GymClass> = {}): GymClass => ({
  id: over.id ?? "c1", gymId: "g1", title: "Fundamentals", classType: "fundamentals",
  giType: "gi", skillLevel: "beginner", isRecurring: true, dayOfWeek: 1 /* Monday */,
  startTime: "18:00", endTime: "19:00", status: "active", ...over,
});

describe("ClassFacade.schedule (expansion)", () => {
  it("expands a Monday recurring class across two weeks", async () => {
    const { f } = facade({ classes: [recur()] });
    // 2026-08-03 and 2026-08-10 are Mondays.
    const s = await f.schedule("g1", "2026-08-01", "2026-08-14");
    expect(s.map((x) => x.date)).toEqual(["2026-08-03", "2026-08-10"]);
    expect(s[0]?.status).toBe("scheduled");
    expect(s[0]?.goingCount).toBe(0);
  });

  it("applies a cancellation override without dropping the occurrence", async () => {
    const { f } = facade({
      classes: [recur()],
      occurrences: [{ id: "o", classId: "c1", gymId: "g1", date: "2026-08-10", status: "cancelled" }],
    });
    const s = await f.schedule("g1", "2026-08-01", "2026-08-14");
    expect(s.find((x) => x.date === "2026-08-10")?.status).toBe("cancelled");
  });

  it("includes a one-off class only within range", async () => {
    const oneOff = recur({ id: "c2", isRecurring: false, dayOfWeek: undefined, specificDate: "2026-08-06" });
    const { f } = facade({ classes: [oneOff] });
    expect((await f.schedule("g1", "2026-08-01", "2026-08-07")).map((x) => x.classId)).toEqual(["c2"]);
    expect(await f.schedule("g1", "2026-08-08", "2026-08-14")).toEqual([]);
  });
});

describe("ClassFacade authorization + rsvp", () => {
  it("create requires owner/coach/admin and validates schedule shape", async () => {
    const { f } = facade({ gymOwnerId: "owner1" });
    await expect(f.create("stranger", "g1", { title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, startTime: "18:00", endTime: "19:00" }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
    await expect(f.create("owner1", "g1", { title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, startTime: "18:00", endTime: "19:00" }, "gym_owner"))
      .rejects.toMatchObject({ code: "bad_request" }); // recurring but no dayOfWeek
    const ok = await f.create("owner1", "g1", { title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00" }, "gym_owner");
    expect(ok.status).toBe("active");
  });

  it("rsvp snapshots membership and blocks a cancelled occurrence", async () => {
    const { f, rsvps } = facade({
      classes: [recur()],
      occurrences: [{ id: "o", classId: "c1", gymId: "g1", date: "2026-08-10", status: "cancelled" }],
      memberships: [{ id: "m", gymId: "g1", userId: "u1", status: "active", verifiedMember: true, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }],
    });
    await f.rsvp("u1", "c1", "2026-08-03");
    expect(rsvps[0]?.isMember).toBe(true);
    await expect(f.rsvp("u1", "c1", "2026-08-10")).rejects.toMatchObject({ code: "conflict" });
  });

  it("rsvp blocks when capacity is full", async () => {
    const { f } = facade({ classes: [recur({ capacity: 1 })] });
    await f.rsvp("a", "c1", "2026-08-03");
    await expect(f.rsvp("b", "c1", "2026-08-03")).rejects.toMatchObject({ code: "conflict" });
  });

  it("override rejects a date that is not an occurrence of the class", async () => {
    const { f } = facade({ classes: [recur()], gymOwnerId: "owner1" });
    // 2026-08-04 is a Tuesday; class is Monday-only.
    await expect(f.overrideOccurrence("owner1", "c1", "2026-08-04", { status: "cancelled" }, "gym_owner"))
      .rejects.toMatchObject({ code: "bad_request" });
  });
});
