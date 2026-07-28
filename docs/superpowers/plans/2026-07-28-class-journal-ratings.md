# Class Journaling + Instructor Ratings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an active gym member keep a private (opt-in shareable) journal per class occurrence ("what was taught" + technique tags + training log) and rate that occurrence's instructor, with a public aggregate on the instructor's profile and private detailed feedback to the gym.

**Architecture:** TypeBox contracts in `@bjj/contract` → MongoDB repositories → a `ClassJournalFacade` (membership authorization, effective-instructor resolution, journal + rating upserts, aggregate + gym-feedback reads) → Elysia routes via DI. Reuses the class occurrence keying (`classId`+`date`), the exported `occursOn` validity check, the shared `gym-authz` authorizers, and belt/star-rating widgets on the Flutter side.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^7`), Flutter + Riverpod + Dio. Tests: `bun test` (API), `flutter test` (mobile).

## Global Constraints

- TypeScript strict; **no `any`**; explicit return types + access modifiers; explicit variable types.
- Validation is **TypeBox only** (never Zod). Schema-first, `Static<typeof X>`, `$id` on every schema.
- `.mts` source; import specifiers use `.mjs`. Contract TEST files import from source (e.g. `../src/index.mts`) per the sibling-test convention. One concern per file; barrel via `index.mts`; named exports.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `debugPrint`.
- Layering router → facade → repository; DI via `container.mts`, no `new` in routers. Repo deps via `Pick<>`.
- MongoDB driver `mongodb@^7`. Beware `null !== undefined` on optional fields; Mongo rejects empty `$set`; never put the same field in both `$set` and `$setOnInsert` on an upsert.
- Route param is `:id` where it collides at a path position (memoirist). Existing: `/api/v1/gyms/:id`, `/api/v1/classes/:id`, `/api/v1/users/:id`.
- Health endpoints `/health` and `/ready` only.
- Date convention (matches class schedule): a `YYYY-MM-DD` date's weekday is `new Date(`${d}T00:00:00Z`).getUTCDay()` (0=Sunday). `occursOn(cls, date)` (exported from `apps/api/src/facades/class.facade.mts`) is the occurrence-validity check.
- Conventional Commits; **never** add Co-Authored-By. Do NOT commit `packages/contract/src/index.mjs` (gitignored). Commit per task.
- Run `bunx eslint --fix` on changed `apps/api`/`packages/contract` files before each commit; `flutter analyze` clean on changed mobile files.

---

## File Structure

**`packages/contract/src`**
- `schemas/class-journal-entry.mts` — `ClassJournalEntry`
- `schemas/instructor-rating.mts` — `InstructorRating`, `InstructorRatingSummary`, `InstructorFeedbackItem`
- `schemas/requests/journal-requests.mts` — `UpsertJournalRequest`, `JournalRangeQuery`, `OccurrenceJournalQuery`, `UpsertInstructorRatingRequest`, `InstructorFeedbackQuery`
- barrels: `schemas/index.mts`, `schemas/requests/index.mts`

**`apps/api/src`**
- `facades/gym-authz.mts` — add `assertActiveMember`
- `repositories/class-journal.repository.mts` — `ClassJournalRepository`
- `repositories/instructor-rating.repository.mts` — `InstructorRatingRepository`
- `facades/class-journal.facade.mts` — `ClassJournalFacade`
- `routes/class-journal.routes.mts` — route module
- Modify: `db/collections.mts`, `container.mts`, `app.mts`, `openapi.mts`

**`apps/mobile/lib/features/classes`**
- `models/class_journal_entry.dart`, `models/instructor_rating_summary.dart`, `models/instructor_feedback_item.dart`
- `data/class_journal_repository.dart` (+ providers)
- `screens/class_journal_form_screen.dart`, `screens/instructor_feedback_screen.dart`
- widgets as needed (technique-tag editor, star selector reuse)
- Modify: `core/api/endpoints.dart`, `screens/class_occurrence_screen.dart`, the My-Training screen, `app/router.dart`

---

## Task 1: `ClassJournalEntry` schema + journal requests

**Files:**
- Create: `packages/contract/src/schemas/class-journal-entry.mts`, `schemas/requests/journal-requests.mts` (journal parts)
- Modify: `packages/contract/src/schemas/index.mts`, `schemas/requests/index.mts`
- Test: `packages/contract/test/class-journal-schema.test.mts`

**Interfaces:**
- Produces:
  - `ClassJournalEntry` = `{ id, classId, gymId, userId, date, whatWasTaught?, techniqueTags: string[] (default []), rounds?: int>=0, intensity?: int 1..5, partners?: int>=0, note?, shared: boolean (default false), createdAt?, updatedAt? }`
  - `UpsertJournalRequest` = `{ date, whatWasTaught?, techniqueTags?: string[], rounds?, intensity?, partners?, note?, shared?: boolean }`
  - `JournalRangeQuery` = `{ from, to }`
  - `OccurrenceJournalQuery` = `{ date }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/class-journal-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ClassJournalEntry, UpsertJournalRequest } from "../src/index.mts";

describe("ClassJournalEntry schema", () => {
  it("parses a minimal entry with defaults", () => {
    const e = Value.Parse(ClassJournalEntry, {
      id: "j1", classId: "c1", gymId: "g1", userId: "u1", date: "2026-08-03",
    });
    expect(e.techniqueTags).toEqual([]);
    expect(e.shared).toBe(false);
  });
  it("rejects intensity above 5", () => {
    expect(Value.Check(ClassJournalEntry, {
      id: "j1", classId: "c1", gymId: "g1", userId: "u1", date: "2026-08-03",
      techniqueTags: [], shared: false, intensity: 6,
    })).toBe(false);
  });
});

describe("UpsertJournalRequest", () => {
  it("requires date, everything else optional", () => {
    expect(Value.Check(UpsertJournalRequest, { date: "2026-08-03" })).toBe(true);
    expect(Value.Check(UpsertJournalRequest, {})).toBe(false);
    expect(Value.Check(UpsertJournalRequest, { date: "2026-08-03", techniqueTags: ["armbar"], shared: true })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/class-journal-schema.test.mts`
Expected: FAIL — schemas not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/class-journal-entry.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ClassJournalEntry = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    userId: t.String(),
    date: t.String({ description: "ISO YYYY-MM-DD" }),
    whatWasTaught: t.Optional(t.String()),
    techniqueTags: t.Array(t.String(), { default: [] }),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
    note: t.Optional(t.String()),
    shared: t.Boolean({ default: false }),
    createdAt: t.Optional(t.String()),
    updatedAt: t.Optional(t.String()),
  },
  { $id: "ClassJournalEntry" },
);
export type ClassJournalEntry = Static<typeof ClassJournalEntry>;
```

```ts
// packages/contract/src/schemas/requests/journal-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const UpsertJournalRequest = t.Object(
  {
    date: t.String(),
    whatWasTaught: t.Optional(t.String()),
    techniqueTags: t.Optional(t.Array(t.String())),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
    note: t.Optional(t.String()),
    shared: t.Optional(t.Boolean()),
  },
  { $id: "UpsertJournalRequest" },
);
export type UpsertJournalRequest = Static<typeof UpsertJournalRequest>;

export const JournalRangeQuery = t.Object(
  { from: t.String(), to: t.String() },
  { $id: "JournalRangeQuery" },
);
export type JournalRangeQuery = Static<typeof JournalRangeQuery>;

export const OccurrenceJournalQuery = t.Object(
  { date: t.String() },
  { $id: "OccurrenceJournalQuery" },
);
export type OccurrenceJournalQuery = Static<typeof OccurrenceJournalQuery>;
```

Add to `schemas/index.mts`: `export * from "./class-journal-entry.mts";`
Add to `schemas/requests/index.mts`: `export * from "./journal-requests.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/class-journal-schema.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/schemas/class-journal-entry.mts packages/contract/src/schemas/requests/journal-requests.mts packages/contract/src/schemas/index.mts packages/contract/src/schemas/requests/index.mts packages/contract/test/class-journal-schema.test.mts
git commit -m "feat(contract): add ClassJournalEntry + journal request schemas"
```

---

## Task 2: `InstructorRating` + summary + feedback schemas + rating requests

**Files:**
- Create: `packages/contract/src/schemas/instructor-rating.mts`
- Modify: `packages/contract/src/schemas/requests/journal-requests.mts` (add rating request + feedback query), `schemas/index.mts`, `schemas/requests/index.mts`
- Test: `packages/contract/test/instructor-rating-schema.test.mts`

**Interfaces:**
- Produces:
  - `InstructorRating` = `{ id, classId, gymId, date, instructorUserId?, instructorName?, ratedByUserId, stars: int 1..5, comment?, anonymous: boolean (default false), createdAt? }`
  - `InstructorRatingSummary` = `{ instructorUserId, avg: number, count: int>=0 }`
  - `InstructorFeedbackItem` = `{ classId, date, stars: int 1..5, comment?, ratedByName?, anonymous: boolean, createdAt? }`
  - `UpsertInstructorRatingRequest` = `{ date, stars: int 1..5, comment?, anonymous?: boolean }`
  - `InstructorFeedbackQuery` = `{ instructorUserId?: string, from?: string, to?: string }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/instructor-rating-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { InstructorRating, InstructorRatingSummary, UpsertInstructorRatingRequest } from "../src/index.mts";

describe("InstructorRating", () => {
  it("parses with default anonymous false", () => {
    const r = Value.Parse(InstructorRating, {
      id: "r1", classId: "c1", gymId: "g1", date: "2026-08-03",
      ratedByUserId: "u1", stars: 5,
    });
    expect(r.anonymous).toBe(false);
  });
  it("rejects stars out of range", () => {
    expect(Value.Check(InstructorRating, {
      id: "r1", classId: "c1", gymId: "g1", date: "2026-08-03", ratedByUserId: "u1", stars: 0, anonymous: false,
    })).toBe(false);
  });
});

describe("UpsertInstructorRatingRequest", () => {
  it("requires date + stars", () => {
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03", stars: 4 })).toBe(true);
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03" })).toBe(false);
    expect(Value.Check(UpsertInstructorRatingRequest, { date: "2026-08-03", stars: 6 })).toBe(false);
  });
});

describe("InstructorRatingSummary", () => {
  it("carries avg + count", () => {
    expect(Value.Check(InstructorRatingSummary, { instructorUserId: "i1", avg: 4.5, count: 12 })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/instructor-rating-schema.test.mts`
Expected: FAIL — schemas not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/instructor-rating.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const InstructorRating = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    date: t.String(),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    ratedByUserId: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    anonymous: t.Boolean({ default: false }),
    createdAt: t.Optional(t.String()),
  },
  { $id: "InstructorRating" },
);
export type InstructorRating = Static<typeof InstructorRating>;

export const InstructorRatingSummary = t.Object(
  {
    instructorUserId: t.String(),
    avg: t.Number({ minimum: 0, maximum: 5 }),
    count: t.Integer({ minimum: 0 }),
  },
  { $id: "InstructorRatingSummary" },
);
export type InstructorRatingSummary = Static<typeof InstructorRatingSummary>;

export const InstructorFeedbackItem = t.Object(
  {
    classId: t.String(),
    date: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    ratedByName: t.Optional(t.String()),
    anonymous: t.Boolean(),
    createdAt: t.Optional(t.String()),
  },
  { $id: "InstructorFeedbackItem" },
);
export type InstructorFeedbackItem = Static<typeof InstructorFeedbackItem>;
```

Append to `schemas/requests/journal-requests.mts`:

```ts
export const UpsertInstructorRatingRequest = t.Object(
  {
    date: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    anonymous: t.Optional(t.Boolean()),
  },
  { $id: "UpsertInstructorRatingRequest" },
);
export type UpsertInstructorRatingRequest = Static<typeof UpsertInstructorRatingRequest>;

export const InstructorFeedbackQuery = t.Object(
  {
    instructorUserId: t.Optional(t.String()),
    from: t.Optional(t.String()),
    to: t.Optional(t.String()),
  },
  { $id: "InstructorFeedbackQuery" },
);
export type InstructorFeedbackQuery = Static<typeof InstructorFeedbackQuery>;
```

Add to `schemas/index.mts`: `export * from "./instructor-rating.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/instructor-rating-schema.test.mts`; then full `cd packages/contract && bun test`.
Expected: PASS (all green).

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src packages/contract/test/instructor-rating-schema.test.mts
git commit -m "feat(contract): add InstructorRating, summary, feedback + rating requests"
```

---

## Task 3: `assertActiveMember` shared authorizer + collections

**Files:**
- Modify: `apps/api/src/facades/gym-authz.mts`, `apps/api/src/db/collections.mts`
- Test: `apps/api/test/gym-authz-member.test.mts`

**Interfaces:**
- Consumes: `GymAuthzDeps` (`{ gyms: { findById }, memberships: { find } }`), `UserRole`, `AppError`.
- Produces `assertActiveMember(deps, userId, gymId, role): Promise<void>` — passes if `role === 'admin'`, or `gym.ownerId === userId`, or an active membership exists at the gym; throws `not_found` if gym missing, else `forbidden`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/gym-authz-member.test.mts
import { describe, expect, it } from "bun:test";
import { assertActiveMember } from "../src/facades/gym-authz.mts";
import type { Gym, GymMembership } from "@bjj/contract";

function deps(gym: Gym | null, membership: GymMembership | null) {
  return {
    gyms: { findById: async (): Promise<Gym | null> => gym },
    memberships: { find: async (): Promise<GymMembership | null> => membership },
  };
}
const gym = (ownerId?: string): Gym => ({ id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId });
const active: GymMembership = { id: "m", gymId: "g1", userId: "u", status: "active", verifiedMember: true, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" };

describe("assertActiveMember", () => {
  it("admin passes", async () => { await assertActiveMember(deps(gym(), null), "u", "g1", "admin"); });
  it("gym owner passes", async () => { await assertActiveMember(deps(gym("owner1"), null), "owner1", "g1", "practitioner"); });
  it("active member passes", async () => { await assertActiveMember(deps(gym(), active), "u", "g1", "practitioner"); });
  it("non-member is forbidden", async () => {
    await expect(assertActiveMember(deps(gym(), null), "u", "g1", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });
  it("inactive membership is forbidden", async () => {
    await expect(assertActiveMember(deps(gym(), { ...active, status: "pending" }), "u", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });
  it("missing gym is not_found", async () => {
    await expect(assertActiveMember(deps(null, null), "u", "ghost", "practitioner")).rejects.toMatchObject({ code: "not_found" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/gym-authz-member.test.mts`
Expected: FAIL — `assertActiveMember` not exported.

- [ ] **Step 3: Write minimal implementation**

Append to `apps/api/src/facades/gym-authz.mts` (reuse the existing `GymAuthzDeps` interface + imports):

```ts
export async function assertActiveMember(
  deps: GymAuthzDeps, userId: string, gymId: string, role: UserRole,
): Promise<void> {
  if (role === "admin") return;
  const gym: Gym | null = await deps.gyms.findById(gymId);
  if (!gym) throw new AppError("not_found", `Gym ${gymId} not found`);
  if (gym.ownerId === userId) return;
  const membership: GymMembership | null = await deps.memberships.find(gymId, userId);
  if (membership && membership.status === "active") return;
  throw new AppError("forbidden", "Requires active gym membership");
}
```

(Ensure `Gym`, `GymMembership`, `UserRole` are imported at the top — `assertCanManageGym` already imports `Gym`/`GymMembership`/`UserRole`; if any is missing add it.)

Add to `apps/api/src/db/collections.mts` inside `COLLECTIONS`:

```ts
  classJournals: "classJournals",
  instructorRatings: "instructorRatings",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/gym-authz-member.test.mts` then `bun test test/gym-authz.test.mts` (existing `assertCanManageGym` tests must still pass).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/gym-authz.mts apps/api/src/db/collections.mts apps/api/test/gym-authz-member.test.mts
git commit -m "feat(api): assertActiveMember authorizer + journal/rating collections"
```

---

## Task 4: `ClassJournalRepository`

**Files:**
- Create: `apps/api/src/repositories/class-journal.repository.mts`
- Test: `apps/api/test/class-journal.repository.test.mts`

**Interfaces:**
- Consumes `ClassJournalEntry`, `COLLECTIONS.classJournals`.
- Produces `ClassJournalRepository`:
  - `ensureIndexes()` — unique `{ classId, date, userId }`, `{ userId, date: -1 }`, `{ classId, date, shared }`.
  - `upsert(e: ClassJournalEntry): Promise<ClassJournalEntry>` — by `(classId,date,userId)`; `$set` the mutable fields + `updatedAt`; `$setOnInsert` `{ _id, id, createdAt }`.
  - `findMine(classId, date, userId): Promise<ClassJournalEntry | null>`
  - `listByUserRange(userId, from, to): Promise<ClassJournalEntry[]>` — newest first.
  - `listSharedForOccurrence(classId, date): Promise<ClassJournalEntry[]>` — `shared: true`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class-journal.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassJournalRepository } from "../src/repositories/class-journal.repository.mts";
import type { ClassJournalEntry } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_journal");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const e = (over: Partial<ClassJournalEntry>): ClassJournalEntry => ({
  id: over.id ?? "j1", classId: over.classId ?? "c1", gymId: "g1", userId: over.userId ?? "u1",
  date: over.date ?? "2026-08-03", techniqueTags: over.techniqueTags ?? [], shared: over.shared ?? false,
  createdAt: "t", ...over,
});

describe("ClassJournalRepository", () => {
  it("upsert is idempotent per (class,date,user) and updates fields", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(e({ id: "first", whatWasTaught: "guard" }));
    await repo.upsert(e({ id: "second", whatWasTaught: "mount", shared: true }));
    const mine = await repo.findMine("c1", "2026-08-03", "u1");
    expect(mine?.id).toBe("first");            // id set on insert only
    expect(mine?.whatWasTaught).toBe("mount"); // field updated
    expect(mine?.shared).toBe(true);
  });

  it("listSharedForOccurrence returns only shared entries", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.upsert(e({ id: "s", classId: "c2", userId: "a", shared: true }));
    await repo.upsert(e({ id: "p", classId: "c2", userId: "b", shared: false }));
    const shared = await repo.listSharedForOccurrence("c2", "2026-08-03");
    expect(shared.map((x) => x.userId)).toEqual(["a"]);
  });

  it("listByUserRange filters by date window newest-first", async () => {
    const repo = new ClassJournalRepository(db);
    await repo.upsert(e({ id: "old", classId: "c3", userId: "r", date: "2026-08-01" }));
    await repo.upsert(e({ id: "new", classId: "c4", userId: "r", date: "2026-08-20" }));
    const rows = await repo.listByUserRange("r", "2026-08-01", "2026-08-31");
    expect(rows.map((x) => x.date)).toEqual(["2026-08-20", "2026-08-01"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class-journal.repository.test.mts`
Expected: FAIL — module not found. (Local Mongo on 27017 required.)

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/class-journal.repository.mts
import type { Db } from "mongodb";
import type { ClassJournalEntry } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface JournalDoc extends ClassJournalEntry {
  _id: string;
}

export class ClassJournalRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<JournalDoc>(COLLECTIONS.classJournals);
    await col.createIndex({ classId: 1, date: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1, date: -1 });
    await col.createIndex({ classId: 1, date: 1, shared: 1 });
  }

  public async upsert(e: ClassJournalEntry): Promise<ClassJournalEntry> {
    const { id, classId, date, userId, createdAt, ...rest } = e;
    const now: string = new Date().toISOString();
    await this.collection<JournalDoc>(COLLECTIONS.classJournals).updateOne(
      { classId, date, userId },
      {
        $set: { classId, date, userId, ...rest, updatedAt: now },
        $setOnInsert: { _id: id, id, createdAt: createdAt ?? now },
      },
      { upsert: true },
    );
    return (await this.findMine(classId, date, userId)) as ClassJournalEntry;
  }

  public async findMine(classId: string, date: string, userId: string): Promise<ClassJournalEntry | null> {
    return stripId<ClassJournalEntry>(
      await this.collection<JournalDoc>(COLLECTIONS.classJournals).findOne({ classId, date, userId }),
    );
  }

  public async listByUserRange(userId: string, from: string, to: string): Promise<ClassJournalEntry[]> {
    const docs = await this.collection<JournalDoc>(COLLECTIONS.classJournals)
      .find({ userId, date: { $gte: from, $lte: to } }).sort({ date: -1 }).toArray();
    return docs.map((d) => stripId<ClassJournalEntry>(d) as ClassJournalEntry);
  }

  public async listSharedForOccurrence(classId: string, date: string): Promise<ClassJournalEntry[]> {
    const docs = await this.collection<JournalDoc>(COLLECTIONS.classJournals)
      .find({ classId, date, shared: true }).toArray();
    return docs.map((d) => stripId<ClassJournalEntry>(d) as ClassJournalEntry);
  }
}
```

> `rest` excludes `updatedAt` only if present on the input; since the domain object may carry `updatedAt`, drop it from `rest` before spreading to avoid a `$set` duplicate — simplest: the destructure above keeps `updatedAt` in `rest`, and we override it with `updatedAt: now` after the spread, so the later key wins. That is valid (single `$set` object, last key wins) and not a Mongo conflict.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class-journal.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/class-journal.repository.mts apps/api/test/class-journal.repository.test.mts
git commit -m "feat(api): ClassJournalRepository (upsert, my-range, shared-for-occurrence)"
```

---

## Task 5: `InstructorRatingRepository`

**Files:**
- Create: `apps/api/src/repositories/instructor-rating.repository.mts`
- Test: `apps/api/test/instructor-rating.repository.test.mts`

**Interfaces:**
- Consumes `InstructorRating`, `COLLECTIONS.instructorRatings`.
- Produces `InstructorRatingRepository`:
  - `ensureIndexes()` — unique `{ classId, date, ratedByUserId }`, `{ instructorUserId }`, `{ gymId, instructorUserId, date }`.
  - `upsert(r: InstructorRating): Promise<InstructorRating>` — by `(classId,date,ratedByUserId)`; `$set` mutable fields; `$setOnInsert` `{ _id, id, createdAt }`.
  - `summaryForInstructor(instructorUserId): Promise<{ avg: number; count: number }>` — aggregation avg(stars)+count; `{ avg: 0, count: 0 }` when none. `avg` rounded to 1 decimal.
  - `listForGymInstructor(gymId, instructorUserId?, from?, to?): Promise<InstructorRating[]>` — newest first.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/instructor-rating.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { InstructorRatingRepository } from "../src/repositories/instructor-rating.repository.mts";
import type { InstructorRating } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_instructor_rating");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const r = (over: Partial<InstructorRating>): InstructorRating => ({
  id: over.id ?? "r1", classId: over.classId ?? "c1", gymId: "g1", date: over.date ?? "2026-08-03",
  instructorUserId: over.instructorUserId ?? "inst1", ratedByUserId: over.ratedByUserId ?? "u1",
  stars: over.stars ?? 5, anonymous: over.anonymous ?? false, createdAt: "t", ...over,
});

describe("InstructorRatingRepository", () => {
  it("upsert idempotent per (class,date,rater), summary averages", async () => {
    const repo = new InstructorRatingRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(r({ id: "a", ratedByUserId: "u1", stars: 4 }));
    await repo.upsert(r({ id: "b", ratedByUserId: "u1", stars: 2 })); // same rater+occurrence -> update
    await repo.upsert(r({ id: "c", ratedByUserId: "u2", stars: 4 }));
    const s = await repo.summaryForInstructor("inst1");
    expect(s.count).toBe(2);          // two distinct raters
    expect(s.avg).toBe(3);            // (2 + 4) / 2
  });

  it("summary is zero for an unrated instructor", async () => {
    const repo = new InstructorRatingRepository(db);
    expect(await repo.summaryForInstructor("nobody")).toEqual({ avg: 0, count: 0 });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/instructor-rating.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/instructor-rating.repository.mts
import type { Db } from "mongodb";
import type { InstructorRating } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface RatingDoc extends InstructorRating {
  _id: string;
}

export class InstructorRatingRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<RatingDoc>(COLLECTIONS.instructorRatings);
    await col.createIndex({ classId: 1, date: 1, ratedByUserId: 1 }, { unique: true });
    await col.createIndex({ instructorUserId: 1 });
    await col.createIndex({ gymId: 1, instructorUserId: 1, date: 1 });
  }

  public async upsert(r: InstructorRating): Promise<InstructorRating> {
    const { id, classId, date, ratedByUserId, createdAt, ...rest } = r;
    const now: string = new Date().toISOString();
    await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).updateOne(
      { classId, date, ratedByUserId },
      { $set: { classId, date, ratedByUserId, ...rest }, $setOnInsert: { _id: id, id, createdAt: createdAt ?? now } },
      { upsert: true },
    );
    const doc = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).findOne({ classId, date, ratedByUserId });
    return stripId<InstructorRating>(doc) as InstructorRating;
  }

  public async summaryForInstructor(instructorUserId: string): Promise<{ avg: number; count: number }> {
    const rows = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).aggregate<{ avg: number; count: number }>([
      { $match: { instructorUserId } },
      { $group: { _id: "$instructorUserId", avg: { $avg: "$stars" }, count: { $sum: 1 } } },
    ]).toArray();
    if (rows.length === 0) return { avg: 0, count: 0 };
    return { avg: Math.round((rows[0]!.avg) * 10) / 10, count: rows[0]!.count };
  }

  public async listForGymInstructor(
    gymId: string, instructorUserId?: string, from?: string, to?: string,
  ): Promise<InstructorRating[]> {
    const filter: Record<string, unknown> = { gymId };
    if (instructorUserId !== undefined) filter["instructorUserId"] = instructorUserId;
    if (from !== undefined || to !== undefined) {
      const range: Record<string, string> = {};
      if (from !== undefined) range["$gte"] = from;
      if (to !== undefined) range["$lte"] = to;
      filter["date"] = range;
    }
    const docs = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).find(filter).sort({ date: -1 }).toArray();
    return docs.map((d) => stripId<InstructorRating>(d) as InstructorRating);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/instructor-rating.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/instructor-rating.repository.mts apps/api/test/instructor-rating.repository.test.mts
git commit -m "feat(api): InstructorRatingRepository (upsert, summary aggregate, gym feedback list)"
```

---

## Task 6: `ClassJournalFacade`

**Files:**
- Create: `apps/api/src/facades/class-journal.facade.mts`
- Test: `apps/api/test/class-journal.facade.test.mts`

**Interfaces:**
- Consumes (via `Pick`): `ClassJournalRepository` (`upsert|findMine|listByUserRange|listSharedForOccurrence`), `InstructorRatingRepository` (`upsert|summaryForInstructor|listForGymInstructor`), `ClassRepository` (`findById`), `ClassOccurrenceRepository` (`find`), `MembershipRepository` (`find`), `GymRepository` (`findById`), `UserRepository` (`findById`), `assertActiveMember`, `assertCanManageGym`, `occursOn` (from `class.facade.mts`), `IdFactory`.
- Produces `ClassJournalFacade`:
  - `upsertJournal(userId, classId, req: UpsertJournalRequest, role): Promise<ClassJournalEntry>` — resolve class (404), `assertActiveMember`, validate `occursOn` (400), upsert (preserve existing id/createdAt when editing).
  - `myJournal(userId, from, to): Promise<ClassJournalEntry[]>`
  - `sharedForOccurrence(userId, classId, date, role): Promise<ClassJournalEntry[]>` — `assertActiveMember`; returns shared entries plus the caller's own (deduped).
  - `rateInstructor(userId, classId, req: UpsertInstructorRatingRequest, role): Promise<InstructorRating>` — resolve class (404), `assertActiveMember`, validate `occursOn` (400), resolve effective instructor (override's instructor if set else class's), upsert.
  - `instructorSummary(instructorUserId): Promise<InstructorRatingSummary>`
  - `gymInstructorFeedback(callerId, gymId, instructorUserId?, from?, to?, role): Promise<InstructorFeedbackItem[]>` — `assertCanManageGym`; maps ratings → items, hiding `ratedByName` when `anonymous`.
- Effective-instructor helper (private): `resolveInstructor(cls, occ): { instructorUserId?: string; instructorName?: string }` = `{ instructorUserId: occ?.instructorUserId ?? cls.instructorUserId, instructorName: occ?.instructorName ?? cls.instructorName }`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class-journal.facade.test.mts
import { describe, expect, it } from "bun:test";
import { ClassJournalFacade } from "../src/facades/class-journal.facade.mts";
import type { ClassJournalEntry, InstructorRating, GymClass, ClassOccurrence, Gym, GymMembership, User } from "@bjj/contract";

function facade(seed?: { cls?: GymClass; occ?: ClassOccurrence; membership?: GymMembership; users?: User[] }) {
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class-journal.facade.test.mts`
Expected: FAIL — `ClassJournalFacade` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/facades/class-journal.facade.mts
import type {
  ClassJournalEntry, ClassOccurrence, GymClass, InstructorFeedbackItem, InstructorRating,
  InstructorRatingSummary, UpsertInstructorRatingRequest, UpsertJournalRequest, UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import { assertActiveMember, assertCanManageGym } from "./gym-authz.mts";
import { occursOn } from "./class.facade.mts";
import type { ClassJournalRepository } from "../repositories/class-journal.repository.mts";
import type { InstructorRatingRepository } from "../repositories/instructor-rating.repository.mts";
import type { ClassRepository } from "../repositories/class.repository.mts";
import type { ClassOccurrenceRepository } from "../repositories/class-occurrence.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

type IdFactory = () => string;
type JournalRepo = Pick<ClassJournalRepository, "upsert" | "findMine" | "listByUserRange" | "listSharedForOccurrence">;
type RatingRepo = Pick<InstructorRatingRepository, "upsert" | "summaryForInstructor" | "listForGymInstructor">;
type ClassRepo = Pick<ClassRepository, "findById">;
type OccRepo = Pick<ClassOccurrenceRepository, "find">;
type MemberRepo = Pick<MembershipRepository, "find">;
type GymRepo = Pick<GymRepository, "findById">;
type UserRepo = Pick<UserRepository, "findById">;

export class ClassJournalFacade {

  public constructor(
    private readonly journals: JournalRepo,
    private readonly ratings: RatingRepo,
    private readonly classes: ClassRepo,
    private readonly occurrences: OccRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  private async getClassOr404(classId: string): Promise<GymClass> {
    const cls = await this.classes.findById(classId);
    if (!cls) throw new AppError("not_found", `Class ${classId} not found`);
    return cls;
  }

  private authzDeps(): { gyms: GymRepo; memberships: MemberRepo } {
    return { gyms: this.gyms, memberships: this.memberships };
  }

  public async upsertJournal(userId: string, classId: string, req: UpsertJournalRequest, role: UserRole): Promise<ClassJournalEntry> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    if (!occursOn(cls, req.date)) throw new AppError("bad_request", `${req.date} is not an occurrence of class ${classId}`);
    const existing = await this.journals.findMine(classId, req.date, userId);
    const entry: ClassJournalEntry = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, userId, date: req.date,
      whatWasTaught: req.whatWasTaught,
      techniqueTags: req.techniqueTags ?? existing?.techniqueTags ?? [],
      rounds: req.rounds, intensity: req.intensity, partners: req.partners, note: req.note,
      shared: req.shared ?? existing?.shared ?? false,
      createdAt: existing?.createdAt,
    };
    return this.journals.upsert(entry);
  }

  public async myJournal(userId: string, from: string, to: string): Promise<ClassJournalEntry[]> {
    return this.journals.listByUserRange(userId, from, to);
  }

  public async sharedForOccurrence(userId: string, classId: string, date: string, role: UserRole): Promise<ClassJournalEntry[]> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    const shared = await this.journals.listSharedForOccurrence(classId, date);
    const mine = await this.journals.findMine(classId, date, userId);
    if (mine && !shared.some((e) => e.userId === userId)) return [mine, ...shared];
    return shared;
  }

  private resolveInstructor(cls: GymClass, occ: ClassOccurrence | null): { instructorUserId?: string; instructorName?: string } {
    return {
      instructorUserId: occ?.instructorUserId ?? cls.instructorUserId,
      instructorName: occ?.instructorName ?? cls.instructorName,
    };
  }

  public async rateInstructor(userId: string, classId: string, req: UpsertInstructorRatingRequest, role: UserRole): Promise<InstructorRating> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    if (!occursOn(cls, req.date)) throw new AppError("bad_request", `${req.date} is not an occurrence of class ${classId}`);
    const occ = await this.occurrences.find(classId, req.date);
    const instructor = this.resolveInstructor(cls, occ);
    const existing = (await this.ratings.listForGymInstructor(cls.gymId)).find(
      (r) => r.classId === classId && r.date === req.date && r.ratedByUserId === userId,
    );
    const rating: InstructorRating = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, date: req.date,
      instructorUserId: instructor.instructorUserId,
      instructorName: instructor.instructorName,
      ratedByUserId: userId, stars: req.stars, comment: req.comment,
      anonymous: req.anonymous ?? false,
      createdAt: existing?.createdAt,
    };
    return this.ratings.upsert(rating);
  }

  public async instructorSummary(instructorUserId: string): Promise<InstructorRatingSummary> {
    const s = await this.ratings.summaryForInstructor(instructorUserId);
    return { instructorUserId, avg: s.avg, count: s.count };
  }

  public async gymInstructorFeedback(
    callerId: string, gymId: string, instructorUserId: string | undefined,
    from: string | undefined, to: string | undefined, role: UserRole,
  ): Promise<InstructorFeedbackItem[]> {
    await assertCanManageGym(this.authzDeps(), callerId, gymId, role);
    const rows = await this.ratings.listForGymInstructor(gymId, instructorUserId, from, to);
    return Promise.all(rows.map(async (r): Promise<InstructorFeedbackItem> => {
      let ratedByName: string | undefined;
      if (!r.anonymous) {
        const u = await this.users.findById(r.ratedByUserId);
        ratedByName = u?.displayName;
      }
      return { classId: r.classId, date: r.date, stars: r.stars, comment: r.comment, ratedByName, anonymous: r.anonymous, createdAt: r.createdAt };
    }));
  }
}
```

> Note: `rateInstructor` reads existing via `listForGymInstructor` to preserve `id`/`createdAt` on edit; the repo's unique index guarantees one row per `(classId,date,ratedByUserId)`, so the upsert updates in place. `myJournal`/`gymInstructorFeedback` do not gate on the target being a real occurrence — they are read views over stored data.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class-journal.facade.test.mts`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/class-journal.facade.mts apps/api/test/class-journal.facade.test.mts
git commit -m "feat(api): ClassJournalFacade (journal/rating upserts, effective instructor, aggregate, feedback)"
```

---

## Task 7: routes + container + app wiring

**Files:**
- Create: `apps/api/src/routes/class-journal.routes.mts`
- Modify: `apps/api/src/container.mts`, `apps/api/src/app.mts`
- Test: `apps/api/test/class-journal.routes.test.mts`

**Interfaces:**
- Consumes: `container.classJournalFacade`, `authPlugin`, `requireAuth`, `data`/`list`, request schemas from Tasks 1–2.
- Produces routes (model on `class.routes.mts` — prefixed Elysia instances, `:id` params, `requireId` helper):
  - `POST /api/v1/classes/:id/journal` (auth, `UpsertJournalRequest`) → `data(upsertJournal)`
  - `GET /api/v1/classes/:id/journal` (auth, `OccurrenceJournalQuery`) → `list(sharedForOccurrence)`
  - `GET /api/v1/users/me/journal` (auth, `JournalRangeQuery`) → `list(myJournal)`
  - `POST /api/v1/classes/:id/instructor-rating` (auth, `UpsertInstructorRatingRequest`) → `data(rateInstructor)`
  - `GET /api/v1/users/:id/instructor-rating` (public) → `data(instructorSummary)`
  - `GET /api/v1/gyms/:id/instructor-feedback` (auth, `InstructorFeedbackQuery`) → `list(gymInstructorFeedback)`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class-journal.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { classJournalRoutes } from "../src/routes/class-journal.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const classJournalFacade = {
    upsertJournal: async (u: string, c: string) => { calls.push(`journal:${u}:${c}`); return { id: "j1", classId: c, gymId: "g1", userId: u, date: "2026-08-03", techniqueTags: [], shared: false }; },
    myJournal: async () => [],
    sharedForOccurrence: async () => [],
    rateInstructor: async (u: string, c: string) => { calls.push(`rate:${u}:${c}`); return { id: "r1", classId: c, gymId: "g1", date: "2026-08-03", ratedByUserId: u, stars: 5, anonymous: false }; },
    instructorSummary: async (id: string) => { calls.push(`summary:${id}`); return { instructorUserId: id, avg: 0, count: 0 }; },
    gymInstructorFeedback: async () => [],
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    classJournalFacade,
  } as unknown as Container;
  return { app: new Elysia().use(classJournalRoutes(container)), calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("class journal routes", () => {
  it("GET instructor-rating summary is public", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/users/inst1/instructor-rating"));
    expect(res.status).toBe(200);
    expect(calls).toContain("summary:inst1");
  });
  it("POST journal requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/journal", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST journal calls facade with caller id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/journal", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("journal:u1:c1");
  });
}
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class-journal.routes.test.mts`
Expected: FAIL — `classJournalRoutes` not found.

- [ ] **Step 3: Write minimal implementation**

Model `class-journal.routes.mts` on `apps/api/src/routes/class.routes.mts`: apply `authPlugin(container.verifier, container.roleLookup)`; use two prefixed Elysia instances (`/api/v1/classes` and `/api/v1/users`, plus `/api/v1/gyms` for feedback — one instance per prefix, matching how class routes split gyms vs classes); a `requireId(identity)` helper; `data`/`list` envelopes; `requireAuth: true` on all but `GET /users/:id/instructor-rating`; request schemas as `body`/`query` validators. Handlers read `params.id` and delegate to `container.classJournalFacade`, passing `requireId(identity).userId` and `identity.role`. The eslint-disable-return-type comment on the export, per convention.

Wire the container (`apps/api/src/container.mts`):
- import `ClassJournalRepository`, `InstructorRatingRepository`, `ClassJournalFacade`.
- construct `classJournalRepo`, `instructorRatingRepo`; add `readonly classJournalFacade: ClassJournalFacade;` to `Container`; build `classJournalFacade: new ClassJournalFacade(classJournalRepo, instructorRatingRepo, classRepo, classOccurrenceRepo, membershipRepo, gymRepo, userRepo, id)` (reuse existing repos).
- in `ensureIndexes()` add `await classJournalRepo.ensureIndexes(); await instructorRatingRepo.ensureIndexes();`.

Wire `app.mts`: import `classJournalRoutes`, add `.use(classJournalRoutes(container))`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class-journal.routes.test.mts`, then `bun test test/boot.test.mts`, then full `bun test`.
Expected: PASS; no regressions.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/routes/class-journal.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/class-journal.routes.test.mts
git commit -m "feat(api): class journal + instructor rating routes wired into container and app"
```

---

## Task 8: OpenAPI + Postman docs

**Files:** Modify `apps/api/src/openapi.mts`, regenerate `apps/api/openapi.json`, add a "Class Journal & Ratings" Postman folder.

**Interfaces:** none (docs).

- [ ] **Step 1:** In `openapi.mts` (hand-listed), add the 6 paths with request/response schema refs: `POST /api/v1/classes/{id}/journal` (`UpsertJournalRequest`→`ClassJournalEntry`), `GET /api/v1/classes/{id}/journal` (`OccurrenceJournalQuery`→`ClassJournalEntry[]`), `GET /api/v1/users/me/journal` (`JournalRangeQuery`→`ClassJournalEntry[]`), `POST /api/v1/classes/{id}/instructor-rating` (`UpsertInstructorRatingRequest`→`InstructorRating`), `GET /api/v1/users/{id}/instructor-rating` (→`InstructorRatingSummary`), `GET /api/v1/gyms/{id}/instructor-feedback` (`InstructorFeedbackQuery`→`InstructorFeedbackItem[]`). Register component schemas: `ClassJournalEntry`, `InstructorRating`, `InstructorRatingSummary`, `InstructorFeedbackItem`, `UpsertJournalRequest`, `UpsertInstructorRatingRequest`, `JournalRangeQuery`, `OccurrenceJournalQuery`, `InstructorFeedbackQuery`.
- [ ] **Step 2:** Regenerate committed `apps/api/openapi.json` (same method as prior features). Add the Postman folder mirroring existing folders.
- [ ] **Step 3:** `cd apps/api && bun test` — full suite green.
- [ ] **Step 4: Commit**

```bash
git add apps/api/src/openapi.mts apps/api/openapi.json docs/postman
git commit -m "docs(api): document class journal + instructor rating endpoints"
```

---

## Task 9: Flutter models + endpoints

**Files:**
- Create: `apps/mobile/lib/features/classes/models/class_journal_entry.dart`, `models/instructor_rating_summary.dart`, `models/instructor_feedback_item.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/mobile/test/classes/class_journal_entry_test.dart`

**Interfaces:**
- Dart models with const ctor + `fromJson` mirroring the contract (camelCase keys). `Endpoints`:
  - `classJournal(String classId) => '/api/v1/classes/$classId/journal'`
  - `myJournal = '/api/v1/users/me/journal'` (static const)
  - `classInstructorRating(String classId) => '/api/v1/classes/$classId/instructor-rating'`
  - `userInstructorRating(String userId) => '/api/v1/users/$userId/instructor-rating'`
  - `gymInstructorFeedback(String gymId) => '/api/v1/gyms/$gymId/instructor-feedback'`

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/classes/class_journal_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';

void main() {
  test('ClassJournalEntry.fromJson maps fields + tags', () {
    final e = ClassJournalEntry.fromJson(const {
      'id': 'j1', 'classId': 'c1', 'gymId': 'g1', 'userId': 'u1', 'date': '2026-08-03',
      'whatWasTaught': 'guard passing', 'techniqueTags': ['armbar', 'triangle'],
      'intensity': 4, 'shared': true,
    });
    expect(e.classId, 'c1');
    expect(e.techniqueTags, ['armbar', 'triangle']);
    expect(e.shared, true);
    expect(e.intensity, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/classes/class_journal_entry_test.dart`
Expected: FAIL — model not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/mobile/lib/features/classes/models/class_journal_entry.dart
class ClassJournalEntry {
  final String id;
  final String classId;
  final String gymId;
  final String userId;
  final String date;
  final String? whatWasTaught;
  final List<String> techniqueTags;
  final int? rounds;
  final int? intensity;
  final int? partners;
  final String? note;
  final bool shared;

  const ClassJournalEntry({
    required this.id,
    required this.classId,
    required this.gymId,
    required this.userId,
    required this.date,
    this.whatWasTaught,
    this.techniqueTags = const [],
    this.rounds,
    this.intensity,
    this.partners,
    this.note,
    this.shared = false,
  });

  factory ClassJournalEntry.fromJson(Map<String, dynamic> json) => ClassJournalEntry(
        id: json['id'] as String,
        classId: json['classId'] as String,
        gymId: json['gymId'] as String,
        userId: json['userId'] as String,
        date: json['date'] as String,
        whatWasTaught: json['whatWasTaught'] as String?,
        techniqueTags: (json['techniqueTags'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        rounds: json['rounds'] as int?,
        intensity: json['intensity'] as int?,
        partners: json['partners'] as int?,
        note: json['note'] as String?,
        shared: json['shared'] as bool? ?? false,
      );
}
```

Create `instructor_rating_summary.dart` (`instructorUserId`, `avg` as `num`→`double`, `count`) and `instructor_feedback_item.dart` (`classId, date, stars, comment?, ratedByName?, anonymous, createdAt?`) the same way. Add the `Endpoints` helpers under a `// Class Journal & Ratings` section.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/classes/class_journal_entry_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/classes/models apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/classes/class_journal_entry_test.dart
git commit -m "feat(mobile): class journal + instructor rating models + endpoints"
```

---

## Task 10: Flutter journal repository + providers

**Files:**
- Create: `apps/mobile/lib/features/classes/data/class_journal_repository.dart`
- Test: `apps/mobile/test/classes/class_journal_repository_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `unwrapList`/`unwrapData`, `ApiException`, models from Task 9.
- Produces `ClassJournalRepository` (abstract) + `ApiClassJournalRepository` (matches `class_repository.dart` pattern):
  - `Future<ClassJournalEntry> upsertJournal(String classId, Map<String,dynamic> body)` — POST `classJournal`.
  - `Future<List<ClassJournalEntry>> myJournal({required String from, required String to})` — GET `myJournal` query.
  - `Future<List<ClassJournalEntry>> sharedForOccurrence(String classId, String date)` — GET `classJournal` query `{date}`.
  - `Future<void> rateInstructor(String classId, Map<String,dynamic> body)` — POST `classInstructorRating`.
  - `Future<InstructorRatingSummary> instructorSummary(String userId)` — GET `userInstructorRating`.
  - `Future<List<InstructorFeedbackItem>> gymInstructorFeedback(String gymId, {String? instructorUserId, String? from, String? to})` — GET `gymInstructorFeedback` query.
- Providers: `classJournalRepositoryProvider`; `myJournalProvider = FutureProvider.family<List<ClassJournalEntry>, ({String from, String to})>`; `sharedNotesProvider = FutureProvider.family<List<ClassJournalEntry>, ({String classId, String date})>`; `myClassJournalEntryProvider`? (optional) ; `instructorSummaryProvider = FutureProvider.family<InstructorRatingSummary, String>`.

- [ ] **Step 1: Write the failing test** — fake Dio adapter returns a `{"data":{...ClassJournalEntry...}}` envelope for the POST journal; assert `upsertJournal('c1', {...})` returns the parsed entry. Model on `class_repository_test.dart`.
- [ ] **Step 2:** `cd apps/mobile && flutter test test/classes/class_journal_repository_test.dart` → FAIL.
- [ ] **Step 3:** Implement modeled on `class_repository.dart` (try/catch DioException → ApiException.fromDio; `unwrapData`/`unwrapList`). Providers like the class ones.
- [ ] **Step 4:** `flutter test test/classes/class_journal_repository_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(mobile): class journal repository + providers`.

---

## Task 11: Journal form on occurrence detail (what taught + tags + log + share + rating)

**Files:**
- Create: `apps/mobile/lib/features/classes/screens/class_journal_form_screen.dart`
- Modify: `apps/mobile/lib/features/classes/screens/class_occurrence_screen.dart` (a "Journal this class" action for members), `apps/mobile/lib/app/router.dart`
- Test: `apps/mobile/test/classes/class_journal_form_test.dart`

**Interfaces:**
- Consumes `classJournalRepositoryProvider` (`upsertJournal`, `rateInstructor`), current-user membership gate (reuse the `canJournal`/member derivation: active membership at the class's gym — reuse `rosterProvider(gymId)` membership of current user, or `authStateProvider` admin), `ScheduledClass` for context.
- Produces `ClassJournalFormScreen({required String classId, required String gymId, required String date})`:
  - Fields: whatWasTaught (multiline), technique tags (add via text field + chips, remove on tap), rounds/intensity(1–5)/partners/note, "Share with gym" switch, and an instructor-rating block (star 1–5 selector + comment + "rate anonymously" switch).
  - **Save**: builds the journal body (only set fields) → `upsertJournal(classId, body)`; if a star rating was chosen → `rateInstructor(classId, {date, stars, comment?, anonymous?})`; then invalidate `myJournalProvider` + `sharedNotesProvider((classId,date))` and pop.
  - The occurrence detail's "Journal this class" affordance shows only for members (reuse the occurrence screen's existing member/gym context; it already receives `gymId` from Task-15 of the class-schedule feature).

- [ ] **Step 1:** Widget test: pump `ClassJournalFormScreen(classId:'c1', gymId:'g1', date:'2026-08-03')` with a fake `classJournalRepositoryProvider` recording calls; enter "guard passing", add tag "armbar", toggle Share, pick 5 stars, tap Save; assert `upsertJournal('c1', {...whatWasTaught,'techniqueTags':['armbar'],'shared':true...})` and `rateInstructor('c1', {date:'2026-08-03', stars:5,...})` called. Model harness on the class occurrence/promote-sheet tests. → write test.
- [ ] **Step 2:** `flutter test test/classes/class_journal_form_test.dart` → FAIL.
- [ ] **Step 3:** Implement the form + occurrence-detail affordance + route (`/gym/:id/schedule/occurrence/journal` or push with args — reuse the occurrence screen's nav pattern, passing classId/gymId/date).
- [ ] **Step 4:** `flutter test test/classes/class_journal_form_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): class journal form with technique tags + instructor rating`.

---

## Task 12: Shared notes list + instructor aggregate on occurrence detail

**Files:**
- Modify: `apps/mobile/lib/features/classes/screens/class_occurrence_screen.dart`
- Test: `apps/mobile/test/classes/class_occurrence_shared_notes_test.dart`

**Interfaces:**
- Consumes `sharedNotesProvider((classId, date))` and `instructorSummaryProvider(instructorUserId)`.
- Produces: a **"Shared notes"** section on the occurrence detail listing teammates' shared entries (author name if resolvable, what-was-taught, technique tags); and, when the occurrence has a linked member instructor (`instructorUserId`), an **aggregate rating** display (stars + count) near the instructor line.

- [ ] **Step 1:** Widget test: override `sharedNotesProvider((classId:'c1',date:'2026-08-03'))` → two shared entries; override `instructorSummaryProvider('inst1')` → `{avg:4.5,count:8}`; pump the occurrence screen with an instructor set; assert both shared "what was taught" texts render and "4.5" + count appear. → write test.
- [ ] **Step 2:** `flutter test test/classes/class_occurrence_shared_notes_test.dart` → FAIL.
- [ ] **Step 3:** Implement the shared-notes section + aggregate display.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): shared class notes + instructor aggregate on occurrence detail`.

---

## Task 13: "My Training" class-journal history section

**Files:**
- Modify: the My-Training screen (`apps/mobile/lib/features/training/screens/my_training_screen.dart`)
- Test: `apps/mobile/test/classes/my_journal_history_test.dart`

**Interfaces:**
- Consumes `myJournalProvider((from, to))` (compute a sensible default range, e.g. last 90 days; expose an overridable anchor for deterministic tests).
- Produces a **"Class journal"** section listing my entries newest-first (date, class title if resolvable, what-was-taught, technique-tag chips). Read-only. Separate from the existing check-in list.

- [ ] **Step 1:** Widget test: override `myJournalProvider` → two entries; pump the My-Training screen; assert both entries' what-was-taught render under a "Class journal" heading. → write test.
- [ ] **Step 2:** `flutter test test/classes/my_journal_history_test.dart` → FAIL.
- [ ] **Step 3:** Implement the section.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): class journal history in My Training`.

---

## Task 14: Gym owner/coach instructor-feedback view

**Files:**
- Create: `apps/mobile/lib/features/classes/screens/instructor_feedback_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart`, the gym manage/detail area (a "Instructor feedback" entry gated to owner/coach/admin)
- Test: `apps/mobile/test/classes/instructor_feedback_screen_test.dart`

**Interfaces:**
- Consumes a `gymInstructorFeedbackProvider = FutureProvider.family<List<InstructorFeedbackItem>, String>` (by gymId; add to the repo/providers in this task) and the manage-capability gate (reuse `isAdmin || isOwner || gymRole in {coach,owner}` from the roster/class-manage code).
- Produces `InstructorFeedbackScreen({required String gymId})` — lists feedback items (stars, comment, date, author name or "Anonymous"); only reachable when `canManage`.

- [ ] **Step 1:** Widget test: override the feedback provider → one named + one anonymous item; pump `InstructorFeedbackScreen(gymId:'g1')`; assert both comments render and the anonymous one shows "Anonymous" (no name). → write test.
- [ ] **Step 2:** `flutter test test/classes/instructor_feedback_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement the screen + provider + manager-gated entry + route.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean; run full `cd apps/mobile && flutter test`.
- [ ] **Step 5: Commit** `feat(mobile): gym instructor-feedback view (owner/coach)`.

---

## Task 15: End-to-end verification pass

**Files:** none (verification). Do NOT weaken any test.

- [ ] **Step 1:** API: `cd apps/api && bun test` — full suite green (local Mongo on 27017). Membership + class tests must still pass (Task 3 only ADDS `assertActiveMember`; it must not change `assertCanManageGym`). `cd packages/contract && bun test` — green.
- [ ] **Step 2:** Real API boot smoke — never touch production. Boot with a throwaway local db + self-contained bypass env on a non-default port (as prior features):
  ```
  cd apps/api
  MONGODB_URI="mongodb://localhost:27017/bjj_journal_verify" PORT=3199 \
  AUTH_BYPASS_SECRET="verify-secret" DEMO_USER_ID="verify-user@local" DEMO_USER_ROLE="practitioner" DEMO_USER_EMAIL="verify@local.test" \
  bun run src/index.mts   # background; poll /health; kill stale :3199 first
  ```
  Assert: `GET /api/v1/users/whoever/instructor-rating` → 200 `{"data":{"instructorUserId":"whoever","avg":0,"count":0}}`; `POST /api/v1/classes/nonexistent/journal` WITHOUT auth → 401; `POST /api/v1/classes/nonexistent/journal` WITH `Bearer verify-secret` + body `{"date":"2026-08-03"}` → 404 (class not found). Capture status + body each; kill the server after.
- [ ] **Step 3:** Mobile: `cd apps/mobile && flutter test` — full suite green; `flutter analyze` clean.
- [ ] **Step 4:** Lint: `cd apps/api && bunx eslint --fix` on changed api/contract files; zero errors.
- [ ] **Step 5: Commit** any fixups: `chore: lint and verification fixups for class journal + ratings`.

---

## Self-Review Notes (author)

- **Spec coverage:** ClassJournalEntry (T1) ✓; InstructorRating + summary + feedback + requests (T2) ✓; `assertActiveMember` + collections (T3) ✓; repos (T4, T5) ✓; facade with membership gating + effective-instructor snapshot + aggregate + anonymity + shared-vs-private + occurrence validation (T6) ✓; routes public-vs-auth split + wiring (T7) ✓; docs (T8) ✓; mobile models/endpoints (T9), repo/providers (T10), journal form incl. rating (T11), shared notes + aggregate (T12), My-Training history (T13), owner feedback view (T14) ✓; verification incl. real boot (T15) ✓.
- **Decisions honored:** new `ClassJournalEntry` ✓; private + opt-in share (facade `sharedForOccurrence` returns only shared + own; `shared` default false) ✓; public aggregate (member-only) + gym feedback + anonymity (T6 `instructorSummary`/`gymInstructorFeedback`) ✓; free-text instructors have no public aggregate (summary keyed by `instructorUserId`; free-text ratings carry no `instructorUserId` so they never aggregate) ✓; free-text + technique tags ✓; active-member-only authoring (`assertActiveMember`) ✓; effective-instructor snapshot (override beats class) ✓.
- **Type consistency:** facade method names + repo `Pick` sets match Tasks 4–7; endpoint helpers (T9) match routes (T7); provider record types consistent across T10–T14; `occursOn` import from `class.facade.mts` matches its existing export.
- **Guardrails flagged:** upsert `$set`/`$setOnInsert` no-overlap (T4/T5 destructure id/createdAt into `$setOnInsert` only; `updatedAt` last-key-wins in `$set`); non-occurrence date → `bad_request` (T6); route `:id` split (T7); free-text instructor never produces a public aggregate (T6).
