# Home Gym / Membership Sync — Design

**Date:** 2026-07-30
**App:** BJJ OPEN MAT (Apple ID `6787704999`)
**Status:** Approved

## Problem

"Home gym" is written by two paths, and only one of them keeps the two representations in sync.

| Path | Writes `users.homeGymId` | Writes `gymMemberships` |
|---|---|---|
| My Gyms → "Set as home" (`MembershipFacade.setMine`, `membership.facade.mts:96-97`) | ✅ | ✅ |
| Edit Profile → home gym (`UserFacade.updateProfile`, `user.facade.mts:61-66`) | ✅ | ❌ |

`UserFacade.updateProfile` is a generic field writer — it patches whatever it is handed and has no idea `homeGymId` means anything more than a string.

**Observed in production.** Two users (Davis and Camille Sylvester) have RM Elite Brazilian
Jiu-Jitsu as their profile home gym. Both set it from the profile screen — the unsynced
path — so:

- their profiles show a home gym,
- "My Gyms" shows "No gym memberships yet",
- the gym's Members screen is empty.

All three are correct readings of the data. They just disagree.

**Scale of the gap.** The `gymMemberships` collection holds **0 documents** across 847 gyms
and 14 users. Nobody has ever joined a gym, so every membership-gated surface is dark:
`deriveCanAccessForumGym` requires an active membership, so the gym forum is unreachable for
everyone; the My Gym tab's `isHome` fallback can never fire.

## Fix

`UserFacade.updateProfile` gains the missing half of the sync. When a patch contains a
`homeGymId` that differs from the user's current value, it also ensures a membership at that
gym and marks it home.

### One entry point, not repository access

`UserFacade` calls a single new method on `MembershipFacade`:

```
ensureHome(userId: string, gymId: string): Promise<void>
```

which joins if needed, then marks the membership home. `UserFacade` does not gain the
membership repository, and does not reimplement join logic.

**Dependency direction must stay one-way.** `MembershipFacade` today depends on the *user
repository* (`this.users.update`), not on `UserFacade`, so adding `UserFacade → MembershipFacade`
creates no cycle. The implementation must not introduce the reverse edge.

`ensureHome` composes existing behaviour rather than duplicating it:

- `MembershipFacade.join` (`membership.facade.mts:40`) already throws
  `AppError('not_found')` when the gym does not exist, and already uses `upsertJoin`, so it
  is idempotent.
- Marking home reuses the existing `memberships.setHome(userId, gymId)`.

`ensureHome` deliberately does NOT call `setMine`, which would write `homeGymId` a second
time — redundant here, and it would create a second path back into user state.

### Behaviour

| Case | Result |
|---|---|
| `homeGymId` unchanged | No membership write at all. Idempotent — no duplicate, no `updatedAt` churn. |
| Membership already exists | Marked home. No second join. |
| No membership yet | Joined (`status: active`, `gymRole: member`, `joinMethod: self`, `visibleInRoster: true`), then marked home. |
| Gym does not exist | **The whole profile update is rejected** with the `not_found` that `join` already throws. |
| Patch has no `homeGymId` | Untouched. Existing behaviour exactly. |

**On rejecting the update for a missing gym.** This is a real behaviour change: today the
profile saves and the bad id is stored silently. Rejecting is the right trade — accepting a
home gym that cannot be joined recreates precisely the divergence this work removes.

**Setting a home gym joins the gym.** That is the intended semantic, not a side effect: a
declared home gym now means a roster entry. Note it makes the user visible in that gym's
roster (`visibleInRoster: true`, matching `join`'s existing default), which they can turn off
from My Gyms.

## Backfill

A one-off script for users holding a `homeGymId` with no matching membership — **3 users
today**.

- Read-only by default: prints every user and gym it would touch and changes nothing.
- Writes only with an explicit `--commit` flag, mirroring the pattern the
  `fb-open-mat-scraper` skill already uses for production writes.
- Skips any user whose `homeGymId` points at a gym that no longer exists, and reports those
  separately rather than failing the run.
- Idempotent: safe to run twice; a user who already has the membership is skipped.

## Testing

- `ensureHome`: joins when no membership exists; marks home without a second join when one
  does; propagates `not_found` for an unknown gym; idempotent on repeat.
- `updateProfile`: syncs on a changed `homeGymId`; makes no membership call when the value is
  unchanged; makes no membership call when the patch omits `homeGymId`; rejects the whole
  update when the gym is unknown; leaves every other field's behaviour untouched.
- Backfill: dry run writes nothing; `--commit` creates exactly the missing memberships; a
  second run is a no-op; a user pointing at a missing gym is reported and skipped.

## Out of scope

- **Gym ownership.** 0 of 847 gyms have an `ownerId`, so logo upload, instructor feedback,
  and gym admin stay unreachable. That is a separate gap with its own product question
  (how does a gym get claimed?) and must not be bundled here.
- Removing the home-gym field from the profile screen. Both paths stay; they simply agree now.
- Deduplicating gym records. Two RM Elite rows exist (`518d6c86…` and `gpl-ChIJQ6Rb…`);
  worth addressing separately.
- Any mobile change. The profile screen already sends `homeGymId`; only the server behaviour
  changes.

## Risks

**Unexpected roster visibility.** A user who set a home gym months ago as a private note now
appears on that gym's public roster after the backfill. With 3 affected users — two of them
the app's owner — the blast radius is negligible today, but the same code will apply to every
future user, so the profile screen should eventually say that setting a home gym joins the gym.
Recorded as follow-up rather than fixed here, since it is a copy change on a screen this work
does not otherwise touch.

**Profile saves can now fail for a new reason.** A stale `homeGymId` — a gym deleted after the
user selected it — turns a previously-succeeding profile save into a `not_found`. The backfill
surfaces how many such users exist today (expected: none), and the mobile client already
renders `friendlyErrorMessage` for a 404 rather than raw text.

## Follow-up work

1. **Tell users that setting a home gym joins the gym**, on the profile screen's home-gym
   field.
2. **Gym ownership / claim flow** — the blocker for every owner-gated feature.
3. **Deduplicate the two RM Elite gym records.**
