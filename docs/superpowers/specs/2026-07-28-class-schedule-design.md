# Gym Class Schedule + Attendance — Design

**Date:** 2026-07-28
**Status:** Approved (design); pending spec review
**Author:** Davis Sylvester

## Context

Subsystem #2 of the 5-part social-gym plan (membership shipped in PR #36). The app
already has open-mat discovery/RSVP/check-in, gyms with owners, and — as of the
membership feature — gym rosters, per-gym `gymRole` (member/coach/owner), and
gym-verified belt ranks.

This spec adds **gym class schedules**: a gym owner/coach defines the gym's
recurring class timetable (plus one-off classes and per-date overrides), and
members/visitors can RSVP "going" to a specific class occurrence. It deliberately
reuses the existing **RSVP-by-date** pattern (the open-mat `rsvps` collection keys
on `(openMatId, sessionDate, userId)`) and the **membership authorization** model.

## Goals

- Owner/coach/admin can create and manage a gym's classes.
- Support **recurring** weekly classes, **one-off** classes, and **per-date
  overrides** (cancel a date, change time/instructor, add a note).
- Anyone can view a gym's schedule (public); any signed-in user can RSVP "going",
  with the attendee list distinguishing **members from visitors/drop-ins**.
- A class carries a **type** (Fundamentals, No-Gi, Kids, …), gi type, skill level,
  and an **instructor** (a linked gym member or a free-text name).

## Non-Goals (next subsystem, #3)

- Attendance **confirmation** / check-in for classes.
- Class **journaling** ("what was taught").
- **Instructor ratings.**
These build on this subsystem later.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Model | **New `GymClass` entity**, reusing the RSVP-by-date pattern (own `classRsvps` collection) |
| Schedule shapes | **Recurring + one-off + per-date overrides** (lazily-created `ClassOccurrence`) |
| Instructor | **`instructorUserId?` (linked member) OR `instructorName?` (free-text)** |
| Visibility / RSVP | **Public schedule; any signed-in user may RSVP**, attendee list flags member vs visitor |
| Class type | **Fixed `ClassType` enum + `other` with a free-text label** |

## Data Model

New TypeBox schemas in `packages/contract` (`@bjj/contract`); repositories in
`apps/api/src/repositories`. Reuses existing `GiType`, `SkillLevel` enums.

### New enum: `ClassType`

`fundamentals | all_levels | advanced | gi | nogi | kids | womens | competition | private | other`

### New: `GymClass` (the definition)

- `id`, `gymId`, `title`
- `classType: ClassType`, `classTypeLabel?` (required-by-convention when `classType === 'other'`)
- `description?`
- `giType: GiType`, `skillLevel: SkillLevel`
- `instructorUserId?` (a gym member; ideally coach/owner), `instructorName?` (free-text fallback)
- schedule: `isRecurring: boolean`, `dayOfWeek?` (0–6, for recurring), `startTime`
  (24h `HH:mm`), `endTime` (`HH:mm`), `specificDate?` (ISO `YYYY-MM-DD`, for one-off)
- `capacity?` (integer ≥ 0)
- `status: 'active' | 'archived'` (default `active`)
- `createdAt?`

Indexes: `{ gymId, status }`, `{ gymId, dayOfWeek }`.

Validation rule (enforced in the facade): a recurring class requires `dayOfWeek`;
a one-off (`isRecurring:false`) requires `specificDate`.

### New: `ClassOccurrence` (per-date override, lazily created)

A row exists only when a specific date deviates from the class template.

- `id`, `classId`, `gymId`, `date` (`YYYY-MM-DD`)
- `status: 'scheduled' | 'cancelled'` (default `scheduled`)
- overrides (all optional): `startTime?`, `endTime?`, `instructorUserId?`,
  `instructorName?`, `note?`
- unique `{ classId, date }`; index `{ gymId, date }`

### New: `ClassRsvp` (going)

Mirrors the open-mat RSVP repository.

- `classId`, `date` (`YYYY-MM-DD`), `userId`, `rsvpAt`
- `isMember: boolean` — snapshot of whether the user was an **active member** of the
  class's gym at RSVP time (drives the member/visitor badge without a re-lookup)
- unique `{ classId, date, userId }`; index `{ classId, date }`

### Resolved occurrence (response shape, not stored): `ScheduledClass`

What the schedule endpoint returns per concrete occurrence — the class template with
overrides applied, plus counts. Fields: `classId`, `gymId`, `date`, `title`,
`classType`, `classTypeLabel?`, `giType`, `skillLevel`, effective
`startTime`/`endTime`, effective `instructorUserId?`/`instructorName?`, `status`
(`scheduled|cancelled`), `note?`, `capacity?`, `goingCount`.

## API Surface

Elysia, router → facade → repository. New `ClassRepository`,
`ClassOccurrenceRepository`, `ClassRsvpRepository`; `ClassFacade` owns authorization,
**occurrence expansion**, RSVP, and attendee assembly. Authorization reuses
`MembershipRepository` + `Gym.ownerId` + app admin (identical rule to
`MembershipFacade.assertCanManage`). All request/response schemas are TypeBox in
`@bjj/contract`. Route param is `:id` where it collides with existing routes
(memoirist param-name constraint).

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /api/v1/gyms/:id/classes` | owner/coach/admin | Create a class (recurring or one-off). |
| `GET /api/v1/gyms/:id/classes` | public | List the gym's class definitions. |
| `GET /api/v1/gyms/:id/schedule?from=&to=` | public | The timetable: expand recurring classes across `[from,to]` by `dayOfWeek`, merge `ClassOccurrence` overrides/cancellations, add one-offs in range, join per-occurrence RSVP counts. Returns `ScheduledClass[]`. |
| `PATCH /api/v1/classes/:classId` | owner/coach/admin | Edit a class definition. |
| `DELETE /api/v1/classes/:classId` | owner/coach/admin | Archive a class (`status: archived`). |
| `PUT /api/v1/classes/:classId/occurrences/:date` | owner/coach/admin | Upsert a per-date override (cancel / change time / swap instructor / note). |
| `POST /api/v1/classes/:classId/rsvp` (body `{ date }`) | any signed-in user | RSVP "going"; snapshots `isMember`. |
| `DELETE /api/v1/classes/:classId/rsvp` (body `{ date }`) | signed-in user | Cancel your RSVP. |
| `GET /api/v1/classes/:classId/attendees?date=` | public | Attendee list for one occurrence; each flagged member vs visitor. |

### Occurrence expansion (in `ClassFacade`, pure + unit-testable)

Given a gym's active classes and a date range `[from, to]`:
1. For each **recurring** class, emit a candidate occurrence for every date in range
   whose weekday === `dayOfWeek`.
2. For each **one-off** class, emit its `specificDate` if within range.
3. Left-join `ClassOccurrence` overrides by `(classId, date)`; apply `status` and any
   overridden fields; `cancelled` occurrences are returned with `status:'cancelled'`
   (shown, not silently dropped, so RSVP'd users see the cancellation).
4. Left-join RSVP counts by `(classId, date)` → `goingCount`.

### Authorization rules

- Mutating a class or occurrence at gym G requires: app `admin`, OR `Gym.ownerId ===
  callerId`, OR an active membership at G with `gymRole` in `{coach, owner}` — the same
  helper as membership. Factor a shared authorizer so both facades use one rule.

## Error Handling

- RSVP to a `cancelled` occurrence → `409`.
- RSVP when `capacity` is set and `goingCount` already ≥ capacity → `409`.
- Create/edit/archive/override without owner/coach/admin → `403`.
- Class or gym not found → `404`.
- Override `:date` that is not a valid occurrence of the class (weekday ≠ `dayOfWeek`
  for recurring, or ≠ `specificDate` for one-off) → `400`.
- Create with `isRecurring:true` but no `dayOfWeek`, or one-off with no `specificDate`
  → `400`.
- Mongo `null !== undefined`: normalize optional override fields on write/query.

## Mobile UX

Flutter, new `apps/mobile/lib/features/classes/` (data / models / screens / widgets).

- **Gym detail**: a **"Class schedule"** entry → weekly **timetable screen**
  (consumes `GET /schedule?from=&to=` for the visible week; week paging). Each
  occurrence shows title, class-type chip, time, instructor (belt icon when a linked
  member resolves), and going-count; a `cancelled` occurrence renders a struck-through
  "Cancelled" banner.
- **Occurrence detail**: RSVP **"I'm going / Not going"** toggle; attendee grid reusing
  the belt-icon widgets with **Member / Visitor** badges; capacity indicator.
- **Owner/coach manage** (gated by `gymRole`/admin — the same seam as the roster
  manage): **create/edit class** form (type + optional label, gi, level, instructor
  picker from the roster *or* free-text, recurrence = weekly day+time *or* one-off
  date, capacity); per-occurrence actions (**cancel this date**, change
  time/instructor, add note) that upsert a `ClassOccurrence`.

Reuses: belt-icon widgets, the `currentUserIdProvider` seam, `gymByIdProvider`, and the
manage-capability derivation (`isAdmin || isOwner || gymRole in {coach,owner}`) from
the membership feature.

## Testing

- **Facade unit tests (core):** occurrence expansion across multiple weeks respects
  `dayOfWeek`; applies overrides; returns cancellations as `cancelled` (not dropped);
  includes one-offs only within range; RSVP `isMember` snapshot is correct; capacity
  enforcement; cannot RSVP a cancelled occurrence; only owner/coach/admin may mutate;
  invalid override date → `400`.
- **Repository tests (local Mongo):** unique indexes `(classId,date)` and
  `(classId,date,userId)`; occurrence override upsert; per-date RSVP add/remove/count.
- **Flutter widget tests:** timetable groups occurrences by day and renders the
  type chip + going-count; RSVP toggle calls the repo and invalidates; cancelled
  banner; create-form validation (recurring needs a weekday, one-off needs a date).
- Verification per house rule: real API boot smoke against a throwaway local DB
  (public schedule 200, unauth mutate 401, non-manager mutate 403), not just green
  unit tests.

## Reuse & Shared-Code Note

The owner/coach/admin authorization is identical to membership's
`assertCanManage`. Extract it into a small shared authorizer (e.g. a
`GymAuthzService` or an exported function taking the membership repo + gym repo)
that both `MembershipFacade` and `ClassFacade` consume, rather than duplicating the
rule. This is a targeted improvement justified by the second consumer.

## Rollout Order (subsystem sequence, for reference)

1. Gym membership — DONE (PR #36)
2. **Class schedule + attendance** ← this spec
3. Class journaling + instructor ratings
4. Gym forum / Q&A
5. Member-to-member messaging
