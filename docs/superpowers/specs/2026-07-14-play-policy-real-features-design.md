# Play Policy Fix — Wire Stub Screens to Real Features

**Date:** 2026-07-14
**Driver:** Google Play rejection (Misleading Claims — "app description lists features not present in the app"; flagged areas: App screenshot (en-US), In-app experience).
**Goal:** Every screen a reviewer can reach shows real, user-specific data backed by the live API, and every description claim maps to a working feature. Then resubmit.

## Problem

Four reachable screens in `apps/mobile` render hard-coded stub data for every user, and one description claim ("directions") has no implementation:

| Surface | File | Stub |
|---|---|---|
| My Training | `lib/features/training/screens/my_training_screen.dart` | Fake stat strip (47 mats / 94 hrs / 7 streak / 8 gyms) + 4 fake sessions |
| Favorites | `lib/features/favorites/screens/favorites_screen.dart` | 4 hard-coded gyms |
| Notifications | `lib/features/notifications/screens/notifications_screen.dart` | 4 fake notifications |
| Gym Detail | `lib/features/gyms/screens/gym_detail_screen.dart` | Ignores `gymId`; always renders "ATOS HQ / Los Angeles, CA / 4.8★" + fake sessions |
| Directions | — | `url_launcher` in pubspec but unused; no directions anywhere |

The backend already implements everything needed: `GET /users/me/checkins`, `GET /users/me/favorites`, `POST/DELETE /gyms/:id/favorite`, `GET/POST /api/v1/notifications` (+ `:id/read`, `read-all`), `GET /gyms/:id`, `GET /open-mats?gymId=`, `GET /gyms/:id/directions` (returns `{latitude, longitude, address, mapsUrl}`).

## Design

Follow existing repo conventions throughout: repository classes over `Dio` (`rsvp_repository.dart` is the template), Riverpod `FutureProvider`s, `unwrapList`/`unwrapData` envelope helpers, `ApiException.fromDio`, and the shared `shimmer_loader` / `error_state` / `empty_state` widgets. Glass theme and layout of each screen stay as-is — only the data source changes.

### 1. My Training (real check-ins)

- New `lib/features/training/data/training_repository.dart` + provider fetching `GET /users/me/checkins` (page size 100; use envelope `total` for the Mats stat).
- New pure function `computeTrainingStats(List<CheckIn>, {DateTime? now})` in `lib/features/training/data/training_stats.dart`:
  - **Mats** = total check-ins (envelope total)
  - **Gyms** = distinct non-empty `gymId`
  - **Rounds** = sum of `rounds` (null → 0)
  - **Streak** = consecutive calendar weeks with ≥1 check-in, counting backward from the current week (a week with no check-in breaks it; current week without a check-in yet does not break a streak anchored on last week)
- Session History = real check-ins rendered by a new lightweight `CheckInRow` widget in the training feature (`SessionRow` requires gi/exp/distance fields check-ins don't carry). Shows gym name (fallback: open-mat title), formatted `sessionDate`, rounds/partners when logged, and star rating when reviewed. Same GlassCard styling as other rows.
- States: shimmer while loading, `ErrorState` on failure, `EmptyState` ("No sessions yet — check in at an open mat to start your log") when zero check-ins; stat strip renders zeros.

### 2. Favorites (real favorites)

- New `lib/features/favorites/data/favorite_repository.dart`:
  - `list()` → `GET /users/me/favorites` → `List<Gym>`
  - `add(gymId)` → `POST /gyms/:id/favorite`
  - `remove(gymId)` → `DELETE /gyms/:id/favorite`
- Favorites screen lists real gyms (name, city/state, rating when present); tap → `/gyms/:id`; heart icon removes (optimistic update, revert + snackbar on failure).
- Heart toggle appears **only** on the Gym Detail header (filled = favorited). Initial state derived from the favorites list provider.
- `EmptyState` when no favorites ("No favorite gyms yet — find a gym and tap the heart").

### 3. Notifications (real inbox)

- New `lib/features/notifications/models/app_notification.dart` mirroring the contract schema (`id, type[rsvp|review|session_update|system], title, body, read, data?, createdAt`).
- New `lib/features/notifications/data/notification_repository.dart`: `list({unread, page, limit})`, `markRead(id)`, `markAllRead()`.
- Screen: real list, icon/color by `type` (reuse current stub styling map), unread items emphasized, tap marks read, "Mark all read" header action, relative timestamps from `createdAt`. `EmptyState` when empty. Push delivery is out of scope — this is the in-app inbox the API populates.

### 4. Gym Detail (real gym)

- Wire to `gymRepository.getById(gymId)` (exists) and `GET /open-mats?gymId=` for that gym's sessions.
- Header: real name, city/state, gi badge only if derivable; pills show only real data (rating when present, `isVerified` badge, sessions/week from fetched sessions). Remove hard-coded "1.2 mi" unless `distanceKm` present.
- Favorite heart (see §2) and Directions button (see §5) live here.
- Missing/invalid `gymId` → `ErrorState`.

### 5. Directions

- New small helper `lib/core/location/directions_launcher.dart`: fetch `GET /gyms/:id/directions`, open `mapsUrl` with `url_launcher` (`LaunchMode.externalApplication`). Failure → snackbar.
- Buttons: Gym Detail (primary action row) and Open-Mat Detail (with the session info). Open mat without a `gymId` → fall back to `https://www.google.com/maps/search/?api=1&query=<encoded address>`.

### 6. Testing

- `flutter test` unit tests: `computeTrainingStats` (empty list, rounds nulls, distinct gyms, streak edge cases: gap week, current-week grace, single week), notification/gym JSON parsing, favorites repository envelope handling (Dio mocked via existing test patterns).
- Manual verify: run app against prod API with a real account; walk Training/Favorites/Notifications/Gym Detail/Directions.

### 7. Store listing follow-through

- New `docs/play-store-listing.md`: Play-ready description (all claims true post-fix; no "Hours"), short description, and a resubmission checklist:
  1. Ship fixed build to Play (internal → promote).
  2. Retake en-US phone screenshots from the real build (no placeholder art, no fabricated data).
  3. Update Store listing text + screenshots in Play Console.
  4. Resubmit via Publishing overview. No appeal — the violation was legitimate and is fixed by this work.

## Out of scope

Push notification delivery, in-app map view, iOS/App Store listing changes, favorites hearts on list cards.
