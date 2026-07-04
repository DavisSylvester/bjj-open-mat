# Open-Mat Check-In Form — Design

**Date:** 2026-06-22
**Status:** Approved (design); pending implementation plan

## Goal

Turn the currently no-op "Check In" button on the open-mat detail screen into a real **check-in form** that records a training-session log plus the captured **GPS location, timestamp, and a snapshot of the gym/session**. Location is stored with a soft trust flag, never blocking the check-in.

## Approach

Extend the **existing** check-in infrastructure rather than introduce a parallel entity:
- The `CheckIn` schema, `POST /api/v1/open-mats/:id/checkin` route, and `CheckInFacade.checkIn(...)` already exist; `gymName`/`openMatTitle`/`userName`/`beltRank` fields are already defined but never populated.
- We enrich the request and record, have the facade build the gym/session/user snapshot and compute the location flag, and add a real form screen on mobile (the app already depends on `geolocator`).

## Data model (`packages/contract`)

### New enum `enums/check-in-location-status.mts`
```
CheckInLocationStatus = "verified" | "far" | "no_location"
```
- `verified`: GPS present and within the radius of the gym's coordinates.
- `far`: GPS present but beyond the radius.
- `no_location`: no GPS captured, or the gym has no coordinates to compare against.

### `schemas/check-in.mts` — extend `CheckIn`
Add (all optional except `locationStatus`):
- GPS: `latitude?: number`, `longitude?: number`, `gpsAccuracyM?: number`.
- Trust: `locationStatus: CheckInLocationStatus` (default `"no_location"`), `distanceM?: number` (meters from the gym; absent when `no_location`).
- Gym/session snapshot: `gymId?: string`, `gymCity?: string`, `gymState?: string`. (`gymName`, `openMatTitle`, `userName`, `beltRank` already exist.)
- Training log: `note?: string`, `rounds?: integer (min 0)`, `intensity?: integer (1..5)`, `partners?: integer (min 0)`.

### `schemas/requests/check-in-requests.mts` — new `CreateCheckInRequest`
```
CreateCheckInRequest = {
  sessionDate: string,            // required
  latitude?: number,
  longitude?: number,
  gpsAccuracyM?: number,
  note?: string,
  beltRank?: BeltRank,
  rounds?: integer (min 0),
  intensity?: integer (1..5),
  partners?: integer (min 0),
}
```
The existing minimal `CheckinRequest` (`{ sessionDate }`) is superseded by this; remove it once the route is switched (grep for other consumers first).

## API (`apps/api`)

### Constant
`CHECKIN_VERIFY_RADIUS_M = 500` (in the facade).

### `facades/check-in.facade.mts`
- Inject `openMatRepo` (`findById`) and `userRepo` (`findById`) in addition to the checkins repo (DI wiring in `container.mts`).
- Change `checkIn(openMatId, userId, sessionDate)` → `checkIn(openMatId, userId, req: CreateCheckInRequest)`:
  1. Load the open mat (`OpenMatDetail` is already denormalized: `gymName`, `city`, `state`, `latitude`, `longitude`, `title`, `gymId`). 404 if missing.
  2. Load the user (`displayName`, `beltRank`) for `userName`/`beltRank` fallback.
  3. Compute location: if `req.latitude`/`longitude` present AND the mat has `latitude`/`longitude` → `distanceM` via haversine; `locationStatus = distanceM <= 500 ? "verified" : "far"`. Otherwise `locationStatus = "no_location"`, `distanceM` undefined.
  4. Insert the check-in with: ids/sessionDate/`checkedInAt`(now)/`createdAt`(now), GPS fields, `locationStatus`/`distanceM`, gym snapshot (`gymId`,`gymName`,`gymCity`,`gymState`,`openMatTitle`), `userName`, log fields (`note`,`beltRank` (req ?? user.beltRank),`rounds`,`intensity`,`partners`).
- A small private pure `haversineMeters(lat1,lng1,lat2,lng2)` helper (unit-testable).

### `routes/open-mat.routes.mts`
- `POST /:id/checkin`: body `CreateCheckInRequest`; `requireAuth`; call `checkInFacade.checkIn(params.id, identity.userId, body)`.

### `repositories/check-in.repository.mts`
- `insert` already stores the whole `CheckIn` object — the new fields persist automatically once they're on the type. No query changes required (existing `listByUser`/`listBySession` return the richer record).

## Mobile (`apps/mobile`)

### Location service `lib/core/location/location_service.dart` (new)
- A thin, injectable wrapper over `geolocator`: `Future<CapturedLocation?> current()` that requests permission, returns `{lat, lng, accuracyM}` or `null` (denied/disabled/timeout). Exposed via a Riverpod provider so tests can override it with a fake. Never throws to the caller — returns null on any failure.

### `features/checkins/models/checkin.dart`
- Add the new fields (`latitude`, `longitude`, `gpsAccuracyM`, `locationStatus`, `distanceM`, `gymCity`, `gymState`, `note`, `rounds`, `intensity`, `partners`) to `CheckIn` + `fromJson` (null-safe).

### Request DTO `features/checkins/data/check_in_request.dart` (new)
- `CreateCheckInRequest` with `toJson()` (omit nulls), mirroring the contract.

### `features/checkins/data/attendance_repository.dart` (or a new `check_in_repository.dart`)
- Add `Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req)` → `POST /api/v1/open-mats/$openMatId/checkin`, unwrap `data` → `CheckIn.fromJson`. Same Dio/try-catch/ApiException pattern.

### `features/checkins/screens/check_in_form_screen.dart` (new)
- On init: call `locationService.current()` (non-blocking; show a subtle "Location off — checking in without it" chip if null). Store the captured location in state.
- Read-only header: gym name + session title/time/date (passed via route or fetched).
- Fields: `note` (multiline), belt (dropdown, default from the user's profile/auth), `rounds` (number), `intensity` (1–5 selector), `partners` (number). All optional.
- Submit: builds `CreateCheckInRequest` (sessionDate = the session's date; today's date if recurring/unspecified), includes captured lat/lng/accuracy, calls `attendanceRepository.checkIn(...)`. On success → navigate to the existing `checkin_success_screen`; the success screen shows the returned `locationStatus` ("Location verified" / "Far from gym" / "Location off").
- Errors surface inline (ApiException message); submit shows a spinner.

### Routing + entry (`lib/app/router.dart`, `open_mat_detail_screen.dart`)
- Add a `checkin` sub-route under `open-mat/:id` → `CheckInFormScreen(sessionId: ...)`.
- Wire the detail screen's (currently empty `onTap: () {}`) **Check In** button in BOTH the Glass and Sport variants to `context.go('/open-mat/<id>/checkin')`.

## Surfacing the flag

The success screen shows the location status line. Owner attendee/check-in lists already exist (`GET /:id/checkins`, `attendance_repository.forSession`); rendering the per-check-in flag/log there is a minor follow-up, not part of this spec.

## Testing

### API (`bun test`)
- `haversineMeters` returns ~0 for identical points and a known distance for a known pair (tolerance).
- Facade: within-radius coords → `verified` + `distanceM`; far coords → `far`; missing GPS → `no_location`/no distance; gym without coords → `no_location`. Snapshot fields populated from the open mat + user. GPS + log fields persisted. (Fakes for openMat/user/checkin repos, mirroring the existing facade-test style.)
- Route: `POST /:id/checkin` with a full body → 200, response carries `locationStatus` and the snapshot.

### Mobile
- Widget test for `CheckInFormScreen` with an overridden `locationService` returning a fixed position: fields render; filling them + submit calls the repo with a `CreateCheckInRequest` carrying the captured coords + entered values (repo overridden with a fake that captures the request). A second case: `locationService` returns null → the "location off" chip shows and submit still succeeds (coords null).

## Out of scope (YAGNI)

- Editing/deleting a check-in after submit (review flow already exists separately).
- Photo upload, duplicate-check-in windows, server-side GPS anti-spoofing beyond the soft flag.
- Rendering the flag/log in owner attendance lists (minor follow-up).

## Affected files

- Contract: `enums/check-in-location-status.mts` (new) + barrel; `schemas/check-in.mts`; `schemas/requests/check-in-requests.mts`.
- API: `facades/check-in.facade.mts`; `container.mts`; `routes/open-mat.routes.mts`; (tests) `test/check-in.facade.test.mts`, `test/open-mat.routes.test.mts`.
- Mobile: `core/location/location_service.dart` (new); `features/checkins/models/checkin.dart`; `features/checkins/data/check_in_request.dart` (new); `features/checkins/data/attendance_repository.dart`; `features/checkins/screens/check_in_form_screen.dart` (new); `features/checkins/screens/checkin_success_screen.dart`; `app/router.dart`; `features/open_mats/screens/open_mat_detail_screen.dart`; (tests) `test/features/check_in_form_test.dart` (new).
