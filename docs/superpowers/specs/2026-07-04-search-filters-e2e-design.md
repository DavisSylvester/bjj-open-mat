# Search & Filters (When / Within / GPS / Zip) + E2E — Design

**Date:** 2026-07-04
**Status:** Approved (design); pending implementation plan

## Goal

Make open-mat **search** work end-to-end. Today the SearchScreen and Discover/home
screens run entirely on hardcoded stub data with no API calls, and the `GET /open-mats`
list endpoint has no text, date, distance, or geo parameters — so the **"When"** (date)
and **"Within"** (distance) filters are dead UI. This work wires search from contract →
API → mobile so a newly-created gym is discoverable and filterable by text, gi-type, fee,
date range, and distance from GPS or a zip code. Ships with an integration (e2e) test that
drives the real app UI and captures screenshots + video.

## Decisions (from brainstorming)

- **Geocoding:** offline `zipcodes` npm package for `zip → {lat,lng}` **plus** explicit
  optional coordinates on gym creation (no external API, works in CI).
- **"When" semantics:** date range → weekday match. A recurring session matches if its
  `dayOfWeek` falls within `[startDate,endDate]`; a one-off matches if its `specificDate`
  is in range.
- **E2E:** drive the real app UI (create flow + search), like the existing
  `create_open_mat_session_test.dart`.
- **Scope:** wire **both** SearchScreen and Discover/home to live data.
- **Artifacts:** e2e captures screenshots (Flutter integration driver) and a screen
  recording (adb).

## Data model & contract (`packages/contract/src`)

### `schemas/requests/open-mat-requests.mts` — extend `OpenMatListQuery`
Add (all optional; existing fields unchanged):
- `q?: string` — free-text; matches `title` + `gymName`.
- `free?: boolean` — sessions with `feeCents` 0 or absent.
- `startDate?: string`, `endDate?: string` — ISO `YYYY-MM-DD`; the "When" range.
- `lat?: number`, `lng?: number`, `radiusKm?: number` (min 1, max 500) — the "Within" range.
- `zip?: string` — alternative to `lat`/`lng`; the server geocodes it to a point.

### Gym creation coordinates
Extend `CreateGymRequest` and the inline `newGym` object in `CreateOpenMatRequest` with
optional `latitude?: number`, `longitude?: number`, `postalCode?: string`. If coords are
absent but `postalCode` is present, the API geocodes it at creation time.

## API (`apps/api/src`)

### Geocoder service — `services/geocoder.mts` (new)
Thin, injectable wrapper over the `zipcodes` package:
```
interface Geocoder { lookupZip(zip: string): { lat: number; lng: number } | null }
```
Registered in `container.mts`. Pure/deterministic; unit-testable. Returns `null` for
unknown zips (callers treat null as "no location constraint" / no coords).

### Gym creation — `facades/gym.facade.mts`
On create: if `latitude`/`longitude` provided, use them; else if `postalCode` provided,
`geocoder.lookupZip(postalCode)` → coordinates; else no location (unchanged behavior). This
is what gives the new 75495 gym a point so distance/zip search can find it.

### List — `GET /open-mats` (`routes/open-mat.routes.mts` + facade + repository)
`OpenMatFacade.list` / `OpenMatRepository.list` gain the new filters, composing in one
Mongo query/aggregation:
- **Text (`q`):** case-insensitive regex on `title` and denormalized `gymName`.
- **Free (`free`):** `feeCents` in `{0, null, absent}`.
- **When (`startDate`/`endDate`):** compute the set of weekdays covered by the range
  (capped at 7). Match `{ $or: [ { isRecurring: true, dayOfWeek: { $in: weekdays } },
  { specificDate: { $gte: startDate, $lte: endDate } } ] }`.
- **Within (`lat`/`lng`/`radiusKm`, or `zip`):** if `zip` present and no `lat`/`lng`,
  geocode it. When a point is available, use `$geoNear` (as `findNearby` already does:
  2dsphere, `maxDistance = radiusKm*1000`, `spherical`) and return `distanceKm`, then apply
  the other filters as the `query`/subsequent `$match`. When no point, behave as today.

Existing `giType`, `skillLevel`, `dayOfWeek`, `mine`, `verified`, `status`, paging remain.

## Mobile (`apps/mobile/lib`)

### Search repository — `features/search/data/search_repository.dart` (new)
`Future<List<OpenMat>> search(SearchQuery q)` → `GET /api/v1/open-mats` with all params
(omit nulls). `SearchQuery` is a small value object holding text, giType, free,
startDate/endDate, lat/lng/radiusKm, zip. Riverpod provider + a `searchResultsProvider`
(FutureProvider.family or an AsyncNotifier) keyed by the current query.

### SearchScreen rewrite — `features/search/screens/search_screen.dart`
Provider-backed, rendering **real** results with loading/empty/error states:
- **Text:** debounced field → `q`.
- **Gi/No-Gi/Both/Free chips:** → `giType` / `free` (existing UI, now wired).
- **"When":** real state + tap handlers for **This week / This weekend / This month /
  pick a date** → computes `startDate`/`endDate` (client-side date math). Selected option
  is highlighted (replaces the hardcoded "This Weekend" text).
- **"Within":** existing slider → `radiusKm`, plus a **location source**: a "use my
  location" toggle (existing `core/location/LocationService`) and a **zip input field**.
  GPS → `lat`/`lng`; zip → `zip`.
- Result cards navigate to the real detail (`/open-mat/:id`).

### Discover/home — `features/discover/screens/discover_screen.dart` + provider
Replace `_stubSessions` with live data: nearby-by-GPS when a location is available (fallback
to a plain recent list). Cards navigate to detail by real id. The existing
`discover_provider.dart` is fixed to pass the location/query instead of ignoring it.

## E2E test (`apps/mobile/integration_test/search_filter_test.dart`)

Drives the real UI (dev-bypass login), reusing the `pumpUntilFound` helper and dart-defines
from `create_open_mat_session_test.dart` (`10.0.2.2:3100`). Flow:
1. Login.
2. Create a **new gym not in seed** (e.g. "North Texas BJJ", address in **75495**,
   `postalCode 75495`) via the "+" create flow.
3. Create a **Saturday 11:00** session, **Gi**; then a second **Saturday 11:00** session,
   **No-Gi** (same gym).
4. Go to **Search**; verify both sessions appear.
5. **GPS search:** emulator location set near 75495 (`adb emu geo fix <lng> <lat>` in the
   run script) + "use my location" → both appear within radius.
6. **Zip search:** enter **75495** → both appear.
7. **When = This weekend** (Saturday) → both appear. Then, via **pick a date**, select a
   single non-Saturday weekday (e.g. the coming Wednesday) → both are excluded (negative
   assertion; a recurring Saturday session has no occurrence in a Wednesday-only range).
8. **Within:** small radius from a far point → excluded; large radius → included.
9. **Gi / No-Gi / Free** filters → each narrows correctly.

### Artifacts (screenshots + video)
- **Screenshots:** add `apps/mobile/test_driver/integration_test.dart` using
  `integrationDriver(onScreenshot: ...)` that writes PNGs to `apps/mobile/build/e2e/`. The
  test calls `binding.takeScreenshot('<step>')` after each milestone (gym created, sessions
  created, results, gps, zip, when, within, each filter). Requires
  `convertFlutterSurfaceToImage()` on Android; run via `flutter drive`.
- **Video:** the `mobile:e2e:search` script wraps the run with
  `adb shell screenrecord /sdcard/e2e.mp4` (backgrounded, `--time-limit 180`, chunked if the
  run is longer), then `adb pull` to `apps/mobile/build/e2e/e2e.mp4`.
- `apps/mobile/build/` is already git-ignored, so artifacts are not committed.

### Run script (root `package.json`)
```
"mobile:e2e:search": "<wrapper that: adb emu geo fix; start screenrecord; flutter drive --driver=test_driver/integration_test.dart --target=integration_test/search_filter_test.dart -d emulator-5554 --dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<secret> --dart-define=API_BASE_URL=http://10.0.2.2:3100; stop+pull screenrecord>"
```
The bypass token must equal the API's `AUTH_BYPASS_SECRET`.

## Testing (TDD)

Unit tests written first, then implementation, then the e2e ties it together:
- **Contract:** `OpenMatListQuery` accepts/validates the new fields; gym-create coords.
- **API:** geocoder `lookupZip` (known zip → coords, unknown → null); list filters — text
  regex, `free`, When (date-range → weekday set incl. week/weekend/month boundaries),
  Within (`$geoNear` include/exclude by radius); gym creation geocodes `postalCode`.
- **Mobile:** search repository builds correct query params (omits nulls; GPS vs zip);
  SearchScreen widget test for "When" option state + zip field wiring (overridden repo).

## Out of scope (YAGNI)

- Full street-address geocoding (zip-centroid accuracy is sufficient).
- Autocomplete / fuzzy text ranking (simple substring/regex).
- Saved searches, map view, clustering.
- Persisting the emulator's mocked GPS beyond the test run.

## Affected files

- **Contract:** `schemas/requests/open-mat-requests.mts`, `schemas/requests/gym-requests.mts`.
- **API:** `services/geocoder.mts` (new), `container.mts`, `facades/gym.facade.mts`,
  `facades/open-mat.facade.mts`, `repositories/open-mat.repository.mts`,
  `routes/open-mat.routes.mts`, `openapi.mts`, `package.json` (add `zipcodes`); tests under `apps/api/test`.
- **Mobile:** `features/search/data/search_repository.dart` (new),
  `features/search/screens/search_screen.dart`, `features/discover/screens/discover_screen.dart`,
  `features/discover/providers/discover_provider.dart`, `test_driver/integration_test.dart`
  (new), `integration_test/search_filter_test.dart` (new); unit tests under `apps/mobile/test`.
- **Root:** `package.json` (`mobile:e2e:search`).
</content>
