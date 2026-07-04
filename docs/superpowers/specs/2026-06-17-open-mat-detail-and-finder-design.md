# Open Mat Detail + Open Mat Finder — Design Spec

**Date:** 2026-06-17
**Status:** Approved (design). Implementation deferred until after the API session; the seed API already satisfies the contract, so it may begin against `localhost:3100`.
**Related:** `docs/decisions/2026-06-17-open-mat-api-contract.md`, `docs/decisions/2026-06-17-monorepo-architecture.md`

## Goal

When a user taps an open-mat card, open a full detail screen with directions and RSVP/attendance; rename the Search screen to "Open Mat Finder" with day-of-week search, GPS-based location, and time-sorted results.

## Decisions (from brainstorming)

1. **Data:** Flutter consumes the **real API contract** via a repository behind a provider. Backend built separately (seed API exists now).
2. **Attending = RSVP** for an occurrence (forward-looking), distinct from post-hoc check-in.
3. **Finder:** day-of-week chips → flat list **sorted by start time, nearest-first tiebreak**; mileage kept on cards.
4. **Location:** GPS via `geolocator` — auto on mobile; web requests permission, falls back gracefully on denial.
5. **Directions:** Google Maps, Waze, Apple Maps buttons via `url_launcher`.

## Architecture — repository behind a provider

- `OpenMatRepository` (abstract): `getById`, `getAttendees`, `rsvp`, `cancelRsvp`, `findByDay`.
- `ApiOpenMatRepository` (Dio → endpoints) and `MockOpenMatRepository` (seed) implement it.
- `openMatRepositoryProvider` selects implementation via `--dart-define=USE_MOCK=true|false`; screens depend only on providers. Mock becomes a test fixture once the API is live.

### Providers
- `openMatDetailProvider(id)` → `FutureProvider.family<OpenMatDetail, String>`
- `attendeesProvider((id, sessionDate))` → `FutureProvider.family<List<Attendee>, (String,String)>`
- `rsvpControllerProvider` → toggles attending (optimistic), invalidates `attendeesProvider` on success, reverts + snackbars on failure
- `finderProvider(dayOfWeek)` → location-aware list, sorted by start time then distance
- `currentLocationProvider` → `FutureProvider<({double lat, double lng})?>` (geolocator; null on denial/unavailable)

### Models (Dart, mirrored from `@bjj/contract` / OpenAPI)
- Extend `OpenMat` with `latitude, longitude, address, city, state, feeCents?, attendeeCount?` (→ `OpenMatDetail`).
- New `Attendee { userId, name, beltRank, beltStripes?, skillLevel, avatarUrl?, rsvpAt }`.

## Components

### 1. Open Mat Detail screen (rewrite `OpenMatDetailScreen`, data-driven)
Sections, Glass (Minimal Vibrant) + Sport variants:
- Back + favorite nav row
- Hero: eyebrow "Open Mat" + gym/title, date/time, Gi/Exp/fee badges
- **Directions card**: address + Google / Waze / Apple buttons (`url_launcher` deep links from lat/lng)
- **Attending button** (full-width primary): outline "I'm Attending" ↔ filled "Attending ✓"; optimistic toggle via `rsvpControllerProvider`
- **Attendees**: "{count} going" header + rows (avatar, name, belt badge, skill); empty state "Be the first to RSVP"
- About, Ratings
- Loading (shimmer) / error (`error_state`) / empty states

### 2. Open Mat Finder (rewrite Search screen)
- Title **"Open Mat Finder"** (was "Find a Mat")
- Location row: GPS state / "Enable location" CTA (web permission prompt)
- **Day-of-week chips** Mon–Sun (default = today)
- Results header "{N} sessions · {Day}"
- List **sorted by start time, nearest-first tiebreak**; each card keeps mileage and is tappable
- Loading / empty / error states

### 3. Card navigation wiring
- `SessionRow` gains `onTap`; card data carries real `id` + `sessionDate`.
- Discover / Finder / Training / Profile cards push `/open-mats/:id`.
- Map `OpenMat → SessionRowData` for display.

## Error handling
- API errors → `error_state` widgets with retry.
- Location denied → hide distance + show "Enable location"; still list sessions (no nearest-first tiebreak).
- RSVP failure → revert optimistic toggle + snackbar.

## Testing
- Unit: `MockOpenMatRepository`; finder day-filter + start-time sort + distance-tiebreak; `OpenMat→SessionRowData` mapping.
- Widget (optional): detail renders attendees; RSVP toggles label.

## Scope
One cohesive plan (detail + RSVP + finder). Backend is out of scope (its contract + seed reference already exist). Health-path fix (`/healthz` → `/health` + `/ready`) folds into the API-wiring task.
