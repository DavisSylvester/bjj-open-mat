# Feature Log

A running record of everything built since the last store release, kept so the
App Store and Play Store release notes can be assembled without archaeology
through git history.

**Last released:** 1.2.0 (+20) — App Store and Play Store
**Current unreleased work:** see below

## How to use this

- Add an entry per feature as it merges, newest first, under **Unreleased**.
- Each entry records **Added**, **Enhanced**, **Fixed**, and **Internal**.
  *Internal* is work with no user-visible effect — it stays out of store notes
  but matters for the team.
- At release time: bump the version, move everything under Unreleased into a
  new version heading, and draft the store copy from the Added/Enhanced/Fixed
  lines only.
- A skeleton for new entries lives at the bottom of this file.

---

## Unreleased — since 1.2.0

### Admin Members by Gym

> **Admin-only internal tooling — skip this entry when drafting App Store or
> Play Store release notes.** Nothing below is reachable by a player; it is
> the internal admin portal only.

Merged 2026-08-07 · PR _pending_ · 13 commits
Spec: `docs/superpowers/specs/2026-08-07-admin-members-by-gym-design.md`

An admin can now find and manage any member by drilling from state down to
gym down to person, instead of scrolling a flat table of raw database ids.

#### Added

- **Members grouped by gym and by state.** The Members page is now a
  state → gym → member tree instead of a flat 50-row table.
- **A "No Gym" group** listing users who belong to no gym at all, which the
  old flat table had no way to surface.
- **Detected-state-first ordering.** The tree opens with the admin's own
  state (from browser location) first, so the common case — checking your
  own region — needs no scrolling.
- **Per-gym paging that can actually reach every member,** replacing a page
  that silently stopped at 50 memberships total.

#### Enhanced

- Roster rows show names and emails instead of raw Mongo `ObjectId`s.
- **Four status badges** — active, hidden, inactive, pending — plus a
  separate self-hidden marker for members who hid their own membership,
  distinct from an admin-hidden one.
- **A one-click segmented status switcher** on each row; clicking Active on
  a pending member approves them in one action instead of a separate
  approve step.

#### Fixed

- The old Members page fetched only the first 50 memberships with no
  pagination control, so it displayed a total member count it could never
  actually reach.

#### Internal

- Three new admin endpoints backing the tree, the per-gym roster, and the
  no-gym list.
- New Mongo aggregations: `countsByGym` for per-gym member counts and
  `listWithoutMemberships` for gymless users.
- **`/api/v1/admin/*` now requires an authenticated admin identity.** It was
  previously reachable with no token at all.

#### Known follow-ups (not shipped)

- The admin portal is still local-only; it cannot be deployed until it has
  real Auth0 login, because the production build ships no token.
- `AdminApiService.listMembers` is now unused and should be removed.
- The "Load more" control has no in-flight guard, so a double-click can
  append the same page twice.

---

### Gym Search

Merged 2026-08-06 · PR [#58](https://github.com/DavisSylvester/bjj-open-mat/pull/58) · 18 commits
Spec: `docs/superpowers/specs/2026-08-06-gym-search-design.md`

Students can now search for gyms near them, not just open mats. Previously a
gym was reachable only as a side effect of an open-mat session, or through a
fixed list on Discover with no search and no filters.

#### Added

- **Gym search on the Find screen.** An `Open Mats | Gyms` toggle switches the
  existing Find screen between the two. Search by GPS or ZIP code, filter by
  gym name or city, and adjust the radius with the same controls open-mat
  search already uses.
- **Automatic radius expansion.** When nothing is found nearby, the search
  widens on its own — 25 → 50 → 100 miles — and tells the user it did, rather
  than showing an empty screen or letting the radius control misreport what is
  on screen.
- **Paged results.** Results load a page at a time with a *Load more* control,
  so a search in a dense metro no longer tries to render every gym at once.
- **Full gym details.** The gym detail screen now shows the complete street
  address (tap for directions), phone number (tap to call), website, and
  amenities. All four were already being returned by the API and silently
  discarded.

#### Enhanced

- Gym results show distance in miles and are ordered nearest-first.
- ZIP entry resolves to a place name (e.g. `75495` → "Van Alstyne, TX"), so the
  user can confirm the app understood the location they meant.
- Open-mat-only controls (gi/no-gi, free, When, date chips) hide in Gyms mode
  instead of sitting there inert, and the result count reads "N Gyms".

#### Fixed

- **Security — gym join codes were publicly exposed.** The nearby-gyms endpoint
  returned each gym's `joinCode` (its roster-join secret) and `ownerId` to
  unauthenticated callers. Both are now stripped from search results. This
  predates the feature; it was fixed here because this work makes that endpoint
  a much more prominent public surface.

#### Internal

- `GET /api/v1/gyms/nearby` gained `zip`, `q`, `page`, and `limit`; ZIP resolves
  server-side. Search text is regex-escaped, so a gym named `Alliance (North)`
  is findable and a crafted query is not a denial-of-service vector.
- **Ranking seam for future paid placement.** Gyms carry a `rankBoost` field
  that the result ordering already reads, and responses carry a derived
  `sponsored` flag. Nothing writes `rankBoost` today and ordering is pure
  distance, so behaviour is unchanged — but selling placement later is a write
  path plus a badge, not a schema change and a re-sort.
- **First CI test gate in the repo.** `.github/workflows/ci.yml` runs an
  end-to-end test on every pull request and every push to `main`, and the API
  deploy now declares `needs: [e2e]`, so a failing test blocks the deploy. The
  gate covers the acceptance scenario: search ZIP 75495 at 25 miles, find
  nothing, expand to 50 miles, find the gym — driven against a real MongoDB
  over HTTP.
- Mobile paging uses Riverpod's modern `Notifier` API, matching the app's four
  existing precedents, with a request-generation guard so a slow response from
  an abandoned search cannot overwrite newer results.

#### Behaviour change to watch at release

Discover's "Gyms near you" section previously listed **every** gym within 50
miles; it now lists up to 50, because the underlying endpoint became paged. In
a dense metro that is a visible reduction (a Dallas-area query returns 233).
Decide before release whether that section should page, raise its cap, or stay
as-is.

#### Known follow-ups (not shipped)

- `GET /api/v1/gyms/:id` still returns `joinCode` and `ownerId` without
  authentication. No endpoint currently accepts a join code, so this is a
  leaked invite token rather than a way in — but gym IDs are now trivially
  enumerable, so it should be closed.
- Branch protection on `main` must list `e2e` as a required status check for a
  failing test to block a **merge**. The **deploy** is already blocked.
- Search result ordering has no tiebreaker, so two gyms at an identical
  distance could in principle repeat or be skipped across a page boundary.
- A gym phone number entered in a normal format like `(972) 555-0100` may fail
  to open the dialer, and the failure is silent.
- With location permission denied and no ZIP entered, Gyms mode reads "No gyms
  found" when in fact no search has run yet.

---

## Entry template

```markdown
### <Feature name>

Merged <YYYY-MM-DD> · PR [#N](url) · <n> commits

<One or two sentences: what a user can now do that they could not before.>

#### Added
- <User-visible new capability.>

#### Enhanced
- <Existing behaviour made better.>

#### Fixed
- <Bug or defect resolved. Note if it predates the feature.>

#### Internal
- <No user-visible effect: API, schema, CI, refactor.>

#### Behaviour change to watch at release
- <Anything existing users will notice as different. Omit if none.>

#### Known follow-ups (not shipped)
- <Deliberately deferred. Omit if none.>
```
