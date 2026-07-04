# Community Open-Mat Submissions — Design

**Date:** 2026-06-21
**Status:** Approved (design); pending implementation plan

## Goal

Make BJJ Open Mat a global directory of open mats across the US by letting **anyone** (any authenticated user, not just gym owners) submit a session. Submitting is a **first-class action** surfaced prominently in the UI. Submissions are **live immediately** but marked **unverified** until the gym's owner or an admin confirms them; owners/admins can also hide bad entries.

## Decision note (reconciliation)

The original request said a session "won't be public until the gym owner or an admin approves." During brainstorming the chosen moderation model was **auto-approve + flag for review** instead: sessions are visible immediately, start unverified, and owner/admin can verify or hide. This was a deliberate change (a hard pending-gate would hide most sessions, since most gyms have no registered owner — undermining the "global directory" goal). This spec implements the auto-approve/verify model. If a hard pending-gate is actually wanted, revisit before implementation.

## Model overview

Two independent flags on an open mat:

- **`status`**: `'live' | 'hidden'`, default `'live'`. Moderation switch. Public listings exclude `hidden`.
- **`verified`**: `boolean`, default `false`. True when the gym's owner or an admin has confirmed the session (or when the submitter is the gym owner / an admin at create time).

Community submissions are `status='live'`, `verified=false` → visible, badged "Unverified."

## 1. Contract changes (`packages/contract`)

### `schemas/open-mat.mts` — `OpenMat`
Add:
- `verified: t.Boolean({ default: false })`
- `status: t.Union([t.Literal("live"), t.Literal("hidden")], { default: "live" })`
- `hostId` (already optional) is repurposed as the **submitter's userId** (who created the session). Keep optional for backward compatibility with existing data.

`OpenMatDetail` composes `OpenMat`, so it inherits the new fields.

### `schemas/requests/open-mat-requests.mts`
- `CreateOpenMatRequest`: make `gymId` optional and add an optional inline gym:
  - `newGym: t.Optional(t.Object({ name, address, city?, state?, postalCode?, country? }))`
  - Validation rule (enforced in the facade): **exactly one** of `gymId` / `newGym` must be present.
- `OpenMatListQuery`: add
  - `status: t.Optional(t.Union([Literal("live"), Literal("hidden")]))`
  - `verified: t.Optional(t.Boolean())` (filter verified/unverified)
  - `submittedByMe: t.Optional(t.Boolean())` (sessions where `hostId` == caller) — distinct from existing `mine` (gym-owner's sessions).
- New `VerifyResult`/no body needed for verify/hide (path-only POSTs).

### `enums/user-role.mts`
- Add `t.Literal("admin")` to the `UserRole` union → `practitioner | gym_owner | admin`.

Regenerate/extend derived types and barrels as needed.

## 2. API changes (`apps/api`)

### Auth (`auth/auth.middleware.mts`)
- Add a `requireAdmin(enabled)` macro mirroring `requireOwner` (403 unless `identity.role === "admin"`).
- Admins bypass gym-owner checks (see facade helpers).

### Routes (`routes/open-mat.routes.mts`)
- `POST /api/v1/open-mats`: change `{ requireOwner: true }` → `{ requireAuth: true }`. Pass the caller's identity (id + role) to the facade.
- `GET /api/v1/open-mats` (public list): default to `status='live'` only (exclude hidden). Honor new query filters (`verified`, `submittedByMe`). Existing `mine` (gym-owner's gyms) unchanged.
- New: `POST /api/v1/open-mats/:id/verify` — owner of the session's gym **or** admin → sets `verified=true`.
- New: `POST /api/v1/open-mats/:id/hide` and `POST /api/v1/open-mats/:id/unhide` — owner-or-admin → sets `status='hidden'`/`'live'`.

### Facade (`facades/open-mat.facade.mts`)
- `create(submitterId, req, { role })`:
  - Resolve the gym: if `req.gymId`, load it (404 if missing). If `req.newGym`, create an **unverified, owner-less gym** (`ownerId: undefined`, `isVerified: false`) via the gym repository and use it.
  - **Remove** the current `gym.ownerId !== ownerId → forbidden` check.
  - Set `hostId = submitterId`, `status = "live"`, `verified = role === "admin" || gym.ownerId === submitterId`.
  - Insert; the session is associated with `gym.ownerId` (may be undefined) for the owner `mine` filter.
- `verify(callerId, role, id)` and `setHidden(callerId, role, id, hidden)`: load session + gym; allow if `role === "admin"` or `gym.ownerId === callerId`; else 403. Update the flag.
- Add `assertOwnerOrAdmin(callerId, role, openMatId)` helper (generalizes `assertOwner`).
- `update(...)`: also allow admin (currently owner-only).

### Repository (`repositories/open-mat.repository.mts`)
- Persist `verified`, `status`, `hostId`.
- `list` filter: support `status` (default exclude `hidden`), `verified`, and a `hostId` filter for `submittedByMe`.

### Gym creation for contributors
- Inline `newGym` is created **through the open-mat facade** (no need to open `POST /gyms`). `POST /gyms` stays `requireOwner` for the owner-driven gym flow.

### Seed / dev
- `DEMO_USER_ROLE` may be set to `admin` to exercise admin flows locally (in addition to `gym_owner`).

## 3. Mobile — adding is first-class (`apps/mobile`)

### Bottom navigation (`app/router.dart`, `shared/widgets/app_bottom_nav.dart`, `om_widgets.dart` OMBottomNav)
- Add a **center raised "+" button** to both the practitioner and owner nav bars. Tapping it routes to the create flow.
- Add a top-level route (e.g. `/add-session`) that renders the create screen and is reachable by **any** authenticated user (not under `/owner`).

### Create flow (`features/admin/screens/create_session_screen.dart` → generalize, likely move to a shared `features/open_mats/screens/`)
- Replace the owner-only `myGymsProvider` gym picker with:
  - A **searchable list of all gyms** (new provider backed by `GET /gyms` with a name/city query), and
  - A **"Can't find your gym? Add it"** affordance revealing inline fields: name, address, city, state (postal optional).
- Build `CreateOpenMatRequest` with either the selected `gymId` or the `newGym` object.
- Submit enabled when a gym is selected **or** new-gym name+address are filled (drop the "Add a gym first" gate).
- Success copy: "Posted — it's live now and marked unverified until the gym or an admin confirms it."

### Surfacing & badges
- `shared/widgets/session_row.dart` (and the detail screen): show an **"Unverified"** chip when `verified == false`. Hidden sessions are not fetched for public lists.
- `models/open_mat.dart`: add `verified` and `status` fields + JSON mapping.

### Moderation
- **Owner Sessions screen** (`features/admin/screens/session_mgmt_screen.dart`): list the gym's sessions including community submissions; each row gets **Verify** and **Hide** actions (calls the new endpoints; invalidates the list).
- **Admin review screen** (new, e.g. `features/admin/screens/admin_review_screen.dart`, route `/admin/review`): lists `live` + `unverified` sessions across all gyms with **Verify / Hide**; entry shown to users whose role is `admin` (e.g., from the Profile/Settings screen). Guarded so non-admins can't reach it.

### Data layer (`features/open_mats/data/session_repository.dart`)
- `create` supports the `newGym` payload.
- Add `verify(id)`, `hide(id)`, `unhide(id)`.
- Add `listUnverified()` (admin) and `listSubmittedByMe()` as needed.

## 4. Testing

### API (`apps/api/test`, `bun test`)
- A non-owner can create a session → 200, `verified=false`, `status='live'`, `hostId=caller`.
- Create with `newGym` → creates an unverified gym and the session.
- Gym owner creating their own gym's session → `verified=true`.
- Admin verify / hide any session; non-owner non-admin → 403.
- Public `GET /open-mats` excludes `status='hidden'`; includes unverified.

### Mobile
- Widget test: create screen reachable from both shells via the center "+"; new-gym inline path builds the right request; "Unverified" badge renders when `verified=false`.
- Integration (emulator, dev-bypass): anyone adds a session → it appears in the list as live + unverified. (Mirrors existing `create_open_mat_session_test.dart`.)

## Out of scope (YAGNI)

- End-user "report this session" button.
- Admin user-management UI (granting the admin role) — set via DB/seed for now.
- Email/push notifications on verify/hide.
- De-duplication of inline-added gyms (accepted as a known follow-up).

## Affected files (summary)

- Contract: `schemas/open-mat.mts`, `schemas/requests/open-mat-requests.mts`, `enums/user-role.mts` (+ barrels/types).
- API: `auth/auth.middleware.mts`, `routes/open-mat.routes.mts`, `facades/open-mat.facade.mts`, `repositories/open-mat.repository.mts`.
- Mobile: `app/router.dart`, `shared/widgets/app_bottom_nav.dart`, `shared/widgets/om_widgets.dart`, `features/.../create_session_screen.dart`, `features/admin/screens/session_mgmt_screen.dart`, new admin review screen, `shared/widgets/session_row.dart`, `features/open_mats/screens/open_mat_detail_screen.dart`, `features/open_mats/models/open_mat.dart`, `features/open_mats/data/session_repository.dart`.
