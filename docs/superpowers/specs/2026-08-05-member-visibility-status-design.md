# Member Visibility Status — Design

**Date:** 2026-08-05
**Status:** Approved

## Problem

A gym's public roster lists every active member. Owners and admins have no way to take
someone off that list — a member who stopped training, a member who asked to be removed,
a duplicate or bad-faith account. The only existing hide mechanism, `visibleInRoster`,
is self-service: the member toggles it in the mobile app, and
`UpdateMembershipRequest` accepts only `verifiedMember` and `gymRole`, so an owner
cannot set it.

Two distinct needs are tangled together in the request:

- **Hidden** — still a member of the gym, just not listed.
- **Inactive** — no longer training here; should lose member access, not merely a listing.

## Decisions

| Decision | Choice |
|---|---|
| Does non-active status revoke privileges? | `inactive` revokes; `hidden` does not |
| Owner hide vs. member self-hide | Both kept and independent — either one hides |
| Manager roster presentation | Inline, badged and dimmed, sorted after active |
| Storage | One widened enum plus a shared privilege helper |

### What "hidden keeps privileges" means

A hidden member's *own* access is intact: they can post in the gym forum, open a DM,
and see member-only gym content. It does **not** mean other members can still pick them
out of a list. A hidden member is absent from every member-facing list, including the
DM recipient picker and class assignment. This matches how the existing self-hide
already behaves.

An inactive member loses their own access as well.

## Data model — `packages/contract`

`MembershipStatus` (`src/enums/membership-status.mts`) widens:

```
pending | active | hidden | inactive
```

New shared helper, exported from the contract:

```ts
hasMemberPrivileges(status: MembershipStatus): boolean
  // true for 'active' and 'hidden'
```

This replaces the bare `status === 'active'` comparisons in
`apps/api/src/facades/gym-authz.mts` (`assertCanManageGym`, `assertActiveMember`) and
the membership facade.

`GymMembership` (`src/schemas/gym-membership.mts`) gains:

- `statusUpdatedAt?: string`
- `statusUpdatedBy?: string` — userId of the owner/coach/admin who set it

These mirror the `Gym.verifiedAt` / `User.verifiedAt` precedent and answer "who hid this
person and when" without introducing an audit collection.

`RosterMember` (`src/schemas/roster-member.mts`) gains `status`. Public responses only
ever contain `active`, so no state leaks to anonymous callers.

`UpdateMembershipRequest` (`src/schemas/requests/membership-requests.mts`) gains
`status`. `pending` is not accepted — it stays a join-flow state.

`visibleInRoster` is unchanged in meaning and remains member-owned.

## Visibility rules

Enforced in exactly one place: `membership.repository.listByGym(gymId, includeHidden)`.

| Caller | Filter |
|---|---|
| Public / ordinary member | `status === 'active' && visibleInRoster !== false` |
| Manager (`includeHidden`) | `status !== 'pending'`, all states returned with `status` |

The `visibleInRoster !== false` form is retained so legacy docs missing the field stay
visible. Either flag hides a member; neither overrides the other, so a member cannot
un-hide themselves out of an owner's decision and an owner cannot force a private member
back into public view.

No backfill migration is required: existing documents already carry `status: 'active'`,
and the enum only widens.

## API — `apps/api`

**`PATCH /api/v1/gyms/:id/members/:userId`** — accepts `status` alongside the existing
`verifiedMember` and `gymRole`. No new routes. Authorization already flows through
`assertCanManageGym`, which admits gym owner, coach, and admin. On a status change the
facade stamps `statusUpdatedAt` and `statusUpdatedBy`.

Rationale for extending `PATCH` rather than adding `hide`/`unhide` route pairs as open
mats do: status here is a four-value enum, not a boolean.

**`GET /api/v1/gyms/:id/members?includeHidden=true`** — explicit opt-in. Returns 403
unless the caller can manage the gym. Without the parameter the response is
byte-identical to today's.

`membership.facade.roster()` currently hardcodes `listByGym(gymId, false)`; it takes an
`includeHidden` argument and the manager check lives in the facade alongside the other
authorization rules.

The route is currently unauthenticated but sits inside the `authPlugin` scoped group, so
`identity` is already resolved (null for anonymous callers) and the manager check needs
no new middleware.

Rationale for an explicit parameter rather than inferring from the caller's role:
inference would silently change the roster payload for every manager, and on mobile that
same roster feeds the DM recipient picker, class assignment, and permission checks.

**`PATCH /api/v1/admin/memberships/:gymId/:userId`** — the same capability on the admin
router.

OpenAPI (`apps/api/src/openapi.mts`) updated for the widened enum, the new request
field, and the `includeHidden` parameter.

### Guard rails

- A caller cannot change their own status (mirrors the self-promotion block in `promote`).
- A membership whose `userId` equals the gym's `ownerId` cannot be set to `hidden` or
  `inactive`. Transfer ownership first.
- `pending` is rejected as an input value.

## Mobile — `apps/mobile`

`rosterProvider` is unchanged — it remains the active-and-visible list. All existing
consumers keep their current behavior with no edits: `gym_permissions`,
`join_gym_button`, `new_message_screen` (DM picker), `class_edit_screen`,
`class_occurrence_screen`, `class_schedule_screen`, `forum_question_screen`,
`conversation_screen`, `gym_reports_screen`.

New `manageRosterProvider(gymId)` requests `includeHidden=true`. Only `roster_screen`
consumes it, and only when `canManage` is already true.

`roster_screen`: hidden and inactive tiles render at reduced opacity with a `Hidden` or
`Inactive` badge and sort after the active members. The member manage sheet gains a
status control.

`membership_repository.manageMember()` accepts `status`.

`gym_permissions.dart` adopts the shared privilege rule so an inactive member correctly
loses `isMember`.

## Admin portal — `apps/admin`

Members page (`src/app/features/members/`):

- The existing `status` badge column extends to color `hidden` and `inactive`.
- New `Visible in roster` column — `visibleInRoster` is not rendered today.
- New row action to set status.
- New `AdminApiService.updateMembership(gymId, userId, patch)`.

Out of scope, noted: the page still displays raw `gymId` / `userId` strings rather than
resolved names.

## Testing

`bun test`:

- Repository filter matrix — each of the four statuses × `visibleInRoster` true/false/absent
  × `includeHidden` true/false.
- `hasMemberPrivileges` across all four states.
- Guard rails: self-status change rejected, gym owner cannot be hidden or deactivated,
  `pending` rejected as input.
- 403 on `includeHidden=true` for a non-manager; unchanged payload for an anonymous caller.
- Facade stamps `statusUpdatedAt` / `statusUpdatedBy`.

Contract tests for the widened enum and the extended `UpdateMembershipRequest`.

Playwright (`apps/admin`): status-change round-trip on the Members page. Seed fixtures
(`e2e/seed/fixtures.ts`) extended with one hidden and one inactive membership.
