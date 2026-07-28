# Class Journaling + Instructor Ratings — Design

**Date:** 2026-07-28
**Status:** Approved (design); pending spec review
**Author:** Davis Sylvester

## Context

Subsystem #3 of the 5-part social-gym plan (membership = PR #36, class schedule =
PR #37). The app has gym classes with occurrences (recurring + one-off + per-date
overrides) and an effective instructor per occurrence (`instructorUserId` linking a
member, or `instructorName` free-text). The existing open-mat **CheckIn** is a
training journal but is open-mat/GPS-specific.

This spec adds, for **gym classes**: a personal **class journal** ("what was taught"
+ your training log for a class you attended) and **instructor ratings**. It reuses
the RSVP-by-date keying (`classId` + `date`), the class occurrence-expansion logic
(to resolve the effective instructor), and the membership authorization
(`assertCanManageGym`, plus a new `assertActiveMember`).

## Goals

- An active gym member can keep a private **class journal** per occurrence: free-text
  "what was taught" + technique tags + a training log (rounds/intensity/partners/note),
  with an **opt-in share** to gym members.
- A member can **rate the instructor** of an occurrence (1–5 + optional comment,
  optionally anonymous).
- Rating visibility: a **public aggregate** (avg + count) on a member instructor's
  profile; **individual ratings + comments** to the gym owner/coach/admin (author
  name unless anonymous). Free-text instructors get gym-only feedback, no public
  aggregate.

## Non-Goals (later subsystems)

- Gym forum / Q&A (#4).
- Member-to-member messaging (#5).
- Merging class journals into the existing open-mat CheckIn "My Training" *stats*
  (they remain separate records; the UI shows a second list, not a merged stat).

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Journal model | **New `ClassJournalEntry`** (separate from open-mat CheckIn) |
| Rating visibility | **Public aggregate + private gym feedback + optional anonymity** (member instructors only for the public aggregate) |
| Journal privacy | **Private by default, opt-in share** to gym members |
| "What was taught" | **Free-text + technique tags** (string list) |
| Eligibility | **Active members of the class's gym only** |

## Data Model

New TypeBox schemas in `packages/contract`; repositories in `apps/api/src/repositories`.

### New: `ClassJournalEntry`

- `id`, `classId`, `gymId`, `userId`, `date` (`YYYY-MM-DD`)
- `whatWasTaught?` (free-text), `techniqueTags: string[]` (default `[]`)
- `rounds?` (int ≥ 0), `intensity?` (int 1–5), `partners?` (int ≥ 0), `note?`
- `shared: boolean` (default `false`)
- `createdAt`, `updatedAt?`
- unique `{ classId, date, userId }`; index `{ userId, date }` (my-journal range),
  `{ classId, date, shared }` (shared-for-occurrence)

### New: `InstructorRating`

- `id`, `classId`, `gymId`, `date`
- `instructorUserId?`, `instructorName?` — snapshot of the occurrence's **effective**
  instructor at rating time (override's instructor if set, else the class's)
- `ratedByUserId`, `stars` (int 1–5), `comment?`, `anonymous: boolean` (default `false`)
- `createdAt`
- unique `{ classId, date, ratedByUserId }`; index `{ instructorUserId }` (aggregate),
  `{ gymId, instructorUserId, date }` (gym feedback)

### Response shapes (not stored)

- `InstructorRatingSummary` = `{ instructorUserId, avg, count }` (public aggregate;
  `avg` rounded to one decimal; `count` 0 when never rated).
- `InstructorFeedbackItem` = `{ classId, date, stars, comment?, ratedByName?, anonymous, createdAt }`
  — `ratedByName` omitted/`null` when `anonymous`.

## API Surface

Elysia, router → facade → repository. New `ClassJournalRepository`,
`InstructorRatingRepository`, `ClassJournalFacade`. Reuses `ClassRepository` (resolve
gym + effective instructor for an occurrence), `ClassOccurrenceRepository` (override
instructor), `MembershipRepository`, `UserRepository`, `assertCanManageGym`.

Adds a shared **`assertActiveMember(deps, userId, gymId)`** in `gym-authz.mts`:
throws `not_found` if the gym is missing, `forbidden` unless the user has an active
membership at the gym (admins and the gym owner also pass — they are implicitly
active members for authoring purposes).

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /api/v1/classes/:id/journal` (body: `date`, `whatWasTaught?`, `techniqueTags?`, `rounds?`, `intensity?`, `partners?`, `note?`, `shared?`) | active member | Upsert my journal entry for the occurrence. Validates `date` via `occursOn`. |
| `GET /api/v1/users/me/journal?from=&to=` | self | My entries in `[from,to]`, newest first. |
| `GET /api/v1/classes/:id/journal?date=` | active member | Shared entries for one occurrence (excludes private; author's own always included). |
| `POST /api/v1/classes/:id/instructor-rating` (body: `date`, `stars`, `comment?`, `anonymous?`) | active member | Upsert my rating; snapshots the effective instructor. Validates `date` via `occursOn`. |
| `GET /api/v1/users/:id/instructor-rating` | public | `InstructorRatingSummary` for a member instructor. |
| `GET /api/v1/gyms/:id/instructor-feedback?instructorUserId=&from=&to=` | owner/coach/admin | `InstructorFeedbackItem[]`, anonymity respected. |

### Effective-instructor resolution

Reuse the occurrence-expansion precedence from the class facade: the effective
instructor for `(classId, date)` = the `ClassOccurrence` override's
`instructorUserId`/`instructorName` if present, else the `GymClass`'s. The journal
facade resolves this when a rating is written and snapshots it onto the
`InstructorRating`, so the rating attaches to whoever actually taught that date.

### Authorization

- Journal upsert, rating upsert, shared-entry read: `assertActiveMember`.
- Gym instructor-feedback: `assertCanManageGym` (owner/coach/admin).
- Public aggregate: no auth.
- `GET /users/me/journal`: the caller's own id only.

## Error Handling

- Journal/rate a `date` that isn't an occurrence of the class → `400`.
- Journal/rate when not an active member → `403`; missing gym/class → `404`.
- `stars` outside 1–5 → `400` (TypeBox bound).
- Re-submit is an idempotent upsert keyed by the unique index (not a duplicate).
- Aggregate for an instructor with no ratings → `{ avg: 0, count: 0 }`.
- Mongo `null !== undefined`: normalize optional fields on write/query.

## Mobile UX

Flutter, extends `apps/mobile/lib/features/classes/` (+ a small addition to the
profile/training area).

- **Occurrence detail** (from #2): active members get a **"Journal this class"**
  action → a **journal form**: what-was-taught (multiline), technique-tag chips
  (add/remove strings), training log (rounds / intensity 1–5 / partners / note), a
  **"Share with gym"** toggle, and an optional **instructor rating** block (star
  selector + comment + "rate anonymously"). Save upserts both records; reopening
  pre-fills the member's existing entry/rating (edit).
- **Occurrence detail** shows a **"Shared notes"** list of teammates' shared entries
  for that date (from `GET /classes/:id/journal?date=`).
- **My Training** (existing screen): add a **class-journal history** section — a
  read-only list from `GET /users/me/journal`, newest first, showing what-was-taught +
  technique tags. Separate from the open-mat check-in list (no stat merge).
- **Instructor display** (occurrence/class where a member instructor is linked): show
  the public aggregate stars + count from `GET /users/:id/instructor-rating`.
- **Gym owner/coach**: an **"Instructor feedback"** entry in the gym manage area →
  list of ratings + comments per instructor, respecting anonymity.

Reuses: `currentUserIdProvider`, `authStateProvider`, the manage-capability gate,
belt-icon widgets, and the star-rating idiom from the existing review flow.

## Testing

- **Facade unit tests (core):** non-member journaling/rating → `403`;
  effective-instructor resolution (override beats template); aggregate math (avg +
  count; member-only, free-text excluded); gym-feedback anonymity (name hidden when
  `anonymous`); shared-vs-private filtering (teammates see only `shared`; author sees
  own); upsert idempotency (one row per `(classId,date,user)`); non-occurrence date →
  `400`.
- **Repository tests (local Mongo):** unique indexes on both entities; my-journal
  range query; aggregate grouping by `instructorUserId`.
- **Flutter widget tests:** journal form saves what-was-taught + tags + share toggle +
  rating; my-journal list renders; shared-notes list; instructor aggregate display.
- Verification per house rule: real API boot smoke against a throwaway local DB
  (public aggregate 200; unauth journal 401; non-member journal 403), not just green
  unit tests.

## Reuse & Shared-Code Note

`assertActiveMember` joins `assertCanManageGym` in the shared `gym-authz.mts`. The
effective-instructor resolution should reuse the class facade's occurrence logic
rather than duplicating precedence rules — factor a small shared helper if the class
facade's `occursOn`/override-merge is not already importable.

## Rollout Order (subsystem sequence, for reference)

1. Gym membership — DONE (PR #36)
2. Class schedule + attendance — DONE (PR #37)
3. **Class journaling + instructor ratings** ← this spec
4. Gym forum / Q&A
5. Member-to-member messaging
