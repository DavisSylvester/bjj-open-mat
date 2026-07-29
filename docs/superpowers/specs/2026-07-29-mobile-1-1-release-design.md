# Mobile 1.1 Release — Design

**Date:** 2026-07-29
**App:** BJJ OPEN MAT (iOS, Apple ID `6787704999`)
**Status:** Approved

## Context

Version 1.0 went live on the App Store 2026-07-28 and is indexed (ranks #2 in the US
and #1 in Canada for "bjj open mat"). It has zero ratings. A direct competitor,
Open Mat Locator (`6788885903`), launched one day earlier with an overlapping feature
set and shipped its own 1.1 the next day.

This release bundles four code fixes, one new feature, and one App Store metadata
change. Several were found by running 1.0 on the simulator.

Two constraints shaped the design:

1. **Google does not permit programmatic review submission.** The Business Profile
   APIs read and reply to reviews but cannot create them. The only sanctioned path is
   deep-linking the user out to Google Maps.
2. **A gym review system already exists in this codebase.** `ReviewScreen` collects
   five category ratings plus free text against a check-in. The new work is a Google
   hand-off appended to that flow, not a second rating system.

## Naming

"Review" already means *gym check-in review* throughout this codebase
(`review.mts`, `review_repository.dart`, `ReviewScreen`, `/checkins/:id/review`).

The App Store rating prompt is a different thing. It is named `AppRatingService` /
`app_rating_prompt` and never "review", so the two do not blur in code or in
conversation.

---

## A. Favorites entry point

**Defect.** `FavoritesScreen` is built and routed at `/profile/favorites`, but nothing
in the app navigates to it — the only reference to the route is its own definition.
Meanwhile `gym_detail_screen.dart:108` renders a working heart toggle, so users can
favorite gyms and the data persists. They have no way to see the list they built.

**Fix.** Add a `ListTile` to the Profile settings card pushing `/profile/favorites`,
following the existing "My Gyms" row pattern (`profile_screen.dart:185-190`):
`LucideIcons.heart` leading, chevron trailing.

Placement: directly above "My Gyms", so the two browse-your-own-data rows sit together.

**Tests.** Widget test asserting the row renders and that tapping it navigates to
`/profile/favorites`.

---

## B. Join button sign-in gating

**Defect.** `JoinGymButton` sets `disabled: !isAuthed || _busy` and passes
`onTap: null`, so Flutter greys the `ElevatedButton` while the label still reads
"Join". No explanation is offered. The roster-error branch produces a *visually
identical* dead button. Two distinct states share one silent appearance, and the
signed-out case reads as broken rather than gated.

**Fix.** Separate the three states:

| State | Label | Action |
|---|---|---|
| Signed out | "Sign in to join" | push `/login` |
| Roster load failed | "Retry" | invalidate `rosterProvider(gymId)` |
| Signed in | "Join" / "Leave" | existing `_toggle` |

`_MembershipLayout` gains an explicit state enum rather than the current
`disabled` boolean, so the three cases cannot collapse into each other again.

**Tests.** Widget tests per state: signed-out shows the sign-in label and routes to
login; error state shows retry and re-invalidates; signed-in preserves current
join/leave behaviour.

---

## C. App Store rating prompt

**Goal.** Move off zero ratings. Apple hides the star display until a minimum number
of ratings accumulate, so the listing currently shows nothing at all.

**Fix.** Add the `in_app_review` package. Call `requestReview()` after the user's
**third** check-in — a point at which they have demonstrated real usage.

**Count source.** The trigger reads the count returned by the existing
`/api/v1/users/me/checkins` data the app already loads, not a locally incremented
tally. A local counter would reset on reinstall and re-prompt an established user;
it would also miss check-ins made on another device. If that data is unavailable at
the moment of check-in, no prompt fires — a missed prompt is cheaper than a wrong one.

Constraints:

- Never on launch or first run. Apple caps the system prompt at three presentations
  per user per year; spending one on a cold start wastes it.
- Fires once. A boolean flag in secure storage (`app_rating_prompted`) guards
  re-prompting.
- `requestReview()` gives no success/failure signal by design — do not branch on it,
  and never show custom UI claiming a review was left.

**Tests.** Unit tests on the trigger predicate: no prompt below three check-ins,
prompt at exactly three, no prompt once the guard flag is set.

---

## D. Error and session fixes (already implemented)

Written, tested, and currently uncommitted on `main`. Moves onto the release branch
as-is. Recorded here for release notes and traceability.

**Root cause.** A stale access token persisted in the iOS Keychain, which survives app
deletion and reinstall. `checkAuth` treated "a token exists" as "the token is valid"
and called `/api/v1/auth/me` unconditionally. The API returned 401, the refresh
interceptor could not recover it, and a generic `catch` stringified the raw
`DioException` into `state.error`, which the login screen rendered verbatim.

**Fixes.**

1. `auth_service.dart` — a 401 during `checkAuth` now clears the dead credentials via
   `clearStoredSession()` and lands on `/login` silently. Self-healing: the next launch
   finds no token and skips the request. `clearStoredSession()` deliberately avoids
   `logout()`, which would open the Auth0 hosted logout page mid-startup.
2. `lib/core/api/friendly_error.dart` — maps failures to general-but-descriptive
   messages (401/403/404/429/5xx/offline/timeout/fallback). Applied at the login path
   and six admin screens carrying the identical raw leak.
3. Login cancellation — dismissing the Auth0 sheet throws
   `WebAuthenticationException` with code `USER_CANCELLED`. That is a deliberate user
   choice, not a failure, and now returns to the login screen with no message. Both
   cancellation paths fixed (thrown exception, and the null-credentials branch that
   previously showed "Login cancelled").

**Verification already performed.** `flutter analyze` clean; 197 tests pass; the 401 was
reproduced and confirmed gone on the simulator across three runs, including proof that
the stale token is genuinely purged rather than silently re-handled each launch.

---

## E. Google review hand-off

**What it is not.** Not an in-app Google review form. Google forbids programmatic
submission; the user composes and submits in Google Maps.

**Flow.** On successful submission in the existing `ReviewScreen`, show a completion
step: "Thanks — want to share this on Google?" with a button opening the Maps review
composer via `url_launcher` in `LaunchMode.externalApplication`.

**Gates.** The Google step appears only when both hold:

- the gym has a `googlePlaceId` (already on the model, `gym.dart:12`, and in
  `packages/contract`), and the backend returned a usable URI; and
- the submitted **overall** rating is 4 or higher.

A 2-star reviewer must not be routed toward the gym's public Google profile. Everyone
else sees the normal confirmation, unchanged.

**Link source.** The legacy `search.google.com/local/writereview?placeid=` URL is
reported returning 400s in 2026 and is not used. The supported field is
`googleMapsLinks.writeAReviewUri` from **Places API (New)** Place Details
(field mask `places.googleMapsLinks.writeAReviewUri`; in preview, free at time of
writing).

**Backend.** New endpoint:

```
GET /api/v1/gyms/:id/review-link  ->  { data: { writeAReviewUri: string | null } }
```

Layered per project rules — router handles HTTP only, service orchestrates,
repository owns data access; TypeBox validation; Places API key supplied through DI
config, never hardcoded.

The URI is cached on the gym document after first retrieval. These links are stable,
so this should be one Places call per gym for the lifetime of the gym.

Returns `writeAReviewUri: null` when the gym has no place ID or Places yields nothing.
The app then omits the Google step entirely — this is a normal case, not an error, and
must not surface a message.

**Tests.**
- Backend: service returns cached URI without calling Places; calls Places on cache
  miss and persists; returns null for a gym with no `googlePlaceId`; returns null when
  Places errors (must not 500 the endpoint).
- Mobile: Google step hidden when rating is below 4; hidden when the URI is null;
  shown and launches the URI when both gates pass.

---

## F. App Store secondary category

No code. Once the 1.1 version exists in App Store Connect, set **Secondary category:
Health & Fitness** in App Information (currently empty; primary is Sports).

The dropdowns are locked until an editable version exists, and the change ships only
when 1.1 is approved. Health & Fitness adds a second browse surface and a second chart
to rank in; the competitor already has it.

Primary stays **Sports** — Health & Fitness is far more crowded, and Sports gives a
better shot at a chart position at current scale.

---

## Out of scope

- Changing the primary category.
- Displaying gym reviews in-app (the data is collected but not surfaced; a separate
  piece of work).
- Any restyling or navigation restructure beyond the single Favorites row.
- Android release. iOS 1.1 is the target; Android follows the existing pipeline
  unchanged.

## Risks

**Places API preview status.** `writeAReviewUri` is in preview. If it is withdrawn or
starts charging, the endpoint returns null and the app degrades to hiding the Google
step — no user-visible breakage. Acceptable.

**Review-gating optics.** Showing the Google hand-off only to 4+ raters is deliberate
and applies to *Google*, not to the in-app review, which is always recorded in full
regardless of score. The App Store prompt (item C) uses Apple's own
`requestReview()` and is not conditioned on sentiment, which keeps it within Apple's
rules.
