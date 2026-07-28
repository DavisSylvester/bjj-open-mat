# Gym Membership — Design

**Date:** 2026-07-27
**Status:** Approved (design); pending spec review
**Author:** Davis Sylvester

## Context

The app already has open-mat discovery/RSVP/check-in, a training journal (via
check-ins), gym pages with ratings, and belt ranks on user profiles. Users can
log in (Auth0) and have a `role` (`practitioner` / `gym_owner` / `admin`), a
self-reported `beltRank` / `beltStripes`, and a `homeGymId`.

This spec adds **Gym Membership** — the foundational concept that a user *belongs
to* a gym. It is the first of five planned social subsystems; the other four
(class schedule + attendance, class journaling + instructor ratings, gym
forum/Q&A, member messaging) are out of scope here and key off membership.

## Goals

- A user can **join** a gym and appear on its **roster**.
- A user can belong to **multiple gyms** but designate **one home gym**.
- A gym's owner/coaches can **confirm** members and **promote/verify** belts,
  producing an auditable **promotion history**.
- Members can self-report their belt (as today); the gym is the source of truth
  for the **verified** rank.
- The roster is **public by default**, with a **per-user hide-me** toggle.

## Non-Goals

- Class schedules, attendance, journaling, instructor ratings, forum, messaging
  (later subsystems).
- Invite/approval-only joining and QR/code joining are **modeled but not built**
  now (the enums leave room; only self-join ships).
- Gym-ownership *claiming* (how a user first becomes a gym's `owner`) is a
  dependency handled by the existing gym/lead flow, not redesigned here. See
  "Open dependency" below.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| How to join | **Support several**; ship **self-join** now, model `code`/`invite` for later |
| Multi-gym | **Multiple gyms, one designated home** |
| Belt authority | Owner + coaches can promote **and** confirm self-reported belts as verified |
| Roster privacy | **Public by default** with a **per-user hide-me** toggle |

## Data Model

New and changed TypeBox schemas live in `packages/contract`
(`@bjj/contract`). Repositories in `apps/api/src/repositories`.

### New: `GymMembership`

The join between a user and a gym. A user has many.

- `id: string`
- `gymId: string`
- `userId: string`
- `status: 'pending' | 'active'` — self-join lands as `active` for viewing;
  `verifiedMember` gates trust, not visibility. `pending` reserved for the
  future invite/approval flow.
- `verifiedMember: boolean` (default `false`) — set `true` when owner/coach
  confirms.
- `gymRole: 'member' | 'coach' | 'owner'` (default `member`) — **per-gym**,
  distinct from the global `User.role`.
- `isHome: boolean` (default `false`) — kept in sync with `User.homeGymId`.
- `visibleInRoster: boolean` (default `true`) — the hide-me toggle.
- `joinMethod: 'self' | 'code' | 'invite'` (default `self`) — only `self` built.
- `joinedAt: string` (ISO)
- `createdAt?: string`

Indexes: unique `{ gymId, userId }`; `{ userId }`; `{ gymId }`.

### New: `BeltPromotion`

Audit record of a rank change. A user has many; the newest is the current
verified rank.

- `id: string`
- `userId: string`
- `gymId: string`
- `beltRank: BeltRank`
- `beltStripes: integer 0..4`
- `promotedByUserId: string`
- `promotedAt: string` (ISO)
- `note?: string`

Indexes: `{ userId, promotedAt: -1 }`; `{ gymId }`.

### Changed: `User`

Existing `beltRank` / `beltStripes` remain **self-reported**. Add gym-verified
fields (the source of truth for rank):

- `verifiedBeltRank?: BeltRank`
- `verifiedBeltStripes?: integer 0..4`
- `verifiedByGymId?: string`
- `verifiedAt?: string`

`homeGymId` is unchanged and stays authoritative for "home"; the membership's
`isHome` mirrors it.

### Changed: `Gym`

- `joinCode?: string` — reserved for the future code-join method; unused now.

No new global `UserRole` values — `coach` / `owner` are membership-scoped, so one
person can own their gym and be a plain member at a gym they cross-train at.

## API Surface

Elysia, following the existing router → service → repository layering. New
`gym-membership.routes.mts`. New `MembershipRepository`, `PromotionRepository`,
`MembershipService` (the service owns all authorization rules). All request/
response schemas are TypeBox in `@bjj/contract`.

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /gyms/:gymId/members` | member (self) | Self-join. Idempotent — re-joining returns existing membership. |
| `DELETE /gyms/:gymId/members/me` | member (self) | Leave the gym. |
| `GET /gyms/:gymId/members` | public | Roster. Server-side filters out `visibleInRoster: false`. Returns belt (self + verified), `gymRole`, `verifiedMember`. |
| `PATCH /gyms/:gymId/members/me` | member (self) | Toggle `visibleInRoster`; set/unset `isHome` (updates `User.homeGymId`). |
| `PATCH /gyms/:gymId/members/:userId` | owner/coach | Confirm member (`verifiedMember`), set `gymRole`. |
| `POST /gyms/:gymId/members/:userId/promotions` | owner/coach | Create a `BeltPromotion`; also updates the target user's `verifiedBelt*` fields. |
| `GET /users/:userId/promotions` | public | Belt/promotion history. |

### Authorization rules (in `MembershipService`)

- To confirm/promote/change roles at gym G, the caller must have an **active**
  membership at G with `gymRole` of `coach` or `owner` (or global `admin`).
- The gym's `ownerId` (existing field) is treated as an implicit `owner`
  membership so a freshly-claimed gym owner can act before any membership row is
  reconciled.
- A user cannot promote themselves.
- Promotion writes are transactional-ish: write the `BeltPromotion` record, then
  update `User.verifiedBelt*`. On read, the newest promotion is the truth; the
  denormalized `User` fields are a cache for list/profile rendering.

## Mobile UX

Flutter, new `apps/mobile/lib/features/membership/` (data / models / screens /
widgets), matching the existing feature-folder convention.

- **Gym detail screen**: **Join / Leave** button + **member count**.
- **Roster tab** on a gym: paged grid reusing the existing belt-icon attendee
  widgets; belt shows a ✓ when verified; **Owner** / **Coach** role badges.
  Tapping a member with a profile → their public profile.
- **Profile → "My gyms"**: list of the user's memberships, which is home
  (switchable), and the hide-me toggle.
- **Coach/owner management**: on the roster, owner/coaches see a manage
  affordance → confirm member, assign coach, **Promote belt** sheet (belt +
  stripes + optional note).
- **Profile**: verified rank rendered with ✓ and "promoted at \<gym\> on
  \<date\>"; a belt-history list from `GET /users/:userId/promotions`.

Privacy: hidden members are filtered **server-side** (same pattern as hidden
open-mats), never only client-side.

## Error Handling

- Join when already a member → return the existing membership (idempotent, 200).
- Promote/confirm without owner/coach rights → `403`.
- Promote a non-member of the gym → `404` (target has no membership at G).
- Self-promotion attempt → `403`.
- Toggling `isHome` on demotes the previous home membership and updates
  `User.homeGymId` atomically at the service layer.
- Mongo `null != undefined` gotcha: normalize optional membership fields on
  write and query so absent vs. explicit-null don't diverge (previously hit on
  the check-in form).

## Testing

- **Service unit tests**: only owner/coach/admin can confirm/promote; cannot
  promote at a gym you don't coach; cannot self-promote; `isHome` reassignment
  demotes the prior home; promotion updates both the record and the user's
  verified fields.
- **Repository tests**: roster excludes `visibleInRoster: false`; unique
  `{ gymId, userId }` prevents duplicate joins; the `null != undefined`
  normalization.
- **Flutter widget tests**: join/leave button state; roster renders verified ✓
  and role badges; promote sheet validation (stripes 0–4).

## Open Dependency

Becoming a gym's **owner** (first coach/owner at a gym) relies on the existing
gym-claim / lead flow (`lead.routes.mts`, `gym-lead.repository.mts`, and
`Gym.ownerId`). This spec treats `Gym.ownerId` as an implicit owner so promotion
works day one; a follow-up may reconcile `ownerId` into an explicit `owner`
membership row. If that flow does not currently let a user claim ownership,
that gap must be closed before coach/owner features are usable in production.

## Rollout Order (subsystem sequence, for reference)

1. **Gym Membership** ← this spec
2. Class schedule + attendance
3. Class journaling + instructor ratings
4. Gym forum / Q&A
5. Member-to-member messaging
