# Gym Forum / Q&A — Design

**Date:** 2026-07-28
**Status:** Approved (design); pending spec review
**Author:** Davis Sylvester

## Context

Subsystem #4 of the 5-part social-gym plan (membership PR #36, class schedule PR
#37, class journaling + instructor ratings merged). The app has gym membership
(roster, `gymRole`, the shared `assertActiveMember` / `assertCanManageGym`
authorizers) and a `Notification` model + `NotificationType` enum.

This spec adds a **members-only, gym-scoped Q&A forum**: members ask questions
(with a category), members answer, and the asker or a coach/owner/admin marks an
accepted answer. Coach/owner/admin moderate (pin / lock / delete). Answering and
accepting generate notifications.

## Goals

- Active members of a gym can view and post questions/answers in that gym's forum.
- Q&A shape: a question thread, its answers, and one **accepted answer**.
- Questions carry a **category** from a fixed set.
- Coach/owner/admin **moderate** (pin, lock, delete any); authors edit/delete their own.
- **Notifications:** the asker is notified on a new answer; an answerer is notified
  when their answer is accepted.

## Non-Goals (later)

- Member-to-member **messaging** (subsystem #5).
- Upvotes/reactions, rich text/attachments, full-text search, per-gym custom
  categories, public (non-member) forum access.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Structure | **Q&A** (question → answers → one accepted answer) **+ fixed categories** |
| Access | **Members-only** (view + post), via `assertActiveMember` |
| Accept authority | **Asker OR coach/owner/admin** |
| Moderation | **Coach/owner/admin** pin/lock/delete; authors edit/delete own |
| Notifications | **Answer + accepted** notifications |

## Data Model

New TypeBox schemas in `packages/contract`; repositories in `apps/api/src/repositories`.

### New enum: `ForumCategory`

`technique | rules | competition | schedule | gear | general` (fixed).

### New: `ForumQuestion`

- `id`, `gymId`, `authorId`, `category: ForumCategory`, `title`, `body`
- `pinned: boolean` (default false), `locked: boolean` (default false)
- `acceptedAnswerId?: string`, `answerCount: integer ≥ 0` (default 0)
- `createdAt`, `updatedAt?`
- Indexes: `{ gymId, pinned, createdAt }` (list ordering), `{ gymId, category }`.

### New: `ForumAnswer`

- `id`, `questionId`, `gymId`, `authorId`, `body`
- `accepted: boolean` (default false)
- `createdAt`, `updatedAt?`
- Indexes: `{ questionId, createdAt }`, `{ gymId }`.

### Changed: `NotificationType`

Add `forum_answer` and `forum_accepted`. Forum notifications reuse the existing
`Notification` model; `data` carries `{ questionId, gymId }` for deep-linking.

### Response shape (not stored): `ForumQuestionDetail`

`{ question: ForumQuestion, answers: ForumAnswer[] }` — answers ordered accepted-first
then oldest-first.

## API Surface

Elysia, router → facade → repository. New `ForumQuestionRepository`,
`ForumAnswerRepository`, `ForumFacade`. Reuses `MembershipRepository`,
`GymRepository`, `NotificationRepository` (writes the two notifications),
`assertActiveMember`, `assertCanManageGym`. The facade resolves each entity's
`gymId` (answers/accept resolve it from the parent question) before authorizing.

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /api/v1/gyms/:id/forum/questions` (`{category,title,body}`) | active member | Create a question. |
| `GET /api/v1/gyms/:id/forum/questions?category=&page=&limit=` | active member | List — pinned first, then newest; optional category filter; paged. |
| `GET /api/v1/forum/questions/:id` | active member (of the question's gym) | `ForumQuestionDetail` (question + answers). |
| `PATCH /api/v1/forum/questions/:id` (`{title?,body?,category?,pinned?,locked?}`) | author (content) / moderator (pinned,locked) | Field-level authz. |
| `DELETE /api/v1/forum/questions/:id` | author or moderator | Delete question + its answers. |
| `POST /api/v1/forum/questions/:id/answers` (`{body}`) | active member | Post answer; **409 if locked**; `answerCount++`; notify asker (`forum_answer`). |
| `PATCH /api/v1/forum/answers/:id` (`{body}`) | author | Edit own answer. |
| `DELETE /api/v1/forum/answers/:id` | author or moderator | Delete answer; `answerCount--`; clear `acceptedAnswerId` if it was the accepted one. |
| `POST /api/v1/forum/questions/:id/accept` (`{answerId}`) | asker or moderator | Set `acceptedAnswerId` + flip that answer's `accepted` (unset any prior); notify answerer (`forum_accepted`). |

### Authorization rules (in `ForumFacade`)

- Read (list, detail), create question, create answer → `assertActiveMember(deps, userId, gymId, role)`.
- Edit content (title/body/category on a question; body on an answer) → `authorId === callerId` only.
- `pinned`/`locked` on a question → `assertCanManageGym` (coach/owner/admin).
- A `PATCH` question mixing content + moderation fields is allowed only if the caller
  satisfies both checks for the fields present; otherwise `403`.
- Delete question/answer → `authorId === callerId` OR `assertCanManageGym`.
- Accept → `question.authorId === callerId` OR `assertCanManageGym`; `answerId` must
  belong to the question (else `400`).
- Answer on a `locked` question → `409` (moderators included; locking closes answering).
- Self-notification suppressed: if the asker answers their own question, or accepts
  with the answerer being themselves, skip the notification write.

## Error Handling

- Non-member read/write → `403`; missing gym/question/answer → `404`.
- Answer a locked question → `409`.
- Accept an `answerId` not on the question, or by a non-asker/non-moderator → `400`/`403`.
- Empty `title`/`body` → TypeBox `minLength` `400`.
- `answerCount` never goes negative; deleting the accepted answer clears
  `acceptedAnswerId`.
- Mongo `null !== undefined`: normalize optional fields on write/query.

## Mobile UX

Flutter, new `apps/mobile/lib/features/forum/` (data / models / screens / widgets).

- **Gym detail**: a **"Forum"** entry shown to members → **forum list screen**:
  questions with title, category chip, author, answer count, an accepted ✓ badge, a
  📌 for pinned (pinned sort first); a category filter and an **"Ask a question"** FAB.
- **Ask-question screen**: category dropdown + title + body; submit → create.
- **Question detail**: the question, then answers (accepted answer highlighted and
  first), an **answer composer** (hidden/disabled when `locked`), an **Accept** control
  per answer (visible to asker/moderator), and **moderation actions** (pin / lock /
  delete) for coach/owner/admin (reuse the `canManage` gate). Authors get edit/delete
  on their own question/answers.
- Forum notifications appear in the existing notifications feature (deep-link via
  `data.questionId`).

Reuses: `assertActiveMember`-equivalent client gate (member of `rosterProvider(gymId)`
or admin/owner), the `canManage` derivation, `currentUserIdProvider`,
`authStateProvider`, and existing list/detail screen patterns.

## Testing

- **Facade unit tests (core):** members-only gating (non-member → 403 on read AND
  write); locked question rejects answers (409); accept authz (asker OR moderator; a
  plain non-asker member cannot accept); moderation authz (pin/lock require
  coach/owner/admin); accept sets `acceptedAnswerId`, flips the answer, and unsets a
  prior accepted; delete-answer decrements `answerCount` and clears acceptance when
  applicable; notification written on answer + accept, and suppressed for self.
- **Repository tests (local Mongo):** pinned-first + newest ordering, category filter,
  pagination; `answerCount` maintenance; unique/lookup indexes.
- **Flutter widget tests:** list renders pinned/accepted badges + category chip;
  question detail shows accepted highlight; answer composer hidden when locked; ask
  form validation; moderation actions gated to managers.
- Verification per house rule: real API boot smoke against a throwaway local DB
  (member-gated list → 403 without membership context is hard to smoke; instead assert
  unauth create → 401, and a public-ish 404 on a missing question), not just green
  unit tests.

## Reuse & Shared-Code Note

Authorization reuses `assertActiveMember` and `assertCanManageGym` from
`gym-authz.mts` — no new authorizer. Notification writes reuse
`NotificationRepository`; add the two `NotificationType` literals only. Follow the
prefixed-Elysia-instance route pattern (`/api/v1/gyms` + `/api/v1/forum`) used by the
membership/class routes to avoid memoirist param-name conflicts.

## Rollout Order (subsystem sequence, for reference)

1. Gym membership — DONE (PR #36)
2. Class schedule + attendance — DONE (PR #37)
3. Class journaling + instructor ratings — DONE (merged)
4. **Gym forum / Q&A** ← this spec
5. Member-to-member messaging
