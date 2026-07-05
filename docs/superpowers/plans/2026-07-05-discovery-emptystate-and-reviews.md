# Discovery Empty-State + Reviews Capture — Plan

**Date:** 2026-07-05
**Status:** Draft plan (awaiting sign-off)
**Covers two related pieces of "item 1":**
- **A. Discovery empty-state** — fill Home/Search dead space with nearby gyms that have open mats; else "No open mats found"; results must match the searched city/state.
- **B. Reviews capture** — let a user review a gym or an open mat; new API + UI; persist to DB and aggregate into gym rating.

---

## Part A — Discovery empty-state & location matching

### Problem (from the UX sweep)
Home and Search leave ~50% dead space when the seeded feed is short, and Search shows a typed location ("Los Angeles, CA") while the GPS chip says something else ("San Diego, CA"), so it's unclear which location the results reflect.

### Desired behavior
1. Results are **scoped to the searched location** (the typed city/state or ZIP; GPS only seeds the default). One source of truth for "where am I searching."
2. If open mats exist for that location → show them (current behavior).
3. If the open-mat list is short/empty → show a **"Gyms near you" section listing nearby gyms that have open mats** (gym name, city/state, next open-mat time, rating), filling the space.
4. If **no gyms in the searched city/state have open mats** → a single empty-state: **"No open mats found in {City, ST}"** + a "Widen radius" / "Change location" affordance.

### Data / API
- Reuse `GET /api/v1/open-mats?lat&lng&radiusMiles` (already returns `gymName`, `city`, `state`, `distanceKm`).
- Add a **`hasOpenMats` filter** (or a lightweight `GET /api/v1/gyms/nearby?lat&lng&radiusMiles&withOpenMats=true`) that returns gyms in range annotated with `openMatCount` and `nextSession`. `gym.repository` already has nearby geo queries; extend it to left-join open-mat counts.
- Add optional **`city` + `state` query params** to the open-mats/gyms endpoints so a text search ("Los Angeles, CA") filters by city/state exactly, independent of GPS.

### Mobile
- `discover_provider` / `search` `NearbyQuery`: add `city`, `state`, and a `locationSource` (gps | typed) field. The typed field, when set, drives the query; the GPS chip becomes a "use my location" reset, not a competing value.
- `DiscoverScreen._buildGlass` and `SearchScreen`: after the open-mats list, render a **`GymsNearbySection`** when `openMats.length < N` (e.g. 3), and an **`EmptyOpenMats`** widget ("No open mats found in {label}") when the count is 0.
- New shared widgets: `GymCard` (white card, hairline border, rating pill) and `EmptyState` (icon + message + CTA), both on the glass tokens.

### Tasks (A)
- A1. API: `city`/`state` filter params on open-mats + `withOpenMats` gyms-nearby with `openMatCount`/`nextSession`. Tests.
- A2. Mobile providers: extend `NearbyQuery` + a `gymsNearbyProvider`.
- A3. Mobile UI: `GymCard`, `EmptyState`, wire into Discover + Search below the feed with the `< N` / `== 0` logic.
- A4. Verify on simulator: San Diego shows Atos; a no-result city shows "No open mats found in {City, ST}".

---

## Part B — Reviews capture (gym / open-mat), API + UI + DB

### Current state
- `ReviewRequest` = `{ rating: 1–5, review?: string, categoryRatings }`, only reachable via `POST /api/v1/checkins/:id/review` (a review is stored **on the check-in doc**; you must have checked in first).
- Gyms carry a single `rating` (0–5) that is currently seeded, not computed.
- Mobile `checkins/screens/review_screen.dart` is a **UI stub** with hardcoded category sliders and **no API submit**.

### Desired feature
Let a user submit a review for a **gym** or an **open mat** (not only after a check-in), persist each review as its own document, and **recompute the gym's aggregate rating** from its reviews.

### Data model (new `reviews` collection)
```
Review {
  id: string
  authorId: string            // from auth identity
  targetType: 'gym' | 'open_mat'
  targetId: string            // gymId or openMatId
  gymId: string               // denormalized for aggregation
  rating: 1..5                // overall
  categoryRatings?: { instruction, cleanliness, variety, wouldReturn }  // reuse existing shape
  comment?: string (<= 1000)
  checkInId?: string          // optional link when review follows a check-in
  createdAt, updatedAt
}
```
Unique index `(authorId, targetType, targetId)` → one review per user per target (upsert on re-submit).

### API (new)
- `POST /api/v1/reviews` body `{ targetType, targetId, rating, categoryRatings?, comment? }` → creates/updates the review, then recomputes and writes `gym.rating = avg(overall)` and `gym.ratingCount`.
- `GET /api/v1/reviews?targetType&targetId&page` → paginated reviews for a target.
- `GET /api/v1/gyms/:id` → already returns `rating`; add `ratingCount` and (optionally) `categoryAverages`.
- Validate with TypeBox (`ReviewCreateRequest` in `@bjj/contract`); reuse `categoryRatings`.

### Persistence & aggregation
- New `ReviewRepository` (insert/upsert, `listByTarget`, `averageForGym`). Recompute the gym aggregate inside the create facade in one transaction/step.
- Keep the existing check-in review path working; optionally have it also write a `reviews` row (`checkInId` set) so both surfaces share aggregation. (Decision needed — see open questions.)

### Mobile UI
- Repurpose `review_screen.dart` into a real form: overall stars + the four category ratings (reuse `stat_bar`/`score_cell`) + comment field + submit. Wire to a new `reviewRepository.submit(...)`.
- Entry points: open-mat detail "Ratings" section → "Write a review"; gym detail → "Write a review". After submit, show the updated aggregate.
- Reviews list: show recent reviews under the Ratings section on gym/open-mat detail.

### Tasks (B)
- B1. Contract: `Review` schema + `ReviewCreateRequest` in `@bjj/contract` (TypeBox, derived types).
- B2. API: `ReviewRepository`, `ReviewFacade` (create/upsert + gym aggregate recompute), routes (`POST /reviews`, `GET /reviews`), `gyms/:id` returns `ratingCount`. Unit tests.
- B3. Mobile: `ReviewRepository` (Dio), `reviewSubmitProvider`; turn `review_screen` into a wired form; add "Write a review" entry points on gym + open-mat detail; reviews list widget.
- B4. Verify on simulator: submit a review → gym rating updates → review appears in the list; DB has the `reviews` doc.

---

## Open questions (please confirm)
1. **One review per user per target** (upsert) — correct, or allow multiple/edit-history?
2. **Category ratings**: keep the existing 4 (Instruction, Cleanliness, Variety, Would-Return) + Overall? Same set for gyms and open mats?
3. Should the **check-in review** path be folded into the new `reviews` collection, or left as-is and only the new standalone reviews aggregate?
4. Empty-state (A): threshold **N** for showing the "Gyms near you" section (proposing < 3), and does "nearby gyms" mean *any* gym in range or only gyms *with* open mats? (Plan assumes only gyms with open mats, per your wording.)

## Out of scope
- Photos/media on reviews; moderation/reporting; owner replies to reviews.
