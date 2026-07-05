# Design — iOS Enablement + Search / Profile / Going Features

- **Date:** 2026-07-05
- **Status:** Approved (design), pending spec review
- **Author:** Davis Sylvester (with Claude)
- **Scope:** `apps/mobile` (Flutter), `apps/api` (Elysia/Bun), `packages/contract`, `apps/mobile/ios`

## Summary

Six independently shippable workstreams:

1. **iOS enablement** — configure the existing iOS Runner project so it builds and runs on a Mac (location + Auth0 URL scheme, Podfile floor, Auth0 iOS callbacks, build script, docs).
2. **Search GPS-first** — auto-capture GPS on load, clickable "City, ST" chip via a server reverse-geocode endpoint, raise the "within" max from 50 → 100 mi.
3. **Home GPS alignment** — home already GPS-loads; align permission handling and surface the resolved city label.
4. **Role switch** — a menu item to toggle between practitioner and gym owner.
5. **Profile editing** — add city/state, gender, and structured weight (raw value with lb⇄kg toggle) + an IBJJF division picker (gender- and gi/no-gi-aware), stored independently.
6. **"Going" / RSVP wiring** — surface the already-built RSVP backend end-to-end: an "I'm Going" toggle per session date, public count + attendee names, and an owner "expected" view.

## Decisions (resolved during brainstorming)

- **iOS build:** a Mac is available. Claude configures everything and provides exact Mac commands; the build itself cannot be verified from Windows.
- **Weight model:** raw weight value **and** a manually picked IBJJF division are stored **independently** (no auto-classification).
- **Division taxonomy:** full — collect **gender**, show the correct division set for gender + gi/no-gi context.
- **Weight units:** default **lb**, with a **kg toggle**; store canonical value + unit.
- **Going visibility:** everyone sees the count **and** the attendee names; RSVPs **also** feed the gym owner's expected-attendance view.
- **Reverse geocoding:** **server endpoint**, reusing the existing zipcodes dataset (nearest-entry lookup).

## Current-state findings

- RSVP backend already exists: `POST/DELETE /:id/rsvp` in `apps/api/src/routes/open-mat.routes.mts`, facade `rsvp/cancelRsvp/count/userIds` in `open-mat.facade.mts`, `RsvpRepository` keyed by `(openMatId, sessionDate, userId)` unique. **Not wired into the Flutter app.**
- Home (`discover_screen.dart`) already GPS-loads on `initState`.
- Search (`search_screen.dart`) is opt-in GPS (a "GPS" button); slider `max: 50`. No reverse geocoding anywhere.
- Role switching is backend-supported (`UpdateUserRequest.role`) with an auth `setRole()` method; the router swaps nav shell on `user.role`. No menu entry.
- `EditProfileScreen` edits displayName/bio/weight(free-text)/beltRank. No city/state; `User` schema lacks city/state/gender/structured weight.
- iOS Runner exists (bundle `com.davissylvester.bjjOpenMat`, uses `SceneDelegate`) but `Info.plist` has **no** location usage string and **no** Auth0 URL scheme.

---

## A. iOS build enablement

**Files / changes**
- `apps/mobile/ios/Runner/Info.plist`
  - Add `NSLocationWhenInUseUsageDescription` (geolocator returns null without it).
  - Add `CFBundleURLTypes` with URL scheme `com.davissylvester.bjjopenmat` (lowercased bundle id — auth0_flutter convention).
- `apps/mobile/ios/Podfile`
  - Pin `platform :ios, '13.0'` (auth0_flutter + geolocator floor).
- **Auth0** (existing Native app, per `mobile-auth0-native-login` memory): add iOS callback + logout URLs:
  - `com.davissylvester.bjjopenmat://<AUTH0_DOMAIN>/ios/com.davissylvester.bjjOpenMat/callback`
- `package.json`: add a `mobile:ios` script mirroring `mobile:apk` (bakes `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_AUDIENCE` via `--dart-define`).
- `docs/`: Mac build/run runbook (`pod install`, `flutter build ios`, simulator run, signing-team note).

**Verification:** performed by the user on the Mac. Claude cannot compile iOS on Windows; the doc lists the commands and expected output.

---

## B. Search: GPS-first, clickable city chip, 100 mi

**Files / changes**
- `apps/mobile/lib/features/search/screens/search_screen.dart`
  - Slider `max: 50` → `max: 100` in both `_buildSport` and `_buildGlass`.
  - In `initState`, auto-capture GPS and run the first query (mirror discover). Preserve the ZIP-precedence logic in `_rebuildQuery`.
  - Replace the static "GPS" button with a **chip that shows "City, ST"** once resolved; tapping it re-captures GPS + reverse-geocodes and repopulates location. Typing ZIP/city still overrides.
- **API:** new `GET /api/v1/geo/reverse?lat=&lng=` → `{ city, state, label }`.
  - New route file `apps/api/src/routes/geo.routes.mts`; extend `apps/api/src/services/geocoder.mts` with a `reverse(lat, lng)` that finds the nearest entry in the zipcodes dataset (haversine).
  - Register route in `app.mts`; add TypeBox response schema in contract.
- `apps/mobile/lib/core/api/endpoints.dart`: add `geoReverse`.
- Mobile location layer: add a repository method to call the reverse endpoint (keep `LocationService` device-only; geocoding goes through the API client).

**Error handling:** reverse-geocode failure or denied GPS → chip falls back to a neutral "Use my location" label; search still works via ZIP/text.

---

## C. Home screen GPS alignment

**Files / changes**
- `apps/mobile/lib/features/discover/screens/discover_screen.dart`
  - Keep existing `initState` GPS load; align permission handling with B and show the resolved "City, ST" label in the greeting header (reuse the reverse-geocode call).

Small change; already satisfies "use GPS for the initial list."

---

## D. Role switch menu item

**Files / changes**
- `apps/mobile/lib/features/settings/screens/settings_screen.dart`: add a **"Switch to Gym Owner / Practitioner"** item calling `ref.read(authStateProvider.notifier).setRole(...)`.
- `apps/mobile/lib/features/profile/screens/profile_screen.dart`: add a shortcut to the same action.
- Toggles `practitioner` ⇄ `gym_owner`. Router already redirects to the correct shell on role change (`_ScaffoldWithNavBar` / redirect in `router.dart`). Confirm a `context.go('/')` (or `/owner/dashboard`) after the role update so the shell rebuilds.

---

## E. Profile editing: city/state + weight

**Contract (`packages/contract`)**
- `schemas/user.mts` `User` + `schemas/requests/user-requests.mts` `UpdateUserRequest`: add
  - `city: string`, `state: string` (2-letter), `gender: Gender`,
  - `weightValue: number`, `weightUnit: 'lb' | 'kg'`,
  - `weightDivision: WeightDivision`, `weightDivisionContext: 'gi' | 'nogi'`.
- New enums: `enums/gender.mts` (`male | female`), `enums/weight-division.mts` (`rooster | light_feather | feather | light | middle | medium_heavy | heavy | super_heavy | ultra_heavy`).
- New shared reference `packages/contract/src/reference/ibjjf-weight-classes.mts`: the kg/lb upper-limit tables keyed by gender + context. Mirrored as a Dart constant in `apps/mobile/lib/core/reference/`.

**IBJJF upper limits (gi weights include kimono; kg / lb):**

Male Gi: Rooster 57.5/126.8 · L.Feather 64/141.1 · Feather 70/154.3 · Light 76/167.6 · Middle 82.3/181.4 · Med.Heavy 88.3/194.7 · Heavy 94.3/207.9 · Super Heavy 100.5/221.6 · Ultra ∞

Male No-Gi: Rooster 55.5/122.4 · L.Feather 61.5/135.6 · Feather 67.5/148.8 · Light 73.5/162.0 · Middle 79.5/175.3 · Med.Heavy 85.5/188.5 · Heavy 91.5/201.7 · Super Heavy 97.5/215.0 · Ultra ∞

Female Gi: Rooster 48.5/106.9 · L.Feather 53.5/117.9 · Feather 58.5/129.0 · Light 64/141.1 · Middle 69/152.1 · Med.Heavy 74/163.1 · Heavy 79.3/174.8 · Super Heavy ∞

Female No-Gi: Rooster 46.5/102.5 · L.Feather 51.5/113.5 · Feather 56.5/124.6 · Light 61.5/135.6 · Middle 66.5/146.6 · Med.Heavy 71.5/157.6 · Heavy 76.5/168.7 · Super Heavy ∞

**Mobile**
- `apps/mobile/lib/features/profile/screens/edit_profile_screen.dart`: add City + State inputs; a gender selector; a weight number field with lb⇄kg toggle (default lb); a division picker filtered by gender + a gi/no-gi toggle. Value and division stored independently — no auto-classify.
- `UserProfile` model + `updateProfile` payload extended with the new fields.

**API**
- `user.facade.mts` / `user.repository.mts`: persist the new fields (parse-on-read tolerant of missing legacy fields — Mongo `null != undefined` gotcha from `open-mat-checkin-form` memory).

**Migration note:** legacy `weight` (free-text string) stays for backward compat; new structured fields are additive and optional.

---

## F. "Going" / RSVP wiring

**`sessionDate` resolution:** one-off → `specificDate`; recurring → the **next occurrence** of the session weekday (computed client-side, sent to the API). Going is scoped to that date.

**Contract / API**
- Extend the open-mat **detail** response (`schemas/open-mat-detail.mts`) with `goingCount: number`, `amIGoing: boolean`, and `going: AttendeeSummary[]` (`userId, displayName, beltRank?, avatarUrl?`) for the resolved session date.
- Add `GET /api/v1/open-mats/:id/rsvps?sessionDate=` returning `AttendeeSummary[]` (facade already has `userIds`; join to user summaries).
- Facade: given `userIds`, hydrate to `AttendeeSummary` via the user repository.

**Mobile**
- `endpoints.dart`: add `openMatRsvp(id)` and `openMatRsvps(id)`.
- Open-mat repository/model: add `rsvp(sessionDate)`, `cancelRsvp(sessionDate)`, `attendees(sessionDate)`; extend `OpenMat`/detail model with `goingCount`, `amIGoing`, `going`.
- `open_mat_detail_screen.dart`: add an **"I'm Going" toggle** (distinct from Check In) in both `_SportDetail` and `_GlassDetail`, showing count + attendee avatars/names; tapping a name → `/user/:id` public profile. Optimistic toggle with rollback on error.

**Owner side**
- `apps/mobile/lib/features/admin/screens/attendance_screen.dart` (and/or `session_admin_screen.dart`): add an **"Expected" (RSVP) list/count** section alongside actual check-ins, sourced from the rsvps endpoint.

**Out of scope (noted, not built now):** RSVP push/notifications (the `notifyRsvp` setting and `rsvp` notification type exist but wiring notifications is deferred).

---

## Build order (independently shippable)

1. **A** — iOS enablement (unblocks iOS testing).
2. **E + F schema** — contract foundation (new enums, user fields, going in detail).
3. **E** — profile editing.
4. **D** — role switch.
5. **B + C** — search GPS-first + reverse geocode + home alignment.
6. **F** — going wiring (mobile + owner).

## Testing / verification

- **API:** `bun test` for geocoder reverse, rsvp attendee hydration, user update with new fields; boot test still green. Health endpoints remain `/health` + `/ready`.
- **Contract:** type-check + lint clean; derived `Static` types compile.
- **Mobile:** widget/unit tests where practical; `flutter analyze` clean. E2E via `flutter drive` per the `open-mat-search-filters` memory pattern for the search and going flows.
- **iOS:** user-run on Mac (`pod install`, `flutter build ios`, simulator run) — Claude cannot verify from Windows.

## Risks / open items

- Reverse geocoding via zipcodes dataset is approximate (nearest ZIP centroid → city/state); acceptable for a display label.
- iOS build depends on the user's Mac + Apple signing; not verifiable here.
- `sessionDate` next-occurrence math for recurring sessions must match how the API stores/derives session dates elsewhere — verify against `open-mat.repository.mts` during implementation.
