# Discovery Empty-State + Reviews + Owner Metrics — Implementation Plan

**Date:** 2026-07-05
**Status:** Approved direction (decisions below); ready to break into tasks.
**Scope:** Three connected pieces of work with UI + API + DB + form screens.

## Decisions (from review)
- **Reviews are per open-mat *session per day*, one per day, and roll into check-in.** A review is stored on the user's check-in for that session+date. Because a user has exactly one check-in per session per date, that enforces "review each day you attend, once per day." Multi-day attendees get one review per day.
- **Owner dashboard metrics (Check-ins, Avg Rating) will be implemented for real** (wired to data), not removed.
- **Discovery empty-state**: results match the searched city/state; fill short feeds with nearby gyms that *have* open mats; else "No open mats found in {City, ST}".

---

## Part A — Discovery empty-state & location matching

### Behavior
1. One source of truth for "where am I searching": the typed city/state (or ZIP). GPS only seeds the default; the chip is a "use my location" reset, not a competing value.
2. Open mats for that location exist → show them.
3. Feed short (`< 3`) → append a **"Gyms near you" section** listing nearby gyms that have open mats (name, city/state, next session, rating).
4. No gyms in the searched city/state have open mats → **"No open mats found in {City, ST}"** + "Widen radius / Change location" CTA.

### API
- `GET /api/v1/open-mats` gains optional `city` + `state` params (exact match), independent of lat/lng.
- `GET /api/v1/gyms/nearby?lat&lng&radiusMiles&withOpenMats=true` returns gyms in range annotated with `openMatCount` and `nextSession`. Extend `gym.repository` to join open-mat counts.

### Mobile
- `NearbyQuery`: add `city`, `state`, `locationSource` (gps|typed).
- New `gymsNearbyProvider`.
- `GymCard` + `EmptyState` shared widgets (glass tokens). Wire into `DiscoverScreen` and `SearchScreen` below the feed with the `<3` / `==0` logic.

### Tasks (A)
- A1 API: `city`/`state` filter on open-mats; `withOpenMats` gyms-nearby with `openMatCount`/`nextSession`; tests.
- A2 Mobile providers: extend `NearbyQuery`; add `gymsNearbyProvider`.
- A3 Mobile UI: `GymCard`, `EmptyState`; wire into Discover + Search.
- A4 Verify on simulator: San Diego → Atos; empty city → "No open mats found in {City, ST}".

---

## Part B — Reviews (rolled into check-in), UI + API + DB

### Model (extend the existing check-in doc — no new collection)
The check-in already carries `rating`, `review`, `categoryRatings`. Formalize it:
```
CheckIn {
  id, userId, openMatId, gymId, sessionDate,   // sessionDate = the day attended
  checkedInAt,
  review?: {
    rating: 1..5,
    categoryRatings: { instruction, cleanliness, variety, wouldReturn },  // 1..5 each
    comment?: string (<= 1000),
    reviewedAt
  }
}
```
- Uniqueness: existing unique index `(userId, openMatId, sessionDate)` on check-ins already guarantees **one check-in — and therefore one review — per session per day**. No extra constraint needed.

### API
- Keep `POST /api/v1/checkins/:id/review` (already exists) as the write path; ensure it sets `reviewedAt` and rejects reviewing another user's check-in (already does).
- After a review write, **recompute gym aggregate**: `gym.rating = avg(review.rating)` over all reviewed check-ins for that gym, plus `gym.ratingCount`. Do this in the check-in review facade.
- `GET /api/v1/open-mats/:id/reviews?sessionDate?&page` and `GET /api/v1/gyms/:id/reviews?page` → list reviews (join check-ins where `review != null`), newest first, with author display name + belt.
- Contract: add a `Review` view type in `@bjj/contract` (derived from the check-in review shape) for the list responses.

### Mobile
- Turn `checkins/screens/review_screen.dart` (currently an unwired stub) into a real form: overall stars + 4 category ratings (`stat_bar`/`score_cell`) + comment + submit → `POST /checkins/:id/review` via a new `reviewSubmitProvider`.
- Entry: it's reached today at `/open-mat/:id/review`; gate it so it opens only when the user has a check-in for that session+date (otherwise route them to check-in first — reinforces "review rolls into check-in").
- Open-mat detail + gym detail "Ratings" section: show aggregate + a **reviews list** (recent reviews), and a "Write a review" button that goes to check-in→review.

### Tasks (B)
- B1 API: set `reviewedAt`; gym-aggregate recompute in the review facade; `ratingCount` on gym; tests for aggregate + one-per-day.
- B2 API: `GET open-mats/:id/reviews` and `gyms/:id/reviews`; `Review` view type in contract.
- B3 Mobile: `reviewRepository` + `reviewSubmitProvider`; wire `review_screen` form; check-in gate.
- B4 Mobile: reviews-list widget + aggregate on gym/open-mat detail; "Write a review" entry.
- B5 Verify: check in → review → gym rating updates → review shows in list; second review same day is blocked.

---

## Part C — Owner dashboard live metrics (Check-ins, Avg Rating)

### Behavior
Replace the hardcoded `'--'` tiles with real values scoped to the owner's gyms:
- **Check-ins** = count of check-ins across all of the owner's sessions (optionally last 30 days).
- **Avg Rating** = average `gym.rating` across the owner's gyms (weighted by `ratingCount`), or "—" with a clear "No ratings yet" sub-label when `ratingCount == 0` (a real empty state, not a bare dash).

### API / DB
- Extend `ownerStatsProvider`'s backing data: add `GET /api/v1/owner/stats` (or extend an existing owner endpoint) returning `{ gyms, sessions, checkIns, avgRating, ratingCount }`.
- `check-in.repository`: `countForOwner(ownerId)` (join sessions→gyms owned by owner). `gym.repository`: `avgRatingForOwner(ownerId)`.

### Mobile
- `ownerStatsProvider` returns the richer record; `_StatCard` renders real values; empty state ("No ratings yet") when count 0.
- **Coherence fix (from sweep):** owner sub-screens (Sessions FAB + list icon tiles, dashboard stat-tile icons) currently use teal/green/multicolor — unify to the owner crimson identity (`t.red`) unless a metric legitimately needs a semantic color. Give My Gyms / Sessions list rows the standard white card + hairline treatment.

### Tasks (C)
- C1 API: `owner/stats` with checkIns + avgRating + ratingCount; repo methods; tests.
- C2 Mobile: richer `ownerStatsProvider`; real `_StatCard` values + "No ratings yet" empty state.
- C3 Mobile: owner coherence — crimson accents on Sessions/My Gyms; card-style list rows; reduce dashboard dead space.
- C4 Verify on simulator (owner mode): real counts render; ratings empty state reads intentionally.

---

## Remaining open questions
1. Discovery "Gyms near you" threshold — proposing show it when open-mats `< 3`. OK?
2. Category set — keep Instruction / Cleanliness / Variety / Would-Return + Overall, same for gyms and open mats? OK?
3. Owner "Check-ins" metric — all-time or last-30-days?

## Out of scope
Review photos/media, moderation/reporting, owner replies, review editing history.
