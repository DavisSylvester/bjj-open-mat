# Gym Class Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a gym owner/coach define a class schedule (recurring, one-off, and per-date overrides) and let anyone view it while any signed-in user RSVPs "going" to a specific occurrence, with the attendee list distinguishing members from visitors.

**Architecture:** TypeBox contracts in `@bjj/contract` → MongoDB repositories → a `ClassFacade` (authorization + pure occurrence-expansion + RSVP) → Elysia routes wired via the DI container. The owner/coach/admin authorization rule is extracted from the shipped `MembershipFacade` into one shared authorizer both facades use. Flutter + Riverpod consumes it via a Dio repository, a weekly timetable screen, an occurrence-detail RSVP screen, and an owner manage flow. Reuses the existing RSVP-by-date pattern and belt-icon widgets.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^7`), Flutter + Riverpod + Dio. Tests: `bun test` (API), `flutter test` (mobile).

## Global Constraints

- TypeScript strict; **no `any`**; explicit return types + access modifiers on all functions/methods; explicit variable types.
- Validation is **TypeBox only** (never Zod). Schema-first: define schema, derive `Static<typeof X>`. `$id` on every schema.
- `.mts` source; import specifiers use `.mjs`. One exported schema/type per concern; barrel via `index.mts`. Named exports.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `debugPrint`.
- Layering is **router → facade → repository**; no data access outside repositories; everything resolved through `container.mts` DI, no `new` in routers.
- MongoDB driver stays `mongodb@^7`. Beware `null !== undefined` on optional Mongo fields — normalize on write and query. Mongo rejects an empty `$set` — no-op on empty patches.
- Route param is `:id` (not `:gymId`/`:classId`) where it collides with existing routes at the same path position — memoirist rejects differing param names. Existing routes use `/api/v1/gyms/:id`.
- Health endpoints are `/health` and `/ready` only.
- Conventional Commits; **never** add Co-Authored-By. Commit per task.
- Run `bunx eslint --fix` on changed `apps/api`/`packages/contract` files before each commit; `flutter analyze` clean on changed mobile files.
- Date convention: a `YYYY-MM-DD` date's weekday is `new Date(`${date}T00:00:00Z`).getUTCDay()` → 0=Sunday..6=Saturday. `GymClass.dayOfWeek` uses the same 0–6 (0=Sunday). Occurrence expansion is deterministic from the `from`/`to` query params (no reliance on "now").

---

## File Structure

**`packages/contract/src`**
- `enums/class-type.mts` — `ClassType`
- `schemas/gym-class.mts` — `GymClass`
- `schemas/class-occurrence.mts` — `ClassOccurrence`
- `schemas/class-rsvp.mts` — `ClassRsvp`
- `schemas/scheduled-class.mts` — `ScheduledClass` (resolved-occurrence response)
- `schemas/requests/class-requests.mts` — `CreateClassRequest`, `UpdateClassRequest`, `OccurrenceOverrideRequest`, `ClassRsvpRequest`, `ScheduleQuery`, `AttendeesQuery`
- barrels: `enums/index.mts`, `schemas/index.mts`, `schemas/requests/index.mts`

**`apps/api/src`**
- `facades/gym-authz.mts` — shared `assertCanManage` authorizer (extracted from membership)
- `facades/membership.facade.mts` — refactor to use the shared authorizer
- `repositories/class.repository.mts` — `ClassRepository`
- `repositories/class-occurrence.repository.mts` — `ClassOccurrenceRepository`
- `repositories/class-rsvp.repository.mts` — `ClassRsvpRepository`
- `facades/class.facade.mts` — `ClassFacade`
- `routes/class.routes.mts` — route module
- Modify: `db/collections.mts`, `container.mts`, `app.mts`, `openapi.mts`

**`apps/mobile/lib/features/classes`**
- `models/` — `gym_class.dart`, `scheduled_class.dart`, `class_attendee.dart`
- `data/class_repository.dart` (+ providers)
- `screens/class_schedule_screen.dart`, `screens/class_occurrence_screen.dart`, `screens/class_edit_screen.dart`
- `widgets/class_type_chip.dart`
- Modify: `core/api/endpoints.dart`, `features/gyms/screens/gym_detail_screen.dart`, `app/router.dart`

---

## Task 1: `ClassType` enum

**Files:**
- Create: `packages/contract/src/enums/class-type.mts`
- Modify: `packages/contract/src/enums/index.mts`
- Test: `packages/contract/test/class-type-enum.test.mts`

**Interfaces:**
- Produces `ClassType` = `'fundamentals'|'all_levels'|'advanced'|'gi'|'nogi'|'kids'|'womens'|'competition'|'private'|'other'` (TypeBox union + `Static`).

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/class-type-enum.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ClassType } from "../src/index.mjs";

describe("ClassType enum", () => {
  it("accepts known types", () => {
    expect(Value.Check(ClassType, "fundamentals")).toBe(true);
    expect(Value.Check(ClassType, "nogi")).toBe(true);
    expect(Value.Check(ClassType, "other")).toBe(true);
  });
  it("rejects unknown types", () => {
    expect(Value.Check(ClassType, "sparring")).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/class-type-enum.test.mts`
Expected: FAIL — `ClassType` not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/enums/class-type.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ClassType = t.Union(
  [
    t.Literal("fundamentals"), t.Literal("all_levels"), t.Literal("advanced"),
    t.Literal("gi"), t.Literal("nogi"), t.Literal("kids"), t.Literal("womens"),
    t.Literal("competition"), t.Literal("private"), t.Literal("other"),
  ],
  { $id: "ClassType" },
);
export type ClassType = Static<typeof ClassType>;
```

Append to `packages/contract/src/enums/index.mts`: `export * from "./class-type.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/class-type-enum.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/enums/class-type.mts packages/contract/src/enums/index.mts packages/contract/test/class-type-enum.test.mts
git commit -m "feat(contract): add ClassType enum"
```

---

## Task 2: `GymClass` + `ClassOccurrence` schemas

**Files:**
- Create: `packages/contract/src/schemas/gym-class.mts`, `schemas/class-occurrence.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `packages/contract/test/class-schema.test.mts`

**Interfaces:**
- Consumes `ClassType` (Task 1), existing `GiType`, `SkillLevel`.
- Produces:
  - `GymClass` = `{ id, gymId, title, classType: ClassType, classTypeLabel?, description?, giType: GiType, skillLevel: SkillLevel, instructorUserId?, instructorName?, isRecurring: boolean(default true), dayOfWeek?: int 0..6, startTime: string, endTime: string, specificDate?: string, capacity?: int>=0, status: 'active'|'archived' (optional union default 'active'), createdAt? }`
  - `ClassOccurrence` = `{ id, classId, gymId, date, status: 'scheduled'|'cancelled' (optional union default 'scheduled'), startTime?, endTime?, instructorUserId?, instructorName?, note? }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/class-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymClass, ClassOccurrence } from "../src/index.mjs";

describe("GymClass schema", () => {
  it("parses a recurring class with defaults", () => {
    const c = Value.Parse(GymClass, {
      id: "c1", gymId: "g1", title: "Fundamentals", classType: "fundamentals",
      giType: "gi", skillLevel: "beginner", dayOfWeek: 1, startTime: "18:00", endTime: "19:00",
    });
    expect(c.isRecurring).toBe(true);
    expect(c.status).toBe("active");
  });
  it("rejects dayOfWeek out of range", () => {
    expect(Value.Check(GymClass, {
      id: "c1", gymId: "g1", title: "x", classType: "gi", giType: "gi", skillLevel: "all",
      dayOfWeek: 7, startTime: "18:00", endTime: "19:00",
    })).toBe(false);
  });
});

describe("ClassOccurrence schema", () => {
  it("defaults status to scheduled", () => {
    const o = Value.Parse(ClassOccurrence, { id: "o1", classId: "c1", gymId: "g1", date: "2026-08-03" });
    expect(o.status).toBe("scheduled");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/class-schema.test.mts`
Expected: FAIL — schemas not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/gym-class.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { ClassType } from "../enums/class-type.mts";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const GymClass = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    title: t.String({ minLength: 1 }),
    classType: ClassType,
    classTypeLabel: t.Optional(t.String()),
    description: t.Optional(t.String()),
    giType: GiType,
    skillLevel: SkillLevel,
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    isRecurring: t.Boolean({ default: true }),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm" }),
    endTime: t.String({ description: "24h HH:mm" }),
    specificDate: t.Optional(t.String({ description: "ISO YYYY-MM-DD (one-off)" })),
    capacity: t.Optional(t.Integer({ minimum: 0 })),
    status: t.Optional(t.Union([t.Literal("active"), t.Literal("archived")], { default: "active" })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "GymClass" },
);
export type GymClass = Static<typeof GymClass>;
```

```ts
// packages/contract/src/schemas/class-occurrence.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ClassOccurrence = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    date: t.String({ description: "ISO YYYY-MM-DD" }),
    status: t.Optional(t.Union([t.Literal("scheduled"), t.Literal("cancelled")], { default: "scheduled" })),
    startTime: t.Optional(t.String()),
    endTime: t.Optional(t.String()),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    note: t.Optional(t.String()),
  },
  { $id: "ClassOccurrence" },
);
export type ClassOccurrence = Static<typeof ClassOccurrence>;
```

Add to `schemas/index.mts` (after the membership schemas): `export * from "./gym-class.mts";` and `export * from "./class-occurrence.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/class-schema.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/schemas/gym-class.mts packages/contract/src/schemas/class-occurrence.mts packages/contract/src/schemas/index.mts packages/contract/test/class-schema.test.mts
git commit -m "feat(contract): add GymClass and ClassOccurrence schemas"
```

---

## Task 3: `ClassRsvp`, `ScheduledClass`, and request schemas

**Files:**
- Create: `packages/contract/src/schemas/class-rsvp.mts`, `schemas/scheduled-class.mts`, `schemas/requests/class-requests.mts`
- Modify: `packages/contract/src/schemas/index.mts`, `schemas/requests/index.mts`
- Test: `packages/contract/test/class-requests.test.mts`

**Interfaces:**
- Produces:
  - `ClassRsvp` = `{ classId, date, userId, rsvpAt, isMember: boolean }`
  - `ScheduledClass` = `{ classId, gymId, date, title, classType: ClassType, classTypeLabel?, giType: GiType, skillLevel: SkillLevel, startTime, endTime, instructorUserId?, instructorName?, status: 'scheduled'|'cancelled', note?, capacity?, goingCount: int }`
  - `CreateClassRequest` = GymClass minus `{id, gymId, status, createdAt}` (title/classType/giType/skillLevel/times required; the rest optional)
  - `UpdateClassRequest` = `Partial(CreateClassRequest)`
  - `OccurrenceOverrideRequest` = `{ status?: 'scheduled'|'cancelled', startTime?, endTime?, instructorUserId?, instructorName?, note? }`
  - `ClassRsvpRequest` = `{ date: string }`
  - `ScheduleQuery` = `{ from: string, to: string }`
  - `AttendeesQuery` = `{ date: string }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/class-requests.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CreateClassRequest, OccurrenceOverrideRequest, ScheduleQuery, ScheduledClass } from "../src/index.mjs";

describe("class requests", () => {
  it("CreateClassRequest requires core fields", () => {
    expect(Value.Check(CreateClassRequest, {
      title: "Fundamentals", classType: "fundamentals", giType: "gi", skillLevel: "beginner",
      dayOfWeek: 1, startTime: "18:00", endTime: "19:00",
    })).toBe(true);
    expect(Value.Check(CreateClassRequest, { classType: "gi" })).toBe(false); // missing title/times
  });
  it("OccurrenceOverrideRequest is all-optional", () => {
    expect(Value.Check(OccurrenceOverrideRequest, {})).toBe(true);
    expect(Value.Check(OccurrenceOverrideRequest, { status: "cancelled" })).toBe(true);
  });
  it("ScheduleQuery requires from and to", () => {
    expect(Value.Check(ScheduleQuery, { from: "2026-08-01", to: "2026-08-07" })).toBe(true);
    expect(Value.Check(ScheduleQuery, { from: "2026-08-01" })).toBe(false);
  });
  it("ScheduledClass carries goingCount", () => {
    expect(Value.Check(ScheduledClass, {
      classId: "c1", gymId: "g1", date: "2026-08-03", title: "F", classType: "gi",
      giType: "gi", skillLevel: "all", startTime: "18:00", endTime: "19:00",
      status: "scheduled", goingCount: 3,
    })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/class-requests.test.mts`
Expected: FAIL — schemas not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/class-rsvp.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ClassRsvp = t.Object(
  {
    classId: t.String(),
    date: t.String(),
    userId: t.String(),
    rsvpAt: t.String(),
    isMember: t.Boolean(),
  },
  { $id: "ClassRsvp" },
);
export type ClassRsvp = Static<typeof ClassRsvp>;
```

```ts
// packages/contract/src/schemas/scheduled-class.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { ClassType } from "../enums/class-type.mts";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const ScheduledClass = t.Object(
  {
    classId: t.String(),
    gymId: t.String(),
    date: t.String(),
    title: t.String(),
    classType: ClassType,
    classTypeLabel: t.Optional(t.String()),
    giType: GiType,
    skillLevel: SkillLevel,
    startTime: t.String(),
    endTime: t.String(),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    status: t.Union([t.Literal("scheduled"), t.Literal("cancelled")]),
    note: t.Optional(t.String()),
    capacity: t.Optional(t.Integer({ minimum: 0 })),
    goingCount: t.Integer({ minimum: 0 }),
  },
  { $id: "ScheduledClass" },
);
export type ScheduledClass = Static<typeof ScheduledClass>;
```

```ts
// packages/contract/src/schemas/requests/class-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { GymClass } from "../gym-class.mts";

export const CreateClassRequest = t.Omit(GymClass, ["id", "gymId", "status", "createdAt"], { $id: "CreateClassRequest" });
export type CreateClassRequest = Static<typeof CreateClassRequest>;

export const UpdateClassRequest = t.Partial(CreateClassRequest, { $id: "UpdateClassRequest" });
export type UpdateClassRequest = Static<typeof UpdateClassRequest>;

export const OccurrenceOverrideRequest = t.Object(
  {
    status: t.Optional(t.Union([t.Literal("scheduled"), t.Literal("cancelled")])),
    startTime: t.Optional(t.String()),
    endTime: t.Optional(t.String()),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    note: t.Optional(t.String()),
  },
  { $id: "OccurrenceOverrideRequest" },
);
export type OccurrenceOverrideRequest = Static<typeof OccurrenceOverrideRequest>;

export const ClassRsvpRequest = t.Object({ date: t.String() }, { $id: "ClassRsvpRequest" });
export type ClassRsvpRequest = Static<typeof ClassRsvpRequest>;

export const ScheduleQuery = t.Object(
  { from: t.String({ description: "ISO YYYY-MM-DD" }), to: t.String({ description: "ISO YYYY-MM-DD" }) },
  { $id: "ScheduleQuery" },
);
export type ScheduleQuery = Static<typeof ScheduleQuery>;

export const AttendeesQuery = t.Object({ date: t.String() }, { $id: "AttendeesQuery" });
export type AttendeesQuery = Static<typeof AttendeesQuery>;
```

Add to `schemas/index.mts`: `export * from "./class-rsvp.mts";` and `export * from "./scheduled-class.mts";`
Add to `schemas/requests/index.mts`: `export * from "./class-requests.mts";`

> Note: `t.Omit`/`t.Partial` preserve the child property optionality, so `CreateClassRequest` keeps `title`/`classType`/`giType`/`skillLevel`/`startTime`/`endTime` required and the rest optional. `isRecurring` retains its default.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/class-requests.test.mts`. Also run the full `cd packages/contract && bun test` to confirm no barrel regressions.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src packages/contract/test/class-requests.test.mts
git commit -m "feat(contract): add ClassRsvp, ScheduledClass, and class request schemas"
```

---

## Task 4: Shared `gym-authz` authorizer + collections; refactor MembershipFacade

**Files:**
- Create: `apps/api/src/facades/gym-authz.mts`
- Modify: `apps/api/src/facades/membership.facade.mts` (use the shared authorizer), `apps/api/src/db/collections.mts`
- Test: `apps/api/test/gym-authz.test.mts` (+ existing `membership.facade.test.mts` must stay green)

**Interfaces:**
- Consumes: `AppError`; repo shapes `Pick<MembershipRepository,"find">`, `Pick<GymRepository,"findById">`; `UserRole` from `@bjj/contract`.
- Produces `assertCanManageGym(deps, callerId, gymId, callerRole): Promise<void>` where `deps = { memberships: { find(gymId, userId): Promise<GymMembership|null> }, gyms: { findById(id): Promise<Gym|null> } }`. Same rule as before: admin → ok; gym missing → `not_found`; `gym.ownerId === callerId` → ok; active membership with `gymRole` coach|owner → ok; else `forbidden`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/gym-authz.test.mts
import { describe, expect, it } from "bun:test";
import { assertCanManageGym } from "../src/facades/gym-authz.mts";
import type { Gym, GymMembership } from "@bjj/contract";

function deps(gym: Gym | null, membership: GymMembership | null) {
  return {
    gyms: { findById: async (): Promise<Gym | null> => gym },
    memberships: { find: async (): Promise<GymMembership | null> => membership },
  };
}
const gym = (ownerId?: string): Gym => ({ id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId });
const mem = (role: GymMembership["gymRole"]): GymMembership => ({
  id: "m", gymId: "g1", userId: "u", status: "active", verifiedMember: true, gymRole: role,
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t",
});

describe("assertCanManageGym", () => {
  it("admin passes without a gym", async () => {
    await assertCanManageGym(deps(null, null), "u", "g1", "admin");
  });
  it("gym owner passes", async () => {
    await assertCanManageGym(deps(gym("owner1"), null), "owner1", "g1", "practitioner");
  });
  it("active coach passes", async () => {
    await assertCanManageGym(deps(gym(), mem("coach")), "u", "g1", "practitioner");
  });
  it("plain member is forbidden", async () => {
    await expect(assertCanManageGym(deps(gym(), mem("member")), "u", "g1", "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });
  it("missing gym for non-admin is not_found", async () => {
    await expect(assertCanManageGym(deps(null, null), "u", "ghost", "practitioner"))
      .rejects.toMatchObject({ code: "not_found" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/gym-authz.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/facades/gym-authz.mts
import type { Gym, GymMembership, UserRole } from "@bjj/contract";
import { AppError } from "../http/errors.mts";

export interface GymAuthzDeps {
  readonly gyms: { findById(id: string): Promise<Gym | null> };
  readonly memberships: { find(gymId: string, userId: string): Promise<GymMembership | null> };
}

export async function assertCanManageGym(
  deps: GymAuthzDeps, callerId: string, gymId: string, callerRole: UserRole,
): Promise<void> {
  if (callerRole === "admin") return;
  const gym: Gym | null = await deps.gyms.findById(gymId);
  if (!gym) throw new AppError("not_found", `Gym ${gymId} not found`);
  if (gym.ownerId === callerId) return;
  const membership: GymMembership | null = await deps.memberships.find(gymId, callerId);
  const role: string = membership?.gymRole ?? "member";
  if (membership && membership.status === "active" && (role === "coach" || role === "owner")) return;
  throw new AppError("forbidden", "Requires gym owner or coach");
}
```

Refactor `membership.facade.mts`: replace the body of the private `assertCanManage(callerId, gymId, callerRole)` so it delegates:

```ts
private async assertCanManage(callerId: string, gymId: string, callerRole: UserRole): Promise<void> {
  await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, gymId, callerRole);
}
```

Add the import `import { assertCanManageGym } from "./gym-authz.mts";` at the top of `membership.facade.mts`. (Its `gyms`/`memberships` Pick types already satisfy the deps shape.)

Add to `apps/api/src/db/collections.mts` inside `COLLECTIONS`:

```ts
  gymClasses: "gymClasses",
  classOccurrences: "classOccurrences",
  classRsvps: "classRsvps",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/gym-authz.test.mts` then `bun test test/membership.facade.test.mts` (must stay green — the refactor is behavior-preserving).
Expected: PASS both.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/gym-authz.mts apps/api/src/facades/membership.facade.mts apps/api/src/db/collections.mts apps/api/test/gym-authz.test.mts
git commit -m "refactor(api): extract shared assertCanManageGym authorizer; add class collections"
```

---

## Task 5: `ClassRepository`

**Files:**
- Create: `apps/api/src/repositories/class.repository.mts`
- Test: `apps/api/test/class.repository.test.mts`

**Interfaces:**
- Consumes `GymClass`, `COLLECTIONS.gymClasses`, `BaseRepository`, `stripId`.
- Produces `ClassRepository`:
  - `ensureIndexes(): Promise<void>` — `{ gymId: 1, status: 1 }`, `{ gymId: 1, dayOfWeek: 1 }`.
  - `insert(c: GymClass): Promise<GymClass>`
  - `findById(id: string): Promise<GymClass | null>`
  - `listActiveByGym(gymId: string): Promise<GymClass[]>` — `status: { $ne: "archived" }`.
  - `update(id: string, patch: Partial<GymClass>): Promise<GymClass | null>` — no-op on empty patch.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassRepository } from "../src/repositories/class.repository.mts";
import type { GymClass } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_classes");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function c(over: Partial<GymClass>): GymClass {
  return {
    id: over.id ?? "c1", gymId: over.gymId ?? "g1", title: "Fundamentals", classType: "fundamentals",
    giType: "gi", skillLevel: "beginner", isRecurring: true, dayOfWeek: 1,
    startTime: "18:00", endTime: "19:00", status: "active", ...over,
  };
}

describe("ClassRepository", () => {
  it("lists active classes for a gym, excluding archived", async () => {
    const repo = new ClassRepository(db);
    await repo.ensureIndexes();
    await repo.insert(c({ id: "a", gymId: "g9" }));
    await repo.insert(c({ id: "b", gymId: "g9", status: "archived" }));
    const active = await repo.listActiveByGym("g9");
    expect(active.map((x) => x.id)).toEqual(["a"]);
  });

  it("update no-ops on empty patch", async () => {
    const repo = new ClassRepository(db);
    await repo.insert(c({ id: "u", gymId: "gU" }));
    const same = await repo.update("u", {});
    expect(same?.id).toBe("u");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class.repository.test.mts`
Expected: FAIL — module not found. (Requires local Mongo on 27017.)

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/class.repository.mts
import type { Db } from "mongodb";
import type { GymClass } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ClassDoc extends GymClass {
  _id: string;
}

export class ClassRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ClassDoc>(COLLECTIONS.gymClasses);
    await col.createIndex({ gymId: 1, status: 1 });
    await col.createIndex({ gymId: 1, dayOfWeek: 1 });
  }

  public async insert(c: GymClass): Promise<GymClass> {
    await this.collection<ClassDoc>(COLLECTIONS.gymClasses).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<GymClass | null> {
    return stripId<GymClass>(await this.collection<ClassDoc>(COLLECTIONS.gymClasses).findOne({ _id: id }));
  }

  public async listActiveByGym(gymId: string): Promise<GymClass[]> {
    const docs = await this.collection<ClassDoc>(COLLECTIONS.gymClasses)
      .find({ gymId, status: { $ne: "archived" } }).toArray();
    return docs.map((d) => stripId<GymClass>(d) as GymClass);
  }

  public async update(id: string, patch: Partial<GymClass>): Promise<GymClass | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<ClassDoc>(COLLECTIONS.gymClasses).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/class.repository.mts apps/api/test/class.repository.test.mts
git commit -m "feat(api): ClassRepository (active-by-gym, archive-aware)"
```

---

## Task 6: `ClassOccurrenceRepository`

**Files:**
- Create: `apps/api/src/repositories/class-occurrence.repository.mts`
- Test: `apps/api/test/class-occurrence.repository.test.mts`

**Interfaces:**
- Consumes `ClassOccurrence`, `COLLECTIONS.classOccurrences`.
- Produces `ClassOccurrenceRepository`:
  - `ensureIndexes()` — unique `{ classId: 1, date: 1 }`, `{ gymId: 1, date: 1 }`.
  - `upsert(o: ClassOccurrence): Promise<ClassOccurrence>` — upsert by `(classId, date)`, `$set` the provided fields, `$setOnInsert` the `id`.
  - `find(classId: string, date: string): Promise<ClassOccurrence | null>`
  - `listByGymRange(gymId: string, from: string, to: string): Promise<ClassOccurrence[]>` — `date` string range `{ $gte: from, $lte: to }` (ISO dates sort lexicographically).

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class-occurrence.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassOccurrenceRepository } from "../src/repositories/class-occurrence.repository.mts";
import type { ClassOccurrence } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_occ");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const occ = (over: Partial<ClassOccurrence>): ClassOccurrence =>
  ({ id: "o1", classId: "c1", gymId: "g1", date: "2026-08-03", status: "scheduled", ...over });

describe("ClassOccurrenceRepository", () => {
  it("upsert is keyed by (classId,date) and merges overrides", async () => {
    const repo = new ClassOccurrenceRepository(db);
    await repo.ensureIndexes();
    await repo.upsert(occ({ id: "first", note: "n1" }));
    await repo.upsert(occ({ id: "second", status: "cancelled" })); // same class+date
    const found = await repo.find("c1", "2026-08-03");
    expect(found?.status).toBe("cancelled");
    expect(found?.note).toBe("n1"); // prior field preserved
    expect(found?.id).toBe("first"); // id set on insert only
  });

  it("listByGymRange filters by date window", async () => {
    const repo = new ClassOccurrenceRepository(db);
    await repo.upsert(occ({ id: "in", classId: "c2", gymId: "gR", date: "2026-08-05" }));
    await repo.upsert(occ({ id: "out", classId: "c3", gymId: "gR", date: "2026-09-01" }));
    const rows = await repo.listByGymRange("gR", "2026-08-01", "2026-08-31");
    expect(rows.map((r) => r.classId)).toEqual(["c2"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class-occurrence.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/class-occurrence.repository.mts
import type { Db } from "mongodb";
import type { ClassOccurrence } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface OccurrenceDoc extends ClassOccurrence {
  _id: string;
}

export class ClassOccurrenceRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences);
    await col.createIndex({ classId: 1, date: 1 }, { unique: true });
    await col.createIndex({ gymId: 1, date: 1 });
  }

  public async upsert(o: ClassOccurrence): Promise<ClassOccurrence> {
    const { id, classId, date, ...rest } = o;
    await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences).updateOne(
      { classId, date },
      { $set: { classId, date, ...rest }, $setOnInsert: { _id: id, id } },
      { upsert: true },
    );
    return (await this.find(classId, date)) as ClassOccurrence;
  }

  public async find(classId: string, date: string): Promise<ClassOccurrence | null> {
    return stripId<ClassOccurrence>(
      await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences).findOne({ classId, date }),
    );
  }

  public async listByGymRange(gymId: string, from: string, to: string): Promise<ClassOccurrence[]> {
    const docs = await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences)
      .find({ gymId, date: { $gte: from, $lte: to } }).toArray();
    return docs.map((d) => stripId<ClassOccurrence>(d) as ClassOccurrence);
  }
}
```

> Note: `$set` includes `classId`/`date` (harmless on update, required on insert-via-upsert); `rest` spreads the override fields. `id` only lands via `$setOnInsert`. Do not put the same field in both `$set` and `$setOnInsert` — that's a Mongo conflict — which is why `id`/`_id` are insert-only and `classId`/`date` live only in `$set`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class-occurrence.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/class-occurrence.repository.mts apps/api/test/class-occurrence.repository.test.mts
git commit -m "feat(api): ClassOccurrenceRepository (upsert override by class+date, range query)"
```

---

## Task 7: `ClassRsvpRepository`

**Files:**
- Create: `apps/api/src/repositories/class-rsvp.repository.mts`
- Test: `apps/api/test/class-rsvp.repository.test.mts`

**Interfaces:**
- Consumes `COLLECTIONS.classRsvps`.
- Produces `ClassRsvpRepository` (internal doc `{ classId, date, userId, rsvpAt, isMember }`):
  - `ensureIndexes()` — unique `{ classId: 1, date: 1, userId: 1 }`, `{ classId: 1, date: 1 }`.
  - `add(classId, date, userId, isMember): Promise<void>` — upsert; `$setOnInsert` rsvpAt; always `$set` isMember (refresh snapshot on re-RSVP).
  - `remove(classId, date, userId): Promise<void>`
  - `count(classId, date): Promise<number>`
  - `countsForClassDates(classId, dates: string[]): Promise<Record<string, number>>` — grouped counts for a class across many dates (for the schedule endpoint).
  - `list(classId, date): Promise<Array<{ userId: string; isMember: boolean; rsvpAt: string }>>` — sorted by rsvpAt.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class-rsvp.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ClassRsvpRepository } from "../src/repositories/class-rsvp.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_class_rsvp");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("ClassRsvpRepository", () => {
  it("add is idempotent per (class,date,user) and refreshes isMember", async () => {
    const repo = new ClassRsvpRepository(db);
    await repo.ensureIndexes();
    await repo.add("c1", "2026-08-03", "u1", false);
    await repo.add("c1", "2026-08-03", "u1", true); // re-rsvp, now a member
    expect(await repo.count("c1", "2026-08-03")).toBe(1);
    const list = await repo.list("c1", "2026-08-03");
    expect(list[0]?.isMember).toBe(true);
  });

  it("countsForClassDates groups by date", async () => {
    const repo = new ClassRsvpRepository(db);
    await repo.add("c2", "2026-08-04", "a", true);
    await repo.add("c2", "2026-08-04", "b", false);
    await repo.add("c2", "2026-08-11", "a", true);
    const counts = await repo.countsForClassDates("c2", ["2026-08-04", "2026-08-11"]);
    expect(counts["2026-08-04"]).toBe(2);
    expect(counts["2026-08-11"]).toBe(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class-rsvp.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/class-rsvp.repository.mts
import type { Db } from "mongodb";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface ClassRsvpDoc {
  classId: string;
  date: string;
  userId: string;
  rsvpAt: string;
  isMember: boolean;
}

export class ClassRsvpRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps);
    await col.createIndex({ classId: 1, date: 1, userId: 1 }, { unique: true });
    await col.createIndex({ classId: 1, date: 1 });
  }

  public async add(classId: string, date: string, userId: string, isMember: boolean): Promise<void> {
    await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).updateOne(
      { classId, date, userId },
      { $set: { isMember }, $setOnInsert: { rsvpAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(classId: string, date: string, userId: string): Promise<void> {
    await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).deleteOne({ classId, date, userId });
  }

  public async count(classId: string, date: string): Promise<number> {
    return this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).countDocuments({ classId, date });
  }

  public async countsForClassDates(classId: string, dates: string[]): Promise<Record<string, number>> {
    const rows = await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).aggregate<{ _id: string; n: number }>([
      { $match: { classId, date: { $in: dates } } },
      { $group: { _id: "$date", n: { $sum: 1 } } },
    ]).toArray();
    const out: Record<string, number> = {};
    for (const r of rows) out[r._id] = r.n;
    return out;
  }

  public async list(classId: string, date: string): Promise<Array<{ userId: string; isMember: boolean; rsvpAt: string }>> {
    const docs = await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps)
      .find({ classId, date }).sort({ rsvpAt: 1, userId: 1 }).toArray();
    return docs.map((d) => ({ userId: d.userId, isMember: d.isMember, rsvpAt: d.rsvpAt }));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class-rsvp.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/class-rsvp.repository.mts apps/api/test/class-rsvp.repository.test.mts
git commit -m "feat(api): ClassRsvpRepository (per-date rsvp, isMember snapshot, grouped counts)"
```

---

## Task 8: `ClassFacade` (expansion + authorization + RSVP)

**Files:**
- Create: `apps/api/src/facades/class.facade.mts`
- Test: `apps/api/test/class.facade.test.mts`

**Interfaces:**
- Consumes (via `Pick`): `ClassRepository` (`insert|findById|listActiveByGym|update`), `ClassOccurrenceRepository` (`upsert|find|listByGymRange`), `ClassRsvpRepository` (`add|remove|count|countsForClassDates|list`), `MembershipRepository` (`find`), `GymRepository` (`findById`), `UserRepository` (`findById`), `assertCanManageGym`, `IdFactory`.
- Produces `ClassFacade`:
  - `create(callerId, gymId, req: CreateClassRequest, callerRole): Promise<GymClass>` — authz; validates recurring→dayOfWeek, one-off→specificDate; assigns id/status/createdAt.
  - `listDefinitions(gymId): Promise<GymClass[]>`
  - `update(callerId, classId, req: UpdateClassRequest, callerRole): Promise<GymClass>` — authz (resolve gymId from the class).
  - `archive(callerId, classId, callerRole): Promise<void>`
  - `overrideOccurrence(callerId, classId, date, req: OccurrenceOverrideRequest, callerRole): Promise<ClassOccurrence>` — authz; validates `date` is a real occurrence of the class (`occursOn`); upserts.
  - `schedule(gymId, from, to): Promise<ScheduledClass[]>` — pure expansion (see below) joined with counts.
  - `rsvp(userId, classId, date): Promise<void>` — resolves class + occurrence; blocks if cancelled (`409`) or capacity full (`409`); snapshots `isMember` from membership lookup.
  - `unrsvp(userId, classId, date): Promise<void>`
  - `attendees(classId, date): Promise<Array<{ userId; isMember; name; beltRank?; avatarUrl?; hasProfile }>>` — joins user docs.
- Exposes a pure static/free helper `occursOn(cls: GymClass, date: string): boolean` and `expand(classes, overrides, from, to)` for testability.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class.facade.test.mts
import { describe, expect, it } from "bun:test";
import { ClassFacade } from "../src/facades/class.facade.mts";
import type { GymClass, ClassOccurrence, Gym, GymMembership, User } from "@bjj/contract";

function facade(seed?: {
  classes?: GymClass[]; occurrences?: ClassOccurrence[]; gymOwnerId?: string;
  memberships?: GymMembership[]; users?: User[];
}) {
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
    list: async (c: string, d: string) => rsvps.filter((r) => r.classId === c && r.date === d).map((r) => ({ userId: r.userId, isMember: r.isMember, rsvpAt: r.rsvpAt })),
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class.facade.test.mts`
Expected: FAIL — `ClassFacade` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/facades/class.facade.mts
import type {
  ClassOccurrence, CreateClassRequest, GymClass, OccurrenceOverrideRequest,
  ScheduledClass, UpdateClassRequest, UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import { assertCanManageGym } from "./gym-authz.mts";
import type { ClassRepository } from "../repositories/class.repository.mts";
import type { ClassOccurrenceRepository } from "../repositories/class-occurrence.repository.mts";
import type { ClassRsvpRepository } from "../repositories/class-rsvp.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

type IdFactory = () => string;
type ClassRepo = Pick<ClassRepository, "insert" | "findById" | "listActiveByGym" | "update">;
type OccRepo = Pick<ClassOccurrenceRepository, "upsert" | "find" | "listByGymRange">;
type RsvpRepo = Pick<ClassRsvpRepository, "add" | "remove" | "count" | "countsForClassDates" | "list">;
type MemberRepo = Pick<MembershipRepository, "find">;
type GymRepo = Pick<GymRepository, "findById">;
type UserRepo = Pick<UserRepository, "findById">;

export interface ClassAttendee {
  userId: string;
  isMember: boolean;
  name: string;
  beltRank?: string;
  avatarUrl?: string;
  hasProfile: boolean;
}

// Weekday (0=Sun..6=Sat) for an ISO YYYY-MM-DD date, in UTC.
function weekdayOf(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

// Every ISO date in [from,to] inclusive.
function datesInRange(from: string, to: string): string[] {
  const out: string[] = [];
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  for (let t = start.getTime(); t <= end.getTime(); t += 86_400_000) {
    out.push(new Date(t).toISOString().slice(0, 10));
  }
  return out;
}

export function occursOn(cls: GymClass, date: string): boolean {
  if (cls.isRecurring) return cls.dayOfWeek !== undefined && weekdayOf(date) === cls.dayOfWeek;
  return cls.specificDate === date;
}

export class ClassFacade {

  public constructor(
    private readonly classes: ClassRepo,
    private readonly occurrences: OccRepo,
    private readonly rsvps: RsvpRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  public async create(callerId: string, gymId: string, req: CreateClassRequest, callerRole: UserRole): Promise<GymClass> {
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, gymId, callerRole);
    const isRecurring: boolean = req.isRecurring ?? true;
    if (isRecurring && req.dayOfWeek === undefined) throw new AppError("bad_request", "Recurring class requires dayOfWeek");
    if (!isRecurring && !req.specificDate) throw new AppError("bad_request", "One-off class requires specificDate");
    const cls: GymClass = {
      ...req,
      isRecurring,
      id: this.newId(),
      gymId,
      status: "active",
      createdAt: new Date().toISOString(),
    };
    return this.classes.insert(cls);
  }

  public async listDefinitions(gymId: string): Promise<GymClass[]> {
    return this.classes.listActiveByGym(gymId);
  }

  private async getClassOr404(classId: string): Promise<GymClass> {
    const cls = await this.classes.findById(classId);
    if (!cls) throw new AppError("not_found", `Class ${classId} not found`);
    return cls;
  }

  public async update(callerId: string, classId: string, req: UpdateClassRequest, callerRole: UserRole): Promise<GymClass> {
    const cls = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    return (await this.classes.update(classId, req)) as GymClass;
  }

  public async archive(callerId: string, classId: string, callerRole: UserRole): Promise<void> {
    const cls = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    await this.classes.update(classId, { status: "archived" });
  }

  public async overrideOccurrence(
    callerId: string, classId: string, date: string, req: OccurrenceOverrideRequest, callerRole: UserRole,
  ): Promise<ClassOccurrence> {
    const cls = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    if (!occursOn(cls, date)) throw new AppError("bad_request", `${date} is not an occurrence of class ${classId}`);
    const existing = await this.occurrences.find(classId, date);
    const occurrence: ClassOccurrence = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, date,
      status: req.status ?? existing?.status ?? "scheduled",
      startTime: req.startTime ?? existing?.startTime,
      endTime: req.endTime ?? existing?.endTime,
      instructorUserId: req.instructorUserId ?? existing?.instructorUserId,
      instructorName: req.instructorName ?? existing?.instructorName,
      note: req.note ?? existing?.note,
    };
    return this.occurrences.upsert(occurrence);
  }

  public async schedule(gymId: string, from: string, to: string): Promise<ScheduledClass[]> {
    const [classes, overrides] = await Promise.all([
      this.classes.listActiveByGym(gymId),
      this.occurrences.listByGymRange(gymId, from, to),
    ]);
    const overrideByKey = new Map<string, ClassOccurrence>();
    for (const o of overrides) overrideByKey.set(`${o.classId}:${o.date}`, o);

    const range = datesInRange(from, to);
    const result: ScheduledClass[] = [];
    for (const cls of classes) {
      const dates = range.filter((d) => occursOn(cls, d));
      const counts = await this.rsvps.countsForClassDates(cls.id, dates);
      for (const date of dates) {
        const ov = overrideByKey.get(`${cls.id}:${date}`);
        result.push({
          classId: cls.id, gymId, date, title: cls.title,
          classType: cls.classType, classTypeLabel: cls.classTypeLabel,
          giType: cls.giType, skillLevel: cls.skillLevel,
          startTime: ov?.startTime ?? cls.startTime,
          endTime: ov?.endTime ?? cls.endTime,
          instructorUserId: ov?.instructorUserId ?? cls.instructorUserId,
          instructorName: ov?.instructorName ?? cls.instructorName,
          status: ov?.status ?? "scheduled",
          note: ov?.note,
          capacity: cls.capacity,
          goingCount: counts[date] ?? 0,
        });
      }
    }
    result.sort((a, b) => (a.date === b.date ? a.startTime.localeCompare(b.startTime) : a.date.localeCompare(b.date)));
    return result;
  }

  public async rsvp(userId: string, classId: string, date: string): Promise<void> {
    const cls = await this.getClassOr404(classId);
    if (!occursOn(cls, date)) throw new AppError("bad_request", `${date} is not an occurrence of class ${classId}`);
    const ov = await this.occurrences.find(classId, date);
    if (ov?.status === "cancelled") throw new AppError("conflict", "This class occurrence is cancelled");
    if (cls.capacity !== undefined) {
      const going = await this.rsvps.count(classId, date);
      if (going >= cls.capacity) throw new AppError("conflict", "This class is full");
    }
    const membership = await this.memberships.find(cls.gymId, userId);
    const isMember: boolean = membership !== null && membership.status === "active";
    await this.rsvps.add(classId, date, userId, isMember);
  }

  public async unrsvp(userId: string, classId: string, date: string): Promise<void> {
    await this.rsvps.remove(classId, date, userId);
  }

  public async attendees(classId: string, date: string): Promise<ClassAttendee[]> {
    const rows = await this.rsvps.list(classId, date);
    return Promise.all(rows.map(async (r): Promise<ClassAttendee> => {
      const u = await this.users.findById(r.userId);
      return {
        userId: r.userId, isMember: r.isMember,
        name: u?.displayName ?? "Guest", beltRank: u?.beltRank, avatarUrl: u?.avatarUrl,
        hasProfile: u !== null,
      };
    }));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class.facade.test.mts`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/class.facade.mts apps/api/test/class.facade.test.mts
git commit -m "feat(api): ClassFacade with occurrence expansion, authorization, rsvp"
```

---

## Task 9: `class.routes.mts` + container + app wiring

**Files:**
- Create: `apps/api/src/routes/class.routes.mts`
- Modify: `apps/api/src/container.mts`, `apps/api/src/app.mts`
- Test: `apps/api/test/class.routes.test.mts`

**Interfaces:**
- Consumes: `container.classFacade`, `authPlugin`, `requireAuth`, `data`/`list`, request schemas from Task 3.
- Produces routes (param `:id` for gym/class to avoid memoirist conflicts — split into a `/api/v1/gyms` prefixed instance and a `/api/v1/classes` prefixed instance, mirroring how `membership.routes.mts` split gyms vs users):
  - `POST /api/v1/gyms/:id/classes` (auth, `CreateClassRequest`) → `data(create)`
  - `GET /api/v1/gyms/:id/classes` (public) → `list(listDefinitions)`
  - `GET /api/v1/gyms/:id/schedule` (public, `ScheduleQuery`) → `list(schedule)`
  - `PATCH /api/v1/classes/:id` (auth, `UpdateClassRequest`) → `data(update)`
  - `DELETE /api/v1/classes/:id` (auth) → `data({ok:true})`
  - `PUT /api/v1/classes/:id/occurrences/:date` (auth, `OccurrenceOverrideRequest`) → `data(overrideOccurrence)`
  - `POST /api/v1/classes/:id/rsvp` (auth, `ClassRsvpRequest`) → `data({ok:true})`
  - `DELETE /api/v1/classes/:id/rsvp` (auth, `ClassRsvpRequest`) → `data({ok:true})`
  - `GET /api/v1/classes/:id/attendees` (public, `AttendeesQuery`) → `list(attendees)`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/class.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { classRoutes } from "../src/routes/class.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const classFacade = {
    create: async (u: string, g: string) => { calls.push(`create:${u}:${g}`); return { id: "c1", gymId: g, title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00", status: "active" }; },
    listDefinitions: async (g: string) => { calls.push(`defs:${g}`); return []; },
    schedule: async (g: string, from: string, to: string) => { calls.push(`sched:${g}:${from}:${to}`); return []; },
    update: async () => ({ id: "c1", gymId: "g1", title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00", status: "active" }),
    archive: async (): Promise<void> => { calls.push("archive"); },
    overrideOccurrence: async () => ({ id: "o1", classId: "c1", gymId: "g1", date: "2026-08-10", status: "cancelled" }),
    rsvp: async (u: string, c: string, d: string): Promise<void> => { calls.push(`rsvp:${u}:${c}:${d}`); },
    unrsvp: async (): Promise<void> => { calls.push("unrsvp"); },
    attendees: async () => [],
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    classFacade,
  } as unknown as Container;
  return { app: new Elysia().use(classRoutes(container)), calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("class routes", () => {
  it("GET schedule is public and passes the range", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/schedule?from=2026-08-01&to=2026-08-07"));
    expect(res.status).toBe(200);
    expect(calls).toContain("sched:g1:2026-08-01:2026-08-07");
  });
  it("POST create requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/classes", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "F", classType: "gi", giType: "gi", skillLevel: "all", isRecurring: true, dayOfWeek: 1, startTime: "18:00", endTime: "19:00" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST rsvp calls the facade with the caller id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/classes/c1/rsvp", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" },
      body: JSON.stringify({ date: "2026-08-03" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("rsvp:u1:c1:2026-08-03");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/class.routes.test.mts`
Expected: FAIL — `classRoutes` not found.

- [ ] **Step 3: Write minimal implementation**

Model `class.routes.mts` on `membership.routes.mts`: apply `authPlugin(container.verifier, container.roleLookup)`, use two prefixed `Elysia` instances (`/api/v1/gyms` and `/api/v1/classes`), a `requireId(identity)` helper, `data`/`list` envelopes, `requireAuth: true` on the mutating routes and the RSVP routes, and the request schemas as `body`/`query` validators. Handlers read `params.id` (and `params.date` for the override route), delegating to `container.classFacade`. Roster-equivalent public routes (`GET .../classes`, `GET .../schedule`, `GET .../attendees`) omit `requireAuth`. Follow the eslint-disable-return-type convention on the exported function.

Wire the container (`apps/api/src/container.mts`):
- import `ClassRepository`, `ClassOccurrenceRepository`, `ClassRsvpRepository`, `ClassFacade`.
- construct `classRepo`, `classOccurrenceRepo`, `classRsvpRepo`; add `readonly classFacade: ClassFacade;` to the `Container` interface; build `classFacade: new ClassFacade(classRepo, classOccurrenceRepo, classRsvpRepo, membershipRepo, gymRepo, userRepo, id)` (reuse the existing `membershipRepo`, `gymRepo`, `userRepo`, `id`).
- in the container `ensureIndexes()`, add `await classRepo.ensureIndexes(); await classOccurrenceRepo.ensureIndexes(); await classRsvpRepo.ensureIndexes();`.

Wire `app.mts`: import `classRoutes`, add `.use(classRoutes(container))`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/class.routes.test.mts`, then `bun test test/boot.test.mts`, then the full `bun test`.
Expected: PASS; no regressions.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/routes/class.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/class.routes.test.mts
git commit -m "feat(api): class routes wired into container and app"
```

---

## Task 10: OpenAPI + Postman docs

**Files:**
- Modify: `apps/api/src/openapi.mts`, `apps/api/openapi.json` (regenerate), `docs/postman/bjj-open-mat.postman_collection.json`

**Interfaces:** none (docs).

- [ ] **Step 1:** `openapi.mts` is hand-listed (confirmed in the membership work). Add the 9 class paths with their request/response schema refs (`CreateClassRequest`, `UpdateClassRequest`, `OccurrenceOverrideRequest`, `ClassRsvpRequest`, `ScheduleQuery`, `AttendeesQuery`, `GymClass`, `ScheduledClass`, `ClassOccurrence`, `ClassRsvp`, `ClassType`). Register the new component schemas alongside the membership ones.
- [ ] **Step 2:** Regenerate the committed `apps/api/openapi.json` the same way the membership task did, and add a "Gym Classes" folder to the Postman collection mirroring the "Gym Membership" folder structure.
- [ ] **Step 3:** Run `cd apps/api && bun test` to confirm nothing broke.
- [ ] **Step 4: Commit**

```bash
git add apps/api/src/openapi.mts apps/api/openapi.json docs/postman/bjj-open-mat.postman_collection.json
git commit -m "docs(api): document gym class schedule + rsvp endpoints"
```

---

## Task 11: Flutter models + endpoints

**Files:**
- Create: `apps/mobile/lib/features/classes/models/gym_class.dart`, `models/scheduled_class.dart`, `models/class_attendee.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/mobile/test/classes/scheduled_class_test.dart`

**Interfaces:**
- Produces Dart models with `fromJson` mirroring the contract, and `Endpoints` helpers:
  - `gymClasses(String gymId) => '/api/v1/gyms/$gymId/classes'`
  - `gymSchedule(String gymId) => '/api/v1/gyms/$gymId/schedule'`
  - `classById(String classId) => '/api/v1/classes/$classId'`
  - `classOccurrence(String classId, String date) => '/api/v1/classes/$classId/occurrences/$date'`
  - `classRsvp(String classId) => '/api/v1/classes/$classId/rsvp'`
  - `classAttendees(String classId) => '/api/v1/classes/$classId/attendees'`

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/classes/scheduled_class_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';

void main() {
  test('ScheduledClass.fromJson maps fields incl goingCount + status', () {
    final s = ScheduledClass.fromJson(const {
      'classId': 'c1', 'gymId': 'g1', 'date': '2026-08-03', 'title': 'Fundamentals',
      'classType': 'fundamentals', 'giType': 'gi', 'skillLevel': 'beginner',
      'startTime': '18:00', 'endTime': '19:00', 'status': 'scheduled', 'goingCount': 4,
    });
    expect(s.classId, 'c1');
    expect(s.status, 'scheduled');
    expect(s.goingCount, 4);
    expect(s.title, 'Fundamentals');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/classes/scheduled_class_test.dart`
Expected: FAIL — model not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/mobile/lib/features/classes/models/scheduled_class.dart
class ScheduledClass {
  final String classId;
  final String gymId;
  final String date;
  final String title;
  final String classType;
  final String? classTypeLabel;
  final String giType;
  final String skillLevel;
  final String startTime;
  final String endTime;
  final String? instructorUserId;
  final String? instructorName;
  final String status;
  final String? note;
  final int? capacity;
  final int goingCount;

  const ScheduledClass({
    required this.classId,
    required this.gymId,
    required this.date,
    required this.title,
    required this.classType,
    this.classTypeLabel,
    required this.giType,
    required this.skillLevel,
    required this.startTime,
    required this.endTime,
    this.instructorUserId,
    this.instructorName,
    required this.status,
    this.note,
    this.capacity,
    required this.goingCount,
  });

  factory ScheduledClass.fromJson(Map<String, dynamic> json) => ScheduledClass(
        classId: json['classId'] as String,
        gymId: json['gymId'] as String,
        date: json['date'] as String,
        title: json['title'] as String,
        classType: json['classType'] as String,
        classTypeLabel: json['classTypeLabel'] as String?,
        giType: json['giType'] as String,
        skillLevel: json['skillLevel'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        instructorUserId: json['instructorUserId'] as String?,
        instructorName: json['instructorName'] as String?,
        status: json['status'] as String,
        note: json['note'] as String?,
        capacity: json['capacity'] as int?,
        goingCount: json['goingCount'] as int,
      );

  bool get isCancelled => status == 'cancelled';
}
```

Create `gym_class.dart` (all `GymClass` fields) and `class_attendee.dart` (`userId, isMember, name, beltRank?, avatarUrl?, hasProfile`) the same way, and add the `Endpoints` helpers under a `// Classes` section.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/classes/scheduled_class_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/classes/models apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/classes/scheduled_class_test.dart
git commit -m "feat(mobile): class models + endpoints"
```

---

## Task 12: Flutter class repository + providers

**Files:**
- Create: `apps/mobile/lib/features/classes/data/class_repository.dart`
- Test: `apps/mobile/test/classes/class_repository_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `unwrapList`/`unwrapData`, `ApiException`, models from Task 11.
- Produces `ClassRepository` (abstract) + `ApiClassRepository`:
  - `Future<List<ScheduledClass>> schedule(String gymId, {required String from, required String to})` — GET `gymSchedule` with query params.
  - `Future<List<GymClass>> definitions(String gymId)`
  - `Future<GymClass> create(String gymId, Map<String,dynamic> body)`
  - `Future<GymClass> update(String classId, Map<String,dynamic> body)`
  - `Future<void> archive(String classId)`
  - `Future<void> overrideOccurrence(String classId, String date, Map<String,dynamic> body)` — PUT `classOccurrence`.
  - `Future<void> rsvp(String classId, String date)` / `Future<void> unrsvp(String classId, String date)` — POST/DELETE `classRsvp` with `{date}` body.
  - `Future<List<ClassAttendee>> attendees(String classId, String date)` — GET `classAttendees?date=`.
- Providers: `classRepositoryProvider`; `scheduleProvider = FutureProvider.family<List<ScheduledClass>, ({String gymId, String from, String to})>`; `classAttendeesProvider = FutureProvider.family<List<ClassAttendee>, ({String classId, String date})>`.

- [ ] **Step 1: Write the failing test** — repository parses a mocked schedule list envelope (model on `apps/mobile/test/membership/membership_repository_test.dart`'s fake `HttpClientAdapter`, returning a `{"data":[<ScheduledClass>],"meta":{...}}` body); assert `schedule(...)` returns one parsed occurrence.
- [ ] **Step 2:** `cd apps/mobile && flutter test test/classes/class_repository_test.dart` → FAIL.
- [ ] **Step 3:** Implement modeled on `apps/mobile/lib/features/membership/data/membership_repository.dart` (try/catch DioException → ApiException.fromDio; `unwrapList`/`unwrapData`). The schedule call passes `queryParameters: {'from': from, 'to': to}`. Define the providers like the membership ones.
- [ ] **Step 4:** `flutter test test/classes/class_repository_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(mobile): class repository + providers`.

---

## Task 13: Weekly timetable screen + gym-detail entry + route

**Files:**
- Create: `apps/mobile/lib/features/classes/screens/class_schedule_screen.dart`, `apps/mobile/lib/features/classes/widgets/class_type_chip.dart`
- Modify: `apps/mobile/lib/app/router.dart`, `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`
- Test: `apps/mobile/test/classes/class_schedule_screen_test.dart`

**Interfaces:**
- Consumes `scheduleProvider((gymId, from, to))`, `ClassTypeChip`, existing belt-icon widget for instructor display, `gymByIdProvider`.
- Produces `ClassScheduleScreen({required String gymId})` — computes the visible week's `from`/`to` (Mon–Sun), watches `scheduleProvider`, groups occurrences by day, renders each with `ClassTypeChip`, time, instructor, going-count; cancelled occurrences show a struck-through "Cancelled" banner; week-paging (prev/next). `ClassTypeChip({required String classType, String? label})` maps the enum to a display name (with `label` when `other`).
- Router: add child `GoRoute(path: 'schedule', builder: (c,s) => ClassScheduleScreen(gymId: s.pathParameters['id']!))` under the existing `gym/:id` route → `/gym/:id/schedule`. Gym-detail gets a "Class schedule" entry pushing `/gym/${gym.id}/schedule` (model on the Task-12 "Members" entry from the membership feature).

- [ ] **Step 1:** Widget test: override `scheduleProvider` for a fixed week to return two occurrences on different days (one `cancelled`); pump `ClassScheduleScreen(gymId:'g1')` in MaterialApp+ProviderScope; assert both titles render and the cancelled banner shows. Model the harness on `apps/mobile/test/membership/roster_screen_test.dart`. → write test.
- [ ] **Step 2:** `flutter test test/classes/class_schedule_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement the screen + chip + route + gym-detail entry. For week math, compute the Monday of the current week from a passed-in or default date; expose the week anchor so the test is deterministic (accept an optional `DateTime? initialWeek` defaulting to `DateTime.now()`).
- [ ] **Step 4:** `flutter test test/classes/class_schedule_screen_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): weekly class timetable screen + gym-detail entry`.

---

## Task 14: Occurrence detail + RSVP + attendee grid

**Files:**
- Create: `apps/mobile/lib/features/classes/screens/class_occurrence_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (route to the occurrence detail), `class_schedule_screen.dart` (tap an occurrence → detail)
- Test: `apps/mobile/test/classes/class_occurrence_screen_test.dart`

**Interfaces:**
- Consumes `classAttendeesProvider((classId, date))`, `classRepositoryProvider` (`rsvp`/`unrsvp`), `currentUserIdProvider` (from the membership feature), belt-icon widget.
- Produces `ClassOccurrenceScreen({required String classId, required String date, ...display fields})` — shows the occurrence header (title, time, instructor, cancelled banner if cancelled), an **"I'm going / Not going"** toggle (disabled + hidden action when cancelled; on tap calls `rsvp`/`unrsvp` then invalidates `classAttendeesProvider` and the parent `scheduleProvider`), and the attendee grid with **Member / Visitor** badges (reuse belt-icon; `hasProfile` gates the profile deep-link exactly like the roster). Pass the display fields via `GoRouter` `extra` or re-fetch; simplest is to pass the `ScheduledClass` as `extra`.
- Router: `/gym/:id/schedule` → push occurrence detail with the tapped `ScheduledClass` as `extra` (no new URL params needed beyond a nested route or a top-level `/class-occurrence` route; choose the pattern already used for passing objects — inspect how open-mat detail is navigated).

- [ ] **Step 1:** Widget test: override `classAttendeesProvider((classId,date))` to return one member + one visitor; override a fake `classRepositoryProvider` recording `rsvp` calls; pump the screen; tap "I'm going"; assert `rsvp(classId, date)` called; assert Member and Visitor badges render. → write test.
- [ ] **Step 2:** `flutter test test/classes/class_occurrence_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement the screen + wire navigation from the timetable.
- [ ] **Step 4:** `flutter test test/classes/class_occurrence_screen_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): class occurrence detail with RSVP + attendee grid`.

---

## Task 15: Owner/coach manage — create/edit class + per-occurrence actions

**Files:**
- Create: `apps/mobile/lib/features/classes/screens/class_edit_screen.dart`
- Modify: `class_schedule_screen.dart` (a "+ Add class" / manage affordance gated to managers), `class_occurrence_screen.dart` (owner/coach per-occurrence actions), `apps/mobile/lib/app/router.dart`
- Test: `apps/mobile/test/classes/class_edit_screen_test.dart`

**Interfaces:**
- Consumes `classRepositoryProvider` (`create`/`update`/`archive`/`overrideOccurrence`), the manage-capability derivation from the membership feature (`isAdmin || isOwner || gymRole in {coach,owner}` — reuse the same inputs: `authStateProvider.user?.role`, `gymByIdProvider(gymId).ownerId`, and the caller's roster/membership role via `myMembershipsProvider` or `rosterProvider`), `ClassType` display list.
- Produces `ClassEditScreen({required String gymId, GymClass? existing})` — form: title, class-type dropdown (+ label when `other`), gi dropdown, skill-level dropdown, instructor (picker from roster *or* free-text), recurrence toggle (weekly day+time *or* one-off date), capacity. Submit calls `create`/`update` then invalidates `scheduleProvider`/definitions. On the occurrence detail, managers get **Cancel this date** / **Change time** / **Change instructor** / **Add note** actions that call `overrideOccurrence` then invalidate.
- Manager gate mirrors the roster: only managers see "+ Add class" and per-occurrence manage actions.

- [ ] **Step 1:** Widget test: pump `ClassEditScreen(gymId:'g1')` with a fake `classRepositoryProvider`; fill title, pick class type + a weekday + times, tap Save; assert `create('g1', {...})` called with `title`, `classType`, `dayOfWeek`, `startTime`, `endTime`, `isRecurring:true`. Also assert one-off mode requires a date before Save is enabled. → write test.
- [ ] **Step 2:** `flutter test test/classes/class_edit_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement the form + manager-gated affordances + per-occurrence override actions + routes.
- [ ] **Step 4:** `flutter test test/classes/class_edit_screen_test.dart` → PASS; `flutter analyze` clean; run full `cd apps/mobile && flutter test`.
- [ ] **Step 5: Commit** `feat(mobile): class create/edit form + per-occurrence manage actions`.

---

## Task 16: End-to-end verification pass

**Files:** none (verification). Do NOT weaken any test to make this pass.

- [ ] **Step 1:** API: `cd apps/api && bun test` — full suite green (local Mongo on 27017 for repo tests). Membership tests must still pass (the Task-4 authorizer refactor is behavior-preserving).
- [ ] **Step 2:** Real API boot smoke test — **never touch production**. Boot with an explicit throwaway local db + self-contained bypass env, on a non-default port, exactly like the membership feature's verification:
  ```
  cd apps/api
  MONGODB_URI="mongodb://localhost:27017/bjj_class_verify" PORT=3199 \
  AUTH_BYPASS_SECRET="verify-secret" DEMO_USER_ID="verify-user@local" DEMO_USER_ROLE="gym_owner" DEMO_USER_EMAIL="verify@local.test" \
  bun run src/index.mts   # background; poll /health; kill stale :3199 first
  ```
  Assert: `GET /api/v1/gyms/nonexistent/schedule?from=2026-08-01&to=2026-08-07` → 200 `{"data":[]...}`; `POST /api/v1/gyms/nonexistent/classes` WITHOUT auth → 401; `POST /api/v1/gyms/nonexistent/classes` WITH `Bearer verify-secret` and a valid body → 404 (gym not found — the demo user isn't the owner of a nonexistent gym, and admin? no: DEMO_USER_ROLE is gym_owner, so `assertCanManageGym` looks up the gym → not_found). Capture status + body for each. Kill the server after; the throwaway db can be ignored.
- [ ] **Step 3:** Mobile: `cd apps/mobile && flutter test` — full suite green; `flutter analyze` clean.
- [ ] **Step 4:** Lint: `cd apps/api && bunx eslint --fix` on the changed api/contract files; zero errors.
- [ ] **Step 5: Commit** any fixups: `chore: lint and verification fixups for class schedule`.

---

## Self-Review Notes (author)

- **Spec coverage:** ClassType enum (T1) ✓; GymClass + ClassOccurrence (T2) ✓; ClassRsvp + ScheduledClass + requests (T3) ✓; shared authorizer + collections (T4) ✓; repos (T5–T7) ✓; expansion + overrides + RSVP isMember snapshot + cancelled/capacity blocks + authz (T8) ✓; routes public-vs-auth split + wiring (T9) ✓; docs (T10) ✓; mobile models/endpoints (T11), repo/providers (T12), timetable (T13), occurrence RSVP + member/visitor attendees (T14), owner create/edit + per-occurrence overrides (T15) ✓; verification incl. real boot (T16) ✓.
- **Decisions honored:** new `GymClass` entity ✓; recurring + one-off + per-date overrides (lazy `ClassOccurrence`, expansion returns cancellations not drops) ✓; instructor member-link OR free-text ✓; public schedule + any-signed-in RSVP with member/visitor via `isMember` snapshot ✓; fixed ClassType + `other` label ✓; shared authorizer refactor ✓.
- **Type consistency:** `ClassFacade` method names + repo `Pick` sets match Tasks 5–8; route param `:id`/`:date` matches Task 9; `Endpoints` helpers (Task 11) match the Task 9 paths; `scheduleProvider` record type consistent across Tasks 12–13.
- **Cross-task guardrails called out:** Mongo `$set`/`$setOnInsert` conflict avoided in the occurrence upsert (Task 6 note); recurring/one-off validation → `bad_request` (Task 8); memoirist `:id` split (Task 9).
