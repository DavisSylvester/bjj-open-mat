# Gym Ownership / Claim Flow — Design

**Date:** 2026-07-30
**Status:** Approved (design); implementation plan to follow.

## Problem

There are 847 gyms in production and **none has an `ownerId`**. `Gym.ownerId` is set only at gym-creation time and there is no path to assign or reassign it afterward. Every owner-gated feature is therefore unreachable in production:

- Logo upload, edit gym (gated by the `requireOwner` account-role macro)
- Instructor feedback, gym admin, forum moderation, class + open-mat management (gated by `assertCanManageGym` / `gym.ownerId === callerId`)

We need a way for a real gym owner/manager to **claim** a gym so those features become usable.

## Goal

Let a user claim an unowned gym (or request transfer of an owned one); the admin reviews submitted evidence and approves or rejects; on approval the app grants real ownership so the previously-unreachable owner features become usable.

## Resolved decisions

1. **Verification model:** manual admin approval. A claim is a queued request the admin approves/rejects; no automated/contact-code verification in v1.
2. **Admin surface:** `requireAdmin`-gated REST endpoints (the foundation) **and** an in-app admin screen built on them, mirroring the existing gym message-reports review screen.
3. **Claim scope:** claim **unowned** gyms **and** request **transfer** of already-owned gyms (admin adjudicates; current owner is notified on a transfer request). One owner per gym; a transfer moves ownership.
4. **Evidence collected:** claimant's relationship to the gym (owner / head coach / manager), a contact (email/phone) they say matches the gym, and a free-text message. No file upload. The admin screen shows the gym's scraped `phone`/`website` alongside for cross-checking.
5. **Notifications:** in-app only (reusing the existing notifications feature). Claimant is notified on the decision; current owner is notified when a transfer is requested.

**Decided-by-code fact:** approval elevates `user.role → gym_owner`, not only `gym.ownerId`. Logo-upload and edit-gym are gated by the `requireOwner` account-role macro, so setting `ownerId` alone would not unblock them.

## Out of scope (deferred)

- Co-owner / staff delegation (the per-gym `coach`/`owner` membership `gymRole` already partly covers this).
- Automated or contact-code verification.
- Email notifications.
- File-upload evidence (would reuse the existing S3 presigned-upload pattern).

## Flow

```
Claimant                        System                         Admin
--------                        ------                         -----
Gym detail → "Claim this gym"
  or "Request ownership"
      │ relationship, contact, message
      ▼
                          GymClaim (pending) ──────────────►  Admin claims queue
                          (kind auto = claim|transfer)         (evidence + gym's
                          if transfer: notify current owner     scraped phone/website)
                                                                    │ approve / reject
                                                                    ▼
                          approve → gym.ownerId = claimant
                                    user.role → gym_owner
                                    membership.gymRole = owner
                                    (transfer: downgrade old owner)
                                    supersede other pending claims
                          notify claimant (approved/rejected)
```

## Data model

### Enums (`packages/contract/src/enums/`)

- `GymClaimStatus` = `'pending' | 'approved' | 'rejected' | 'cancelled'`
- `GymClaimKind` = `'claim' | 'transfer'` — `claim` when the gym is unowned at submission, `transfer` when it already has an owner. **Stored, not derived**, so the admin queue and history are unambiguous.
- `ClaimantRelationship` = `'owner' | 'head_coach' | 'manager'`

### Schema `GymClaim` (`packages/contract/src/schemas/gym-claim.mts`)

| field | type | notes |
|---|---|---|
| `id` | string | |
| `gymId` | string | |
| `claimantId` | string | requesting user |
| `kind` | GymClaimKind | claim vs transfer |
| `relationship` | ClaimantRelationship | |
| `contact` | string | email/phone the claimant says matches the gym |
| `message` | string | free-text justification |
| `status` | GymClaimStatus | default `pending` |
| `previousOwnerId` | string? | set on transfer (owner at decision time) |
| `createdAt` | string | ISO |
| `decidedAt` | string? | set on approve/reject |
| `decidedBy` | string? | admin userId |
| `decisionNote` | string? | admin reason (esp. on reject) |

Every schema carries `$id` (project convention); types derived with `Static<typeof X>`.

### Notification type

Add one value `'gym_claim'` to the existing `NotificationType` enum. The notification `data` field carries `{ gymId, claimId, outcome }` so the mobile client can deep-link to the gym.

### Indexes (`gymClaims` collection)

- `{ gymId: 1, claimantId: 1 }` — dedupe pending claims
- `{ status: 1, createdAt: 1 }` — admin queue
- `{ claimantId: 1 }` — my-claims

## State machine

```
          submit
            │
            ▼
        ┌────────┐  admin approve   ┌──────────┐
        │pending │ ───────────────► │ approved │
        └────────┘                  └──────────┘
          │   │  admin reject (note)  ┌──────────┐
          │   └─────────────────────► │ rejected │
          │      claimant withdraw    └──────────┘
          └─────────────────────────► ┌───────────┐
                                       │ cancelled │
                                       └───────────┘
```

- **One active pending claim per (gym, claimant)** — re-submitting while pending is rejected at the API as a duplicate.
- Multiple *different* users may have pending claims on the same gym; **approving one auto-supersedes the others** (→ `rejected`, note "superseded", each claimant notified).
- Only `pending` claims can be approved / rejected / cancelled; acting on an already-decided claim is a guarded error.

## Facade orchestration

A new **`GymClaimFacade`** owns all logic (layering: routes → facade → repositories). It depends on `Pick<>` slices of `GymClaimRepository`, `GymRepository`, `UserRepository`, `MembershipRepository`, `NotificationRepository`. Identity (`claimantId`, `decidedBy`) always comes from the auth `identity`, never from the request body.

### `submit(callerId, gymId, { relationship, contact, message })`

1. Load gym (404 if missing).
2. Guard: caller isn't already this gym's owner (409 no-op).
3. Guard: no existing `pending` claim by caller for this gym (409 duplicate).
4. `kind` = `gym.ownerId` ? `'transfer'` : `'claim'`.
5. Insert `GymClaim` (pending).
6. If `transfer`: notify current owner — `gym_claim` notification "Someone requested ownership of {gym}".
7. Return the claim.

### `approve(adminId, claimId)`

1. Load claim; guard `pending`. Load gym.
2. `previousOwnerId` = `gym.ownerId` (may be null).
3. `gym.ownerId = claim.claimantId`.
4. Elevate `user.role → gym_owner` (no-op if already `gym_owner` / `admin`).
5. Upsert claimant membership → `gymRole: 'owner'`, `status: 'active'`, `verifiedMember: true`.
6. If `previousOwnerId` and ≠ claimant: downgrade old owner's membership `gymRole: owner → member` (keep account role — they may own other gyms) and notify them "Ownership of {gym} was transferred."
7. Mark claim `approved` (`decidedAt`, `decidedBy`).
8. Supersede other `pending` claims for this gym → `rejected` (note "superseded"), notify each.
9. Notify claimant "Your claim for {gym} was approved."

### `reject(adminId, claimId, note)`

Guard `pending` → `rejected` (+ note, `decidedAt`/`decidedBy`) → notify claimant "…was not approved" (+ note).

### `cancel(callerId, gymId)`

Claimant withdraws their own `pending` claim → `cancelled`.

## API endpoints

### Claimant (authenticated)

- `POST /api/v1/gyms/:id/claims` — submit; body `{ relationship, contact, message }`
- `GET /api/v1/gyms/:id/claims/me` — caller's **most recent** claim for this gym by `createdAt` (drives the gym-detail entry-point state; `null` if none). A prior `rejected`/`cancelled` claim does not block the state machine's single-`pending` rule.
- `DELETE /api/v1/gyms/:id/claims/me` — withdraw pending claim
- `GET /api/v1/users/me/gym-claims` — caller's claims across gyms (status tracking)

### Admin (`requireAdmin: true` macro)

- `GET /api/v1/admin/gym-claims?status=pending` — queue; each row enriched with a lightweight gym summary + scraped `phone`/`website` and the claimant's email for cross-check
- `POST /api/v1/admin/gym-claims/:claimId/approve`
- `POST /api/v1/admin/gym-claims/:claimId/reject` — body `{ note }`

All bodies validated with TypeBox `t` (Elysia-native). The admin list response composes the stored `GymClaim` with a gym+claimant projection.

## Authorization

- Claimant routes — any authenticated user; the `/me` routes scope strictly to `claim.claimantId === callerId`.
- Admin routes — `requireAdmin` macro only (403 for non-admins); no `ownerId`/membership bypass.

## Edge cases

- **Race — gym gets owned between submit and approve.** Approve is authoritative: it captures whatever `gym.ownerId` is at decision time as `previousOwnerId` and overwrites with the claimant. A `claim`-kind request whose gym became owned still approves cleanly as an effective transfer.
- **Claimant already `gym_owner`** (owns other gyms) — role elevation is a no-op; still set `ownerId` + owner membership.
- **Claiming your own gym / duplicate pending** — guarded 409 no-ops.
- **Old owner had the gym as `isHome`** — only `gymRole` is downgraded; membership + `isHome` stay intact.
- **Mongo update hygiene** — follow the repo precedent (`$set`/`$unset` split; never both for one field; never an empty `$set`).
- **Non-existent gym/claim** — 404; acting on a decided claim — guarded error.

## Mobile UX

### Gym-detail entry point

State depends on `GET /gyms/:id/claims/me` + `gym.ownerId` + caller role:

| Situation | What the user sees |
|---|---|
| Gym unowned, no claim by caller | **"Claim this gym"** row → claim form (`kind: claim`) |
| Gym owned by someone else, caller not owner/admin | **"Request ownership"** row → claim form (`kind: transfer`) |
| Caller has a `pending` claim | Chip **"Claim pending review"** + **Withdraw** action |
| Caller has a `rejected` claim | Chip **"Not approved"** + allow re-submit |
| Caller is the owner (or admin) | No entry point |

### Screens

- **`ClaimGymScreen(gymId, kind)`** — form: `relationship` dropdown (Owner / Head coach / Manager), `contact` field, `message` multiline. Submit → `POST …/claims`, pop back to gym detail (now showing the pending chip). Failures routed through `friendlyErrorMessage`.
- **`AdminGymClaimsScreen`** — admin-gated list mirroring `GymReportsScreen`: each card shows gym name, claimant relationship/contact/message, and the gym's scraped `phone`/`website` side-by-side, with **Approve** / **Reject (note)** buttons. Route `/admin/gym-claims`; reached from an admin-only row in Profile settings (gated on `role == 'admin'`).

### State (Riverpod)

- `gymClaimRepository` (Dio) — submit / myClaimForGym / withdraw / admin list / approve / reject
- `myGymClaimProvider(gymId)` — drives the gym-detail entry-point; invalidated after submit/withdraw
- `adminPendingClaimsProvider` — the queue; invalidated after approve/reject
- After an approval affecting the caller's own gym, invalidate `gymByIdProvider` (not `gymDetailProvider` — a prior bug) and memberships so owner UI appears.

## Testing

- **Contract:** `GymClaim` schema + enums round-trip and request-body validation.
- **API (`GymClaimFacade`, integration against local Mongo):** kind detection (claim vs transfer); duplicate-pending guard; own-gym guard; approve side-effects (`ownerId` set, role elevated, owner membership upserted, old owner downgraded on transfer, other pendings superseded, notifications created); reject (note + notification); cancel; admin-list enrichment; authz (non-admin rejected from approve/reject). Facade assertions use direct `await` (avoid the Bun `.resolves` CSOT hang).
- **Mobile (`flutter test`):** `ClaimGymScreen` form submit; gym-detail entry-point gating across all five states; `AdminGymClaimsScreen` admin gating + approve/reject calls + provider invalidation.

## New files

- **Contract:** `enums/{gym-claim-status,gym-claim-kind,claimant-relationship}.mts`, `schemas/gym-claim.mts`, request schemas, `+ 'gym_claim'` on `notification-type`; barrels updated.
- **API:** `repositories/gym-claim.repository.mts`, `facades/gym-claim.facade.mts`, `routes/gym-claim.routes.mts` (+ admin routes), container/DI wiring.
- **Mobile:** `features/gym_claims/{data,models,screens}`, router entries, gym-detail entry point, profile admin row.
