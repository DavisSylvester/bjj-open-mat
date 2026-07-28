// apps/api/test/class-journal.facade.test.mts
import { describe, expect, it } from "bun:test";
import { ClassJournalFacade } from "../src/facades/class-journal.facade.mts";
import type { ClassJournalEntry, InstructorRating, GymClass, ClassOccurrence, Gym, GymMembership, User } from "@bjj/contract";

function facade(seed?: { cls?: GymClass; occ?: ClassOccurrence; membership?: GymMembership; users?: User[] }): { f: ClassJournalFacade; ratings: InstructorRating[] } {
  const journals = new Map<string, ClassJournalEntry>();
  const ratings: InstructorRating[] = [];
  const cls: GymClass = seed?.cls ?? {
    id: "c1", gymId: "g1", title: "Fundamentals", classType: "fundamentals", giType: "gi", skillLevel: "beginner",
    isRecurring: true, dayOfWeek: 1 /* Monday */, startTime: "18:00", endTime: "19:00", status: "active",
    instructorUserId: "inst-default",
  };
  const occ = seed?.occ ?? null;
  const memberships = new Map<string, GymMembership>();
  if (seed?.membership) memberships.set(`${seed.membership.gymId}:${seed.membership.userId}`, seed.membership);
  const users = new Map<string, User>();
  (seed?.users ?? []).forEach((u) => users.set(u.id, u));
  const gyms = new Map<string, Gym>([["g1", { id: "g1", name: "A", address: "x", amenities: [], isVerified: true }]]);

  const journalRepo = {
    upsert: async (e: ClassJournalEntry): Promise<ClassJournalEntry> => {
      const k = `${e.classId}:${e.date}:${e.userId}`; const cur = journals.get(k);
      const merged = { ...e, id: cur?.id ?? e.id }; journals.set(k, merged); return merged;
    },
    findMine: async (c: string, d: string, u: string): Promise<ClassJournalEntry | null> => journals.get(`${c}:${d}:${u}`) ?? null,
    listByUserRange: async (u: string): Promise<ClassJournalEntry[]> => [...journals.values()].filter((e) => e.userId === u),
    listSharedForOccurrence: async (c: string, d: string): Promise<ClassJournalEntry[]> =>
      [...journals.values()].filter((e) => e.classId === c && e.date === d && e.shared),
  };
  const ratingRepo = {
    upsert: async (r: InstructorRating): Promise<InstructorRating> => {
      const i = ratings.findIndex((x) => x.classId === r.classId && x.date === r.date && x.ratedByUserId === r.ratedByUserId);
      if (i >= 0) ratings[i] = r; else ratings.push(r); return r;
    },
    summaryForInstructor: async (id: string): Promise<{ avg: number; count: number }> => {
      const rs = ratings.filter((x) => x.instructorUserId === id);
      if (rs.length === 0) return { avg: 0, count: 0 };
      return { avg: rs.reduce((a, x) => a + x.stars, 0) / rs.length, count: rs.length };
    },
    listForGymInstructor: async (g: string): Promise<InstructorRating[]> => ratings.filter((x) => x.gymId === g),
  };
  const classRepo = { findById: async (id: string): Promise<GymClass | null> => (id === cls.id ? cls : null) };
  const occRepo = { find: async (): Promise<ClassOccurrence | null> => occ };
  const memberRepo = { find: async (g: string, u: string): Promise<GymMembership | null> => memberships.get(`${g}:${u}`) ?? null };
  const gymRepo = { findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null };
  const userRepo = { findById: async (id: string): Promise<User | null> => users.get(id) ?? null };
  let n = 0;
  return { f: new ClassJournalFacade(journalRepo, ratingRepo, classRepo, occRepo, memberRepo, gymRepo, userRepo, () => `id-${n++}`), ratings };
}

const activeMember = (userId: string): GymMembership => ({
  id: "m", gymId: "g1", userId, status: "active", verifiedMember: true, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t",
});

describe("ClassJournalFacade", () => {
  it("non-member cannot journal", async () => {
    const { f } = facade();
    await expect(f.upsertJournal("stranger", "c1", { date: "2026-08-03" }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("member journals a valid occurrence; rejects a non-occurrence date", async () => {
    const { f } = facade({ membership: activeMember("u1") });
    const e = await f.upsertJournal("u1", "c1", { date: "2026-08-03", whatWasTaught: "guard", techniqueTags: ["armbar"], shared: true }, "practitioner");
    expect(e.whatWasTaught).toBe("guard");
    expect(e.techniqueTags).toEqual(["armbar"]);
    // 2026-08-04 is a Tuesday; class is Monday-only.
    await expect(f.upsertJournal("u1", "c1", { date: "2026-08-04" }, "practitioner")).rejects.toMatchObject({ code: "bad_request" });
  });

  it("rating snapshots the occurrence override instructor over the class default", async () => {
    const { f, ratings } = facade({
      membership: activeMember("u1"),
      occ: { id: "o", classId: "c1", gymId: "g1", date: "2026-08-03", status: "scheduled", instructorUserId: "sub-coach" },
    });
    await f.rateInstructor("u1", "c1", { date: "2026-08-03", stars: 5 }, "practitioner");
    expect(ratings[0]?.instructorUserId).toBe("sub-coach");
  });

  it("gym feedback hides the name when anonymous", async () => {
    const { f } = facade({
      membership: { ...activeMember("owner1"), gymRole: "owner" },
      users: [{ id: "u1", email: "u@x.co", displayName: "Alice" }],
    });
    await f.rateInstructor("u1", "c1", { date: "2026-08-03", stars: 4, anonymous: true }, "practitioner");
    // owner1 is a member here; make them the caller with owner gymRole so assertCanManageGym passes.
    const items = await f.gymInstructorFeedback("owner1", "g1", undefined, undefined, undefined, "practitioner");
    expect(items[0]?.anonymous).toBe(true);
    expect(items[0]?.ratedByName).toBeUndefined();
  });

  it("instructor summary aggregates member ratings", async () => {
    const { f } = facade({ membership: activeMember("u1") });
    await f.rateInstructor("u1", "c1", { date: "2026-08-03", stars: 4 }, "practitioner");
    const s = await f.instructorSummary("inst-default");
    expect(s.count).toBe(1);
    expect(s.avg).toBe(4);
  });
});
