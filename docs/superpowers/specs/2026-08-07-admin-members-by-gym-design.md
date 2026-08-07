# Admin Members by Gym — Design

**Date:** 2026-08-07
**Status:** Approved, not yet implemented
**Depends on:** PR #60 (`fix(api): require an admin identity on /api/v1/admin/*`)

## Context

The admin portal's Members page (`apps/admin/src/app/features/members/`) is a
first-pass table. It renders every membership in one flat list and has four
concrete defects:

1. **Only the first 50 rows are reachable.** `members.ts` calls
   `listMembers(1, 50)` and the template has no pagination control. The page
   prints "N total memberships" while never fetching page 2. The API already
   accepts `page`; the UI never sends it.
2. **No per-gym grouping, no filter, no search.** One flat list of everything.
3. **Gym and user render as raw ObjectIds** (`{{ member.gymId }}`,
   `{{ member.userId }}`). Identifying a row means cross-referencing the Users
   and Gyms pages by hand.
4. **The portal is local-only.** Both environment files point at
   `http://localhost:3100` and no deploy workflow exists.

Beyond the defects, the page cannot answer the question it exists to answer —
*who trains where* — and it cannot show a user who belongs to no gym at all,
because `gymMemberships` has no row for such a user.

Current production scale (2026-08-06): **27 users, 846 gyms, 54 open mats.**

## Goals

- Members grouped by gym; users with no membership listed under **No Gym**.
- Gyms grouped by state, defaulting to the state derived from the browser's
  location.
- Names and emails instead of ObjectIds.
- Status badges for `active`, `hidden`, `inactive` — and `pending`, which the
  domain has and the original request did not mention.
- A one-click status switcher.
- Paging that is correct rather than silently truncating.

## Non-goals

- **Auth0 login and hosting for the portal.** Deployability is entangled with
  authentication — since PR #60 the admin API requires an admin identity, and
  the production Angular configuration ships an empty token, so a deployed
  portal would 401 on every page. Making it deployable means an Auth0 SPA app,
  callback URLs, a token interceptor, route guards, a hosting target and CORS
  origins. That is a different workstream with different risks and gets its own
  spec. This work continues to run locally against the API's
  `AUTH_BYPASS_SECRET`.
- **Changing how `pending` is set.** It stays unsettable through the manage
  endpoints; approving means setting `active`.
- **Editing anything other than membership status** (no role editing, no
  removal).

## Architecture

Three new read endpoints on the admin router, plus a reworked page. The write
path is unchanged: `PATCH /api/v1/admin/memberships/:gymId/:userId` already
does exactly what the switcher needs.

```
GET /api/v1/admin/members/tree                      -> states -> gyms -> counts only
GET /api/v1/admin/gyms/:gymId/members?page=&limit=  -> one gym's roster, paged
GET /api/v1/admin/members/no-gym?page=&limit=       -> users with zero memberships, paged
```

The split follows from one constraint: **grouping requires completeness, and
paging returns partial sets.** A flat paged list cannot be grouped correctly,
because a gym's members may straddle a page boundary and a group's count cannot
be known from a partial page.

So the tree carries **counts only**. It is the one response that must always be
complete for grouping and totals to be truthful, and counts stay small enough
that it can be. Rosters are the unbounded part, so they page.

### Repository work

Two new methods, both aggregations in Mongo rather than joins in memory —
otherwise `listAll()` would have to return every membership just so the client
could count them, which is the defect being fixed.

- `MembershipRepository.countsByGym(): Promise<GymMemberCounts[]>` — `$group` on
  `gymId` producing `{ gymId, memberCount, pendingCount }`. `memberCount`
  counts every membership regardless of status; `pendingCount` counts only
  `status: "pending"`.
- `UserRepository.listWithoutMemberships(skip, limit)` — `$lookup` against
  `gymMemberships` on `userId`, `$match` where the joined array is empty, with
  `$skip`/`$limit` and a matching count.

- `MembershipRepository.listByGymForAdmin(gymId, skip, limit)` — every
  membership for a gym, **all statuses**, paged, with a total.

The existing `listByGym(gymId, includeHidden)` **cannot be reused here.** It
excludes `pending` in *both* branches (`membership.repository.mts:42-48`) and
returns an unpaged array. Reusing it would contradict three parts of this
design at once: `pending` members would never appear despite being badged and
approved through this page, and `memberCount` (all statuses) would never equal
the rows actually loaded, so `Load more` would remain visible forever. The
admin view is a superset of the manager view and needs its own query.

Rows are enriched with user records via `UserRepository.findByIds`.

**Legacy rows have no `status` field.** `$ne`/`$nin` filters elsewhere in this
repository exist specifically so those rows stay visible, and the schema
default is `active`. Both the counts aggregation and the badge treat an absent
`status` as `active` — the page already does this
(`member.status ?? 'active'`).

### Facade

A new `AdminMembersFacade` composes `GymFacade` (gyms carry `state`) with the
counts aggregation. It owns the tree shape and the enrichment, keeping
`AdminFacade` from growing a fourth responsibility.

```ts
interface AdminMembersTree {
  states: StateGroup[];      // { state: string; gyms: GymSummary[] }
  noState: GymSummary[];     // gym.state is t.Optional — these are real
  noGym: { userCount: number };
}

interface GymSummary {
  id: string;
  name: string;
  city?: string;
  ownerId?: string;
  memberCount: number;
  pendingCount: number;
}
```

Three properties fall out of the data model:

- **`gym.state` is optional**, so a `(No State)` group is required, not
  defensive padding.
- **Only gyms with at least one membership appear.** All 846 gyms would be
  noise; this page is about members, not gyms.
- **`ownerId` rides along** so the switcher can pre-disable Hidden/Inactive on
  an owner's row rather than round-tripping to discover the server's guard rail
  (a gym's owner cannot be hidden or deactivated).

### Roster rows

The per-gym endpoint returns enriched rows so the client never joins:

```ts
interface AdminRosterRow {
  membershipId: string;
  gymId: string;
  userId: string;
  displayName: string;
  email: string;
  gymRole?: GymRole;
  status: MembershipStatus;      // pending | active | hidden | inactive
  visibleInRoster: boolean;      // member-controlled self-hide
  verifiedMember: boolean;
  joinedAt: string;
}
```

`No Gym` rows are users, not memberships: `{ userId, displayName, email,
createdAt }`. They carry no status, because there is no membership to carry
one.

## State ordering and the GPS default

On load: `navigator.geolocation.getCurrentPosition()` →
`GET /api/v1/geo/reverse?lat&lng` → `{ city, state }`. That endpoint already
exists and needs no change.

Ordering, top to bottom:

1. The detected state, rendered **expanded and first**.
2. Every other state, alphabetically, collapsed.
3. `(No State)` — gyms whose `state` is absent.
4. `No Gym` — users with no membership.

Nothing is ever hidden by the default; detection only changes order and which
group starts open. A manual state selector is always present and is the primary
control — GPS only chooses its initial value.

Geolocation is best-effort. Permission denied, unavailable, a timeout, or a
state string that matches no group all fall back to plain alphabetical order
with nothing pre-expanded. **The tree render does not block on the geolocation
callback**; it renders as soon as the tree arrives, and the detected state
expands if and when location resolves.

## Rows, badges, and the switcher

Each member row shows: display name, email, gym role, verified marker, status
badge, self-hidden marker, and the segmented control.

**Four badge values** — `active`, `hidden`, `inactive`, `pending`. `pending` is
styled distinctly and is read-only.

**Self-hidden is a separate marker, never merged into the badge.**
`visibleInRoster` is the *member's* choice; `hidden` is the *admin's*. An
`active` member who has self-hidden is a real and distinct state, and
collapsing the two would misrepresent who did what and make an empty public
roster unexplainable.

**The switcher is an inline segmented control** — `Active | Hidden | Inactive`
— with the current status selected. Current state and available actions become
one control instead of two columns.

- Clicking `Active` on a `pending` row **is** the approve action.
- `pending` is never a target segment: it is absent from
  `ManageableMembershipStatus` and the API returns 400 for it. (Validation
  errors normalise to **400, not 422** — `http/error-handler.mts:17`.)
- **Owner rows** render `Hidden` and `Inactive` disabled with a tooltip naming
  the reason, mirroring the server guard rail rather than discovering it.
- **`No Gym` rows have no badge and no switcher.** Name, email, join date only.

## Paging

Each gym group is collapsed by default and fetches its first page on expand.
`Load more` appends the next page; it appears only while
`loaded < memberCount`. `No Gym` behaves identically against its own endpoint.
Page size 50, matching the API's existing default and its 100 cap.

Because group counts come from the tree rather than from the loaded rows, a
partially-loaded gym still displays its true total — the specific failure in
the current page, which prints a total it cannot reach.

## Error handling

The switcher updates optimistically and rolls back on failure. That row's
segments disable while the request is in flight, keyed by membership id — the
existing `busyIds` pattern in `members.ts`, kept.

**Per-row errors render on the row**, not in the page-level banner the current
page uses. A failed toggle on one member should not read as the whole page
being broken. The existing `extractErrorMessage` helper already unwraps the
API's `{ error: { code, message } }` envelope and is reused unchanged.

A failed tree fetch is a page-level error with a retry — without the tree there
is no page. A failed roster fetch is scoped to its gym group, with a retry on
that group.

## Testing

Following existing patterns (`apps/api/test/*.test.mts` against a real MongoDB;
Angular component tests in `apps/admin`).

**API — repositories:**

- `countsByGym`: empty database; a gym with no memberships (absent, not zero-
  valued); a gym whose memberships are all `pending`; mixed statuses; a legacy
  row with no `status` field counted as `active`.
- `listByGymForAdmin`: returns `pending` rows (the reason `listByGym` could not
  be reused); its total equals the tree's `memberCount` for the same gym —
  asserted directly, since a mismatch is what leaves `Load more` stuck on
  screen.
- `listWithoutMemberships`: user with no memberships appears; user with one
  membership does not; user with memberships in two gyms does not; paging
  boundary returns a stable set.

**API — routes:** the `401`/`403`/`200` ladder on all three new endpoints. They
are new admin surface and PR #60's incident was precisely an admin route
shipping unguarded. Plus: tree groups by state, a stateless gym lands in
`noState`, and a gym with zero memberships is absent from the tree.

**Admin — component:**

- Tree ordering with a detected state (detected first, rest alphabetical).
- Geolocation denied → alphabetical, nothing pre-expanded, no error surfaced.
- All four badges render; self-hidden marker independent of status.
- Switcher disabled on an owner row.
- Optimistic update rolls back and shows a row-level error on a failed PATCH.
- `Load more` appends rather than replaces, and disappears at the total.

## Assumptions and known limits

- **The tree is unpaged.** It stays complete while gyms-with-members is in the
  hundreds. Past that the tree itself needs paging — a real limit, recorded
  rather than pre-built, since today the number is a handful out of 846 gyms.
- **`pending` remains unsettable**, so approve-by-clicking-`Active` is the only
  approval path.
- **The portal remains local-only**, authenticated by the dev bypass token. It
  cannot be deployed until the Auth0 spec is done.
- **Membership rows referencing a deleted gym or user** are treated as data
  errors: the gym falls into `(No State)` if unresolvable, and a row whose user
  cannot be resolved renders its id with a warning marker rather than being
  dropped silently.
