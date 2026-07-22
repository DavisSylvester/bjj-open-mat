# Design: "Gyms near you" — within 50 miles (Discover)

**Date:** 2026-07-21
**Scope:** Mobile app (`apps/mobile`), Discover/home screen only. Search screen unchanged.

## Goal

Rework the Discover screen's "Gyms near you" section so it always lists **any gym
within 50 miles** of the device (not just gyms that happen to have open mats), and
rework the gym card to:

- **Remove** the `Next: <day> <time>` line.
- **Add** a tappable **address** row (pin icon → opens the platform maps app with
  directions to the gym).
- **Add** a tappable **website** row (globe icon → opens the gym's site in the
  default browser).
- **Add** a **distance** chip (miles from the device).
- Keep the gym **name** and **rating** pill; card body still taps through to the
  gym detail screen.

## Current state

- The section is built by `distinctGymsFromOpenMats(list)` in
  `apps/mobile/lib/shared/widgets/gym_card.dart`, which derives gyms **from the
  open-mats feed** — so it only shows gyms that have open mats.
- It renders only as **sparse-feed filler** (when there are `< 3` open mats), in
  both `discover_screen.dart` (line ~213) and `search_screen.dart` (line ~610),
  via the shared `GymCard` (shows name, city/state, rating, and `Next: …`).
- A ready-to-use provider already exists:
  `nearbyGymsProvider(NearbyQuery)` in
  `apps/mobile/lib/features/discover/providers/discover_provider.dart` →
  `GET /api/v1/gyms/nearby?lat&lng&radiusKm`, returning `List<Gym>`.
- `Gym` (`apps/mobile/lib/features/gyms/models/gym.dart`) already carries
  `address`, `website`, `location`, `rating`, and `distanceKm`.
- The API `/gyms/nearby` route uses a `$near` query with `maxDistance = radiusKm *
  1000` (default 25 km) — no server change needed.
- Reusable helpers exist: `openDirections(ref, context, gymId, address)` in
  `apps/mobile/lib/features/gyms/data/directions.dart` (added for the open-mat
  detail directions), and `url_launcher` for the website.

## Design

### 1. Data source

On Discover, add a second watch:
`nearbyGymsProvider(NearbyQuery(lat, lng, radiusKm: 80))` — 80 km ≈ 50 miles.

- Query/show the section **only when `locState.hasCoords`** — `/gyms/nearby`
  requires lat/lng. When coordinates are unavailable, the section is omitted.
- This is independent of the open-mats feed, so it lists any gym in range.
- `distinctGymsFromOpenMats` is **no longer used on Discover** (it remains for
  Search).

### 2. Discover layout restructure

Collapse the current three feed branches (empty / sparse `<3` / full) into a
**single scrollable column** so both sections coexist:

1. **Open Mats** section — the session rows, or the existing `EmptyState` when
   there are none.
2. **Gyms near you** section — eyebrow `GYMS NEAR YOU`, title `Within 50 miles`,
   followed by the nearby-gym cards. Always rendered below the open-mats section
   when `locState.hasCoords` and the nearby-gyms list is non-empty.

Use a single `SingleChildScrollView`/`CustomScrollView` for the feed area
(replacing the `Expanded` + separate `ListView`/`SingleChildScrollView` branches).
Search's layout and behavior are untouched.

### 3. New `NearbyGymCard` widget

Add `NearbyGymCard` (in `apps/mobile/lib/shared/widgets/`) taking a `Gym`. It
reuses the existing glass card chrome. `GymSummary`, `distinctGymsFromOpenMats`,
and `GymCard` remain for Search.

Layout:

```
┌─────────────────────────────────┐
│ [📍] RM Elite BJJ    12 mi  ⭐5.0 │
│      203 Bear Rd, Bldg #11     🧭 │
│      rmelitebjj.com            🌐 │
└─────────────────────────────────┘
```

- **Header row:** pin avatar + `gym.name`; a **distance chip**
  `${(gym.distanceKm! / 1.60934).round()} mi` (shown when `distanceKm != null`);
  the existing **rating pill** (shown when `rating != null`).
- **Address row:** `LucideIcons.mapPin` + `gym.address`. Tappable → its own
  `GestureDetector` calling `openDirections(ref, context, gymId: gym.id, address:
  gym.address)`. Omitted when `address` is empty.
- **Website row:** `LucideIcons.globe` + display host (strip scheme and leading
  `www.`, e.g. `rmelitebjj.com`). Tappable → `launchUrl(..., mode:
  externalApplication)`, prepending `https://` when the stored value has no
  scheme. Omitted when `website` is null/empty.
- **Card body tap** → `context.push('/gym/${gym.id}')` (unchanged). The address
  and website `GestureDetector`s swallow the tap so they don't also navigate.

Because `NearbyGymCard` needs `ref` (for `openDirections`), it is a
`ConsumerWidget`.

### 4. Error / edge handling

- `nearbyGymsProvider`: loading → a small spinner in the section; error → a quiet
  `Couldn't load nearby gyms` line; empty list → the section is omitted.
- Null/empty `address` or `website` → that row is omitted (never an empty
  pin/globe).
- No device coordinates → the whole section is omitted.

### 5. Testing

- **`NearbyGymCard` widget tests:** renders name, address, website host, and
  distance; website row absent when `website` is null; address row absent when
  `address` is empty; tapping the pin invokes directions and tapping the globe
  launches the URL (through a mockable seam, e.g. an injected launcher or the
  `openDirections` path).
- **Discover screen test:** override `nearbyGymsProvider` to return a gym →
  assert the `Within 50 miles` section header and the gym's address render, and
  that `Next: ` no longer appears in that section.
- Update the existing `apps/mobile/test/features/discover_screen_test.dart` for
  the restructured single-scroll feed.

## Out of scope

- Search screen "More places to roll" (keeps `GymCard` + next-day/time filler).
- Any API/backend change (the `/gyms/nearby` radius is client-supplied).
- Sorting/filtering controls for the nearby-gyms list (server returns nearest
  first via `$near`).
