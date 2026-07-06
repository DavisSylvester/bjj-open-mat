# Attendee Profile 404 Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or execute inline. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Tapping an attendee on an open-mat "Going" grid never throws a raw `DioException` 404; attendees without a real profile are simply not tappable, and the public-profile screen degrades gracefully.

**Architecture:** Two layers. (1) The attendees API tells the client which attendees actually have a user document (`hasProfile`). (2) The mobile grid only makes real-profile attendees tappable, and the public-profile screen shows a friendly empty-state instead of dumping the exception — defense-in-depth so a stale/deleted id can never surface a raw error.

**Tech Stack:** Elysia + TypeBox (`@bjj/contract`), Flutter (Riverpod, go_router), Dio.

## Root Cause

`GET /api/v1/open-mats/:id/attendees` (`open-mat.routes.mts:139-152`) hydrates each RSVP userId to a profile but **intentionally keeps attendees whose user doc is missing** (fallback `"BJJ Practitioner"`, white belt) so the going-count doesn't under-report. It still returns their `userId`. `going_section.dart:148` makes **every** attendee tappable → `context.go('/user/<userId>')` → `publicProfileProvider` → `GET /api/v1/users/<userId>` → `userFacade.getById` throws `AppError("not_found")` → **404** → `PublicProfileScreen`'s `error:` branch renders `ErrorState(message: e.toString())` = the raw DioException text the user sees. Confirmed live: `GET /api/v1/users/does-not-exist` → 404; the bypass user's own id resolves (200), so tapping *yourself* works — only placeholder attendees break.

## Global Constraints

- TypeBox only (no Zod); schema-first with `Static<>`. Strict TS, explicit types/returns, no `any`.
- API health endpoints unchanged. Winston logging on API. Conventional commits, no Co-Authored-By.
- Do not change `getById`'s correct 404-on-missing behavior.
- `Attendee` is a shared contract; a client built against the old shape must still parse (make the new field optional-tolerant on the client).

---

### Task 1: API — add `hasProfile` to the attendee payload

**Files:**
- Modify: `packages/contract/src/schemas/attendee.mts`
- Modify: `apps/api/src/routes/open-mat.routes.mts:139-152`
- Test: `apps/api/test/` (attendees/open-mat route test if present; else add a focused assertion)

**Interfaces:**
- Produces: `Attendee.hasProfile: boolean` — `true` when the RSVP's user document resolved, `false` for placeholder attendees.

- [ ] **Step 1:** Add `hasProfile: t.Boolean()` to the `Attendee` TypeBox object in `attendee.mts` (after `rsvpAt`). Keep `$id: "Attendee"`.

- [ ] **Step 2:** In the `/:id/attendees` handler, compute the profile once and set the flag:
```ts
const attendees = await Promise.all(
  ids.map(async (uid) => {
    const u = await userFacade.getById(uid).catch(() => null);
    return {
      userId: uid,
      name: u?.displayName ?? "BJJ Practitioner",
      beltRank: u?.beltRank ?? "white",
      beltStripes: u?.beltStripes,
      skillLevel: "all" as const,
      avatarUrl: u?.avatarUrl,
      rsvpAt: "",
      hasProfile: u !== null,
    };
  }),
);
```

- [ ] **Step 3:** Run `bun test` in `apps/api`. Expected: PASS (update any fake/fixture that asserts the exact attendee shape to include `hasProfile`).

- [ ] **Step 4:** Manually verify against the running API: an attendee with a real user doc returns `hasProfile:true`; a placeholder returns `hasProfile:false`. (Create a placeholder by RSVPing a non-existent userId via the repository, or assert the fallback path.)

- [ ] **Step 5:** Commit `feat(api): attendees report hasProfile so clients can gate profile links`.

---

### Task 2: Mobile — gate the tap and harden the profile screen

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/models/attendee.dart`
- Modify: `apps/mobile/lib/features/open_mats/widgets/going_section.dart:142-160`
- Modify: `apps/mobile/lib/features/profile/screens/public_profile_screen.dart`

**Interfaces:**
- Consumes: `Attendee.hasProfile` from Task 1.

- [ ] **Step 1:** In `attendee.dart`, add `final bool hasProfile;` (constructor default `false`) and parse `hasProfile: json['hasProfile'] as bool? ?? false` in `fromJson`. Default `false` keeps old payloads safe (a missing flag = not tappable, which is the safe direction).

- [ ] **Step 2:** In `going_section.dart` `_AttendeeCell`, only attach the tap when the profile exists:
```dart
onTap: attendee.hasProfile ? () => context.go('/user/${attendee.userId}') : null,
```
Wrap so a `null` onTap renders a non-interactive cell (GestureDetector with null onTap is inert; if using InkWell keep it — null onTap disables ripple). No visual regression required, but a placeholder cell must not navigate.

- [ ] **Step 3:** In `public_profile_screen.dart`, replace `error: (e, _) => ErrorState(message: e.toString())` with a friendly, non-technical message that special-cases 404:
```dart
error: (e, _) {
  final is404 = e is DioException && e.response?.statusCode == 404;
  return ErrorState(
    message: is404
        ? "This profile isn't available."
        : "Couldn't load this profile. Please try again.",
    onRetry: () => ref.invalidate(publicProfileProvider(userId)),
  );
},
```
Add `import 'package:dio/dio.dart';`.

- [ ] **Step 4:** `flutter analyze lib` — expected: No issues found.

- [ ] **Step 5:** Commit `fix(mobile): don't link profile-less attendees; friendly public-profile error`.

---

### Task 3: Verify end-to-end on the iOS simulator

**Files:** none (verification only)

- [ ] **Step 1:** Ensure local API (`:3100`) + Mongo are up; run the app with DEV_BYPASS.
- [ ] **Step 2:** Open a session with attendees. Confirm placeholder attendees ("BJJ Practitioner") are **not** tappable — tapping them does nothing (no navigation, no error).
- [ ] **Step 3:** Tap an attendee that has a real profile → the public-profile screen loads (200), no exception.
- [ ] **Step 4:** As a safety check, force the error path (e.g., navigate to `/user/does-not-exist`) and confirm the screen shows "This profile isn't available." with a Try Again button — **never** a raw `DioException`.
- [ ] **Step 5:** Screenshot the placeholder-grid and the graceful-error states for the record.

## Self-Review

- Spec coverage: root cause (placeholder attendees + ungated tap + raw error) addressed by Task 1 (signal) + Task 2 (gate + graceful) + Task 3 (verify). ✔
- The `hasProfile` default of `false` on the client is the safe direction (unknown → not tappable). ✔
- `getById`'s 404 behavior is unchanged (correct REST). ✔
- No `any`; TypeBox for the schema; explicit Dart types. ✔
