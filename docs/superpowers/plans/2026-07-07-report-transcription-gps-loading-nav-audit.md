# Report Transcription + GPS Loading + Nav Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make voice transcription on the Report page work, add GPS-capture loading indicators shared across the Home and Find pages (fetch once, reuse), and audit/fix every button and back-arrow.

**Architecture:** Three independent parts. (A) API: enable Whisper by provisioning `OPENAI_API_KEY`; client already has a `transcribing` state — refine the error copy for the "not configured" case. (B) Introduce a single shared `locationController` (Riverpod `Notifier`) that owns the device location + reverse-geocoded label + a status enum; Home and Find both read it and trigger a fetch only when not already resolved/in-flight, and bind loading UI to its status. (C) Nav audit: code-review `go` vs `push` and back handlers, fix, then confirm on the emulator.

**Tech Stack:** Flutter (Riverpod 3, go_router), Elysia/Bun API, OpenAI Whisper (`/v1/audio/translations`), geolocator, AWS Secrets Manager (`bjj-open-mat/app`).

---

## Part A — Fix voice transcription

Root cause (verified by reading `apps/api/src/container.mts:73` + `report.facade.mts:60`): the container builds `transcription` only when `env.openaiApiKey` is set; otherwise `transcribe()` throws `AppError("service_unavailable", "Voice transcription is not configured")`. The key is absent from `apps/api/.env` and the prod secret, so every transcribe call fails → the client shows "Could not transcribe your recording." (`report_screen.dart:199`).

### Task A1: Provision `OPENAI_API_KEY` (local + prod)

**Files:**
- Modify: `apps/api/.env` (local, gitignored)
- External: AWS Secrets Manager `bjj-open-mat/app`

- [ ] **Step 1: Add the key locally.** Append `OPENAI_API_KEY=sk-...` (user-supplied) to `apps/api/.env`. Confirm `env.mts:22` already declares `OPENAI_API_KEY: t.Optional(t.String())` and maps it at `env.mts:60` (`openaiApiKey`).

- [ ] **Step 2: Boot the local API and confirm transcription is enabled.**

Run (kill any stale server on 3100 first — see memory `windows-bun-server-port-collision`):
```
cd apps/api && bun src/index.mts
```
Expected: server starts on `:3100` with no "transcription disabled" path; `container.mts` builds `WhisperTranscriptionService`.

- [ ] **Step 3: Add the key to the prod secret** (user action; the API picks it up on next cold start):
```
aws secretsmanager get-secret-value --secret-id bjj-open-mat/app --region us-east-1 --query SecretString --output text
# merge OPENAI_API_KEY into the JSON, then:
aws secretsmanager put-secret-value --secret-id bjj-open-mat/app --region us-east-1 --secret-string '<merged-json>'
```
Note in the plan output that this requires valid AWS credentials (the assistant session's were invalid; user runs this or provides creds).

- [ ] **Step 4: Verify end-to-end** once deployed: record on the Report page → transcript appears in the description field. (Manual, after A1/Part-C emulator pass.)

### Task A2: Distinguish "not configured" from a real transcription failure (client polish)

**Files:**
- Modify: `apps/mobile/lib/features/report/screens/report_screen.dart` (the transcribe `catch` at ~line 195-200)
- Test: `apps/mobile/test/features/report_screen_audio_test.dart`

- [ ] **Step 1: Write a failing test** asserting that a `503 service_unavailable` from transcribe surfaces a "voice isn't available right now" message (distinct from the generic failure copy), using the existing `transcribeForTest` seam (`report_screen.dart:~220`) with a fake repo that throws `ApiException` with status 503.

```dart
// in report_screen_audio_test.dart
testWidgets('shows a config-specific message when transcription is unavailable (503)', (tester) async {
  // pump ReportScreen with a fake ReportAudioRepository whose transcribe()
  // throws ApiException(statusCode: 503); drive transcribeForTest(); expect
  // find.textContaining('not available') and that typing is still possible.
});
```

- [ ] **Step 2: Run it — expect FAIL** (current code shows the single generic string for all errors).
Run: `cd apps/mobile && flutter test test/features/report_screen_audio_test.dart`

- [ ] **Step 3: Implement.** In the transcribe `catch`, branch on `ApiException.statusCode == 503` to set `_recordError = 'Voice transcription isn't available right now — you can type your description.'`; keep the existing copy for other errors. Preserve the `RecordState.transcribing` spinner already shown while awaiting.

- [ ] **Step 4: Run tests — expect PASS.** Then `flutter analyze lib/features/report`.

- [ ] **Step 5: Commit.**
```
git commit -m "fix(api,mobile): enable Whisper transcription (OPENAI_API_KEY) + clearer unavailable message"
```

---

## Part B — Shared GPS controller + loading indicators

Today Home (`discover_screen.dart:35 _captureLocation`) and Find (`search_screen.dart:208 _useGps`) each call `locationServiceProvider.current()` independently on init — GPS is fetched twice and neither shows a "getting location" indicator. Introduce one shared, cached controller.

### Task B1: Create the shared `locationController`

**Files:**
- Create: `apps/mobile/lib/core/location/location_controller.dart`
- Test: `apps/mobile/test/core/location_controller_test.dart`

- [ ] **Step 1: Write the failing test** with a fake `LocationService` + fake `GeoRepository`:
  - `ensure()` fetches once, sets status `ready` with coords + label; a second `ensure()` does NOT call the service again (cached).
  - When the service returns null, status becomes `unavailable` and `ensure()` may retry.
  - `refresh()` always re-fetches.

```dart
// location_controller_test.dart — override locationServiceProvider + geoRepositoryProvider
// with fakes that count calls; assert call-count 1 after two ensure() calls.
```

- [ ] **Step 2: Run — expect FAIL** (file doesn't exist).
Run: `cd apps/mobile && flutter test test/core/location_controller_test.dart`

- [ ] **Step 3: Implement the controller.**

```dart
// apps/mobile/lib/core/location/location_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'geo_repository.dart';
import 'location_service.dart';

enum LocationStatus { idle, loading, ready, unavailable }

class LocationState {
  final LocationStatus status;
  final double? lat;
  final double? lng;
  final String? label;
  const LocationState({this.status = LocationStatus.idle, this.lat, this.lng, this.label});
  bool get hasCoords => lat != null && lng != null;
  LocationState copyWith({LocationStatus? status, double? lat, double? lng, String? label}) =>
      LocationState(status: status ?? this.status, lat: lat ?? this.lat, lng: lng ?? this.lng, label: label ?? this.label);
}

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// Fetch coords once. No-op if already loading or already resolved.
  Future<void> ensure() async {
    if (state.status == LocationStatus.loading || state.status == LocationStatus.ready) return;
    await _fetch();
  }

  /// Force a fresh capture (GPS chip / map-pin tap).
  Future<void> refresh() async {
    if (state.status == LocationStatus.loading) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    state = state.copyWith(status: LocationStatus.loading);
    final loc = await ref.read(locationServiceProvider).current();
    if (loc == null) {
      state = const LocationState(status: LocationStatus.unavailable);
      return;
    }
    state = LocationState(status: LocationStatus.ready, lat: loc.latitude, lng: loc.longitude);
    final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
    if (rg != null) state = state.copyWith(label: rg.label);
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);
```

- [ ] **Step 4: Run tests — expect PASS.** Then `flutter analyze lib/core/location`.

- [ ] **Step 5: Commit.** `git commit -m "feat(mobile): shared location controller (fetch-once, cached coords + label + status)"`

### Task B2: Home (Discover) uses the shared controller + loading indicator

**Files:**
- Modify: `apps/mobile/lib/features/discover/screens/discover_screen.dart`

- [ ] **Step 1:** In `initState`, call `ref.read(locationControllerProvider.notifier).ensure()` (post-frame) instead of the local `_captureLocation`. Remove the local `_locationLabel`/`_query`-from-GPS duplication: watch `locationControllerProvider` in `build`, derive `NearbyQuery(lat, lng)` when `hasCoords`, and use `state.label` for the header.

- [ ] **Step 2:** Show a loading indicator while `status == loading`: replace the header location text with a small inline spinner + "Locating…" (e.g., a 12px `CircularProgressIndicator` next to the "Find your roll" subtitle). When `unavailable`, show "Near you" (current fallback).

- [ ] **Step 3:** Run: `flutter analyze lib/features/discover` and `flutter test` (ensure discover-related tests still pass). Commit.

### Task B3: Find (Search) uses the shared controller + loading indicator

**Files:**
- Modify: `apps/mobile/lib/features/search/screens/search_screen.dart`
- Test: `apps/mobile/test/features/search_screen_test.dart` (keep passing; adjust fake if needed)

- [ ] **Step 1:** Replace `_useGps()`'s direct `locationServiceProvider.current()` call with `ref.read(locationControllerProvider.notifier).refresh()`; on `initState` call `.ensure()` (reuses Home's fetch if already resolved). Derive `_gpsLat/_gpsLng/_locationLabel` from `locationControllerProvider` (watch it), keeping the ZIP-precedence rule in `_rebuildQuery`.

- [ ] **Step 2:** Bind the GPS chip + top-right map-pin to `refresh()`, and show a spinner inside the GPS chip while `status == loading` (swap the `locateFixed` icon for a 12px `CircularProgressIndicator`). Keep the existing `SnackBar` on `unavailable`.

- [ ] **Step 3:** Run: `flutter analyze lib/features/search` and `flutter test test/features/search_screen_test.dart` (update the fake `LocationService` wiring to the controller if the test overrides it). Commit.

---

## Part C — Button & back-arrow audit (code review + emulator)

### Task C1: Code-review navigation and fix

**Files:** all screens under `apps/mobile/lib/features/**/screens/`, plus `apps/mobile/lib/app/router.dart`.

- [ ] **Step 1: Inventory.** Grep every `context.go`, `context.push`, `context.pop`, `Navigator.of(context).maybePop/pop`, and every `onTap`/`onPressed` across `features/**`. Produce a table: screen → action → target route → nav method.

- [ ] **Step 2: Flag the known smell.** Detail screens are pushed via `context.go('/open-mat/:id')` (e.g. `discover_screen.dart:223`, `search_screen.dart`) but their back affordance calls `context.pop()`/`maybePop()`. `go` replaces rather than stacks, so back can misbehave. For detail/sub-screens that should return to their origin, switch the navigation to `context.push(...)` (keeps a back entry), or ensure the back handler uses `context.go` to an explicit parent. Fix each mismatch.

- [ ] **Step 3: Verify each back arrow has a valid target** (no dead `maybePop` on a route reached via `go`). Add a `context.canPop() ? context.pop() : context.go('<parent>')` guard where a screen can be entered both ways.

- [ ] **Step 4: Add widget tests** for the highest-risk flows (open-mat detail back → returns to list; edit profile back; owner sub-screens back) using a test `GoRouter`.

- [ ] **Step 5:** `flutter analyze` + `flutter test`; commit per fixed cluster.

### Task C2: Emulator walkthrough

- [ ] **Step 1:** Boot the Pixel emulator; start the local API (`bun src/index.mts`) with `OPENAI_API_KEY` set; build+install a debug APK with `--dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<local secret>` `--dart-define=API_BASE_URL=http://10.0.2.2:3100` (see memory `android-emulator-run`).

- [ ] **Step 2:** Walk every tab and sub-screen (both practitioner and owner shells): tap each button and every back arrow. Record any that dead-end or don't respond.

- [ ] **Step 3:** Screenshot the Report record→transcribe flow (should now transcribe), and the Home/Find GPS loading indicator.

- [ ] **Step 4:** Fix anything found in C2 (loop back through C1's method), re-verify.

---

## Rollout

- Parts A (API half) require a redeploy (auto-deploys on push to `main`) + the secret update. Parts B/C are client-only → new mobile build (bump `pubspec.yaml`, currently `0.1.0+13` → `+14`), deliver `.aab`, upload to Play Internal testing.
- Update `docs/TODO.md`: mark "Activate Report→GitHub / transcription" progress and note the OpenAI key is provisioned.

## Self-review notes
- Types consistent: `LocationState`/`LocationStatus` used identically in B1–B3; `NearbyQuery`/`SearchQuery` unchanged.
- No placeholders: controller code is complete; test bodies describe exact assertions.
- Scope: three parts are independent and individually shippable; Part A's client polish is optional if the key alone resolves it.
