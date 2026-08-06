# Gym Search — Design

**Date:** 2026-08-06
**Status:** Approved

## Problem

The app is built around open-mat sessions. A student who wants to find a *gym*
— because they're travelling, relocating, or shopping for a school — has no
first-class way to do it. Gyms are reachable only as a side effect of an open
mat, or via the "Gyms near you" section on Discover, which is a fixed 80 km
list with no search, no filters, and no paging.

This feature makes gym search a first-class surface and completes the gym
detail view. It also lays the ranking seam for a later paid-placement and
referral product, without building any of that product now.

## What already exists

Not starting from zero. Today:

- `GET /api/v1/gyms/nearby?lat&lng&radiusKm` → gyms with `distanceKm`
  (`apps/api/src/routes/gym.routes.mts`, `gym.facade.mts:76`).
  Unbounded, no text search, no paging, distance-sorted by `$geoNear`.
- `GymRepository.findNearby` — a single `$geoNear` stage over a `2dsphere`
  index (`apps/api/src/repositories/gym.repository.mts:85`).
- `Geocoder.lookupZip(zip) → GeoLocation` (`apps/api/src/services/geocoder.mts:12`).
- Mobile: `nearbyGymsProvider`, `NearbyGymCard`, `gym_detail_screen.dart`,
  and a Discover section rendering gyms within 80 km.
- `/search` — open-mats only, with radius chips, ZIP entry, and a shared
  location controller that both modes can reuse.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Placement | Toggle inside `/search` | Reuses radius/ZIP/location chrome; no nav churn |
| Filters | Text search + radius/ZIP | Verified-only and has-open-mats deferred as YAGNI |
| Monetization | Ranking seam only | Sort reads a field nothing writes yet; no product surface |
| Paging | page/limit + auto-widening | Handles dense metros and sparse rural areas |
| API shape | Extend `/gyms/nearby` | One geo pipeline; a second endpoint would be ~90% duplicate and drift |
| E2E | API-level in CI, Flutter locally | Hosted runners can't run an Android emulator reliably |

---

## API

### Contract

`NearbyQuery` (`packages/contract/src/schemas/requests/gym-requests.mts:53`):

```ts
export const NearbyQuery = t.Object(
  {
    lat: t.Optional(t.Number()),
    lng: t.Optional(t.Number()),
    zip: t.Optional(t.String({ pattern: '^\\d{5}$' })),
    q: t.Optional(t.String({ maxLength: 100 })),
    radiusKm: t.Optional(t.Number({ minimum: 1, maximum: 500, default: 25 })),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 50, default: 20 })),
  },
  { $id: 'NearbyQuery' },
);
```

`lat`/`lng` become optional because `zip` is an alternative origin. Exactly one
origin must resolve:

- Neither coords nor `zip` → `400 bad_request`, "lat/lng or zip is required".
- `zip` present but unresolvable → `400 bad_request`, "Unknown ZIP code".
- Both present → coords win; `zip` is ignored.

ZIP resolves server-side via the existing `Geocoder`, matching how open-mat
search already behaves. The client sends `zip`, never coordinates it derived
itself.

`Gym` (`packages/contract/src/schemas/gym.mts`) gains:

```ts
rankBoost: t.Optional(t.Integer({ default: 0 })),
sponsored: t.Optional(t.Boolean({ default: false })),
```

Nothing writes `rankBoost` in this feature. `sponsored` is derived at read time
as `rankBoost > 0` and is never persisted. Together they mean paid placement
later is a write path plus a badge — not a contract change, a re-sort, and a
mobile model migration.

### Response

The route keeps the existing `list()` envelope, so the shape is unchanged; it
just stops reporting a fake `total`. `meta` gains one field:

```jsonc
{
  "data": [ /* Gym[] */ ],
  "meta": { "page": 1, "limit": 20, "total": 37, "effectiveRadiusKm": 80 }
}
```

`effectiveRadiusKm` is the radius that actually produced the results. When it
differs from the requested `radiusKm`, the search auto-widened (below) and the
client must say so rather than let the radius chip misreport.

### Repository

`findNearby` → `searchNearby(opts)`, returning `{ items, total }`.
`$geoNear` must remain the first stage; everything else composes after it:

```
$geoNear   { near, distanceField: 'distanceMeters', maxDistance, spherical }
$match     q → { $or: [ { name: /q/i }, { city: /q/i } ] }     // omitted when q absent
$sort      { rankBoost: -1, distanceMeters: 1 }
$facet     { total: [ { $count: 'n' } ], items: [ { $skip }, { $limit } ] }
```

Notes:

- **`q` must be regex-escaped** before being embedded in a `$regex`. Raw user
  input compiled as a pattern is both a correctness bug (a gym named "Alliance
  (North)" is unsearchable) and a ReDoS vector. Escape all metacharacters and
  anchor nothing — substring match is the intent.
- `rankBoost` is absent on every existing document, so the pipeline normalizes
  it before sorting: `$addFields: { rankBoost: { $ifNull: ['$rankBoost', 0] } }`
  between `$match` and `$sort`. Without it, documents missing the field sort as
  null, and ties among *all* unboosted gyms (which is every gym today) would
  order by BSON null-vs-integer rules rather than by distance. With it, every
  gym has an explicit 0 and today's ordering is pure distance — exactly the
  current behaviour — while a future boosted gym rises above it.
- The `$sort` after `$geoNear` is an in-memory sort over the radius result set,
  not an index scan. At current gym volumes (low thousands nationally, tens per
  radius) this is not a concern. If it becomes one, the fix is a compound index
  and a redesign of the ranking step — deliberately out of scope.
- **Projection:** `joinCode` and `ownerId` are excluded from the search
  projection. `joinCode` is a gym's roster-join secret and is currently returned
  to unauthenticated callers by `/gyms/nearby`. This feature makes that endpoint
  a far more prominent public surface, so the leak is fixed as part of it.
  `getById` is unchanged — only the search projection narrows.

`findNearby` has one caller (`gym.facade.nearby`) and one test
(`gym.repository.test.mts`); it is replaced, not kept alongside.

### Auto-widening

Lives in the facade, not the repository — it is a product policy, not a query.

- Applies **only when `page === 1` and the result set is empty**. A partial
  first page is a real answer and is not widened.
- Ladder: double the requested radius, at most twice, capped at 161 km (100 mi).
  A 40 km (25 mi) request therefore tries 40 → 80 → 161.
- Stops at the first radius that yields ≥ 1 result.
- The radius that produced results is returned as `effectiveRadiusKm`.
- Pages 2+ never widen. The client passes the `effectiveRadiusKm` it received
  back as `radiusKm` on subsequent pages, so paging stays consistent with the
  page-1 result set.

If no radius in the ladder yields results, the response is empty with
`effectiveRadiusKm` equal to the last radius tried.

---

## Mobile

### Search screen

`/search` gains a segmented `Open Mats | Gyms` control at the top of the
existing glass header. Mode is a single field on `_SearchScreenState`. The
radius chips, ZIP field, and `locationController` are shared unchanged. The
gi/nogi/free/when chips hide in Gyms mode — they are open-mat concepts and
have no meaning for a gym.

Switching modes preserves the shared geo inputs (radius, ZIP, GPS) and clears
the result list. The text field is shared; its hint changes per mode.

### New files

```
features/gyms/data/gym_search_query.dart       // q, lat, lng, zip, radiusKm, page, limit
features/gyms/data/gym_search_repository.dart  // GET /api/v1/gyms/nearby → GymSearchPage
features/gyms/models/gym_search_page.dart      // items, total, effectiveRadiusKm
features/gyms/data/gym_search_controller.dart  // StateNotifier: accumulated items, hasMore
```

Paging needs a `StateNotifier`, not the `FutureProvider.family` style used
elsewhere — a `FutureProvider` replaces its value on each fetch and cannot
accumulate pages. State is `{ items, total, effectiveRadiusKm, page, loading,
error }`; `hasMore` is `items.length < total`. A new query resets to page 1;
scrolling near the end requests the next page and appends.

Results reuse `NearbyGymCard` unchanged. When `effectiveRadiusKm` exceeds the
requested radius, a notice renders above the list: "No gyms within 25 mi —
showing results within 50 mi." Empty results reuse the existing `EmptyState`
widget with gym copy.

### Gym detail

`gym_detail_screen.dart` currently drops `phone`, `website`, and `amenities` on
the floor despite all three arriving from the API. Add below the hero:

- **Address row** — full street address, taps through to directions via the
  existing `directions.dart`. Today only city/state shows, in the hero.
- **Phone row** — `tel:` launch. Hidden when null.
- **Website row** — reuses `website_links.dart`. Hidden when null.
- **Amenities** — chips under About. Hidden when the array is empty.

The `Gym` model (`features/gyms/models/gym.dart`) parses `sponsored` and
`rankBoost` so a sponsored badge is a pure rendering change later.

---

## Testing

### Unit

- Repository: `q` filtering, regex escaping of metacharacters, `rankBoost`
  ordering ahead of distance, `$facet` total vs. page length, `joinCode` and
  `ownerId` absent from results.
- Facade: widening ladder (widens on empty page 1, does not widen on a partial
  page, does not widen on page 2, stops at the cap), `sponsored` derivation.
- Route: 400 when no origin, 400 on an unresolvable ZIP, coords winning over
  ZIP.

### API E2E — CI gate

`apps/api/test/gym-search.e2e.test.mts`. Boots the real Elysia app against a
real MongoDB and drives it over HTTP.

The required scenario, verbatim from the requirement — search 75495, expand to
50 miles:

1. Seed a gym in the Dallas metro, roughly 65 km from Van Alstyne, TX (75495 →
   33.4292, -96.5486 — already the mock GPS fix in `scripts/e2e-search.mjs`).
2. `GET /api/v1/gyms/nearby?zip=75495&radiusKm=40` — 40 km (25 mi) does not
   reach the seeded gym.
3. Assert: `200`; `meta.effectiveRadiusKm === 80`; the seeded gym is in `data`;
   `data[0].distanceKm` is between 40 and 80; `joinCode` is absent.

A second case asserts the negative control — a gym seeded 200 km away is *not*
returned even after the ladder exhausts, and `effectiveRadiusKm` is 161.

Seed data is inserted and dropped by the test into its own database, following
the pattern in `gym.repository.test.mts`.

### CI

There is **no test-running CI today**. `api-deploy.yml` triggers on push to
`main` and goes straight to `cdk deploy`. This adds `.github/workflows/ci.yml`:

- Triggers on `pull_request` and on `push` to `main`.
- `mongo:7` service container; `MONGODB_URI=mongodb://localhost:27017`.
- Steps: `oven-sh/setup-bun`, `bun install`, then
  `cd apps/api && bun test test/gym-search.e2e.test.mts`.
- A failure fails the job.

`api-deploy.yml` gains `needs: [ci]` so a red test blocks the deploy. Without
that link the gate is decorative — the deploy workflow would run in parallel and
ship anyway.

**Scope of the gate is deliberate.** The existing suite has 5 known-failing
tests in `device.routes.test.mts` (5-second timeouts, verified pre-existing and
unrelated to this work). Gating on the full suite would red the build on day one
for someone else's bug. The workflow runs the new E2E only; widening it to
`bun test` is a one-line change once `device.routes` is fixed. This is recorded
here so the narrow scope reads as a decision, not an oversight.

### Flutter integration test — local only

`apps/mobile/integration_test/gym_search_test.dart`, driven by
`scripts/e2e-gym-search.mjs` (mirroring `e2e-search.mjs`: mock GPS to
Van Alstyne, `flutter drive`, screen recording), wired as `mobile:e2e:gyms` in
the root `package.json`.

**Not in CI** — the existing mobile e2e scripts require an Android emulator via
`adb`, which is slow and flaky on hosted runners. Run locally before a release,
like the other `mobile:e2e:*` scripts.

## Out of scope

Deliberately not built:

- Promotion tiers, pricing, billing, an admin screen to set `rankBoost`, or the
  referral-bonus flow. Only the seam.
- A "Sponsored" badge in the results UI. The data supports it; nothing renders
  it until there is something to render.
- Verified-only and has-open-mats filters.
- Map view of results.
- Fixing `device.routes.test.mts`.
- Widening the CI gate to the full API suite.

## Verification

Per `[[api-verification-baselines]]`: `bun test` does not type-check. Before
calling this done, run `bunx tsc --noEmit` scoped to source
(`cd apps/api && bunx tsc --noEmit 2>&1 | grep -cE "^src/"` must print 0),
and lint only the changed files — the repo has ~250 pre-existing lint errors.
