# Mobile 1.1 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship BJJ OPEN MAT 1.1 — reach the orphaned Favorites screen, fix the dead-looking Join button, prompt for App Store ratings, and hand users off to Google Maps to review a gym.

**Architecture:** Four independent mobile changes plus one backend endpoint. The Google hand-off is the only cross-stack item: a new `GET /api/v1/gyms/:id/review-link` returns a Google Maps "write a review" URI (fetched once from Places API and cached on the gym document), which the mobile review flow opens externally. Google forbids programmatic review submission, so the app can only hand off.

**Tech Stack:** Flutter/Dart + Riverpod + go_router (mobile); Bun + Elysia + TypeBox + MongoDB (API); `in_app_review` and existing `url_launcher` packages.

**Spec:** `docs/superpowers/specs/2026-07-29-mobile-1-1-release-design.md`

**Branch:** `feature/mobile-1-1-release` (already created; spec and item D fixes already committed)

## Global Constraints

- TypeScript is strict. Never use `any`. Explicit return types and access modifiers on all functions and methods. Explicit types on all variables.
- Validation uses TypeBox (`t` from `elysia` for routes). Never Zod.
- API layering: router handles HTTP only → facade holds business logic → repository owns all data access. Routers never touch the data layer.
- All services and config resolve through the DI container (`apps/api/src/container.mts`). No `new` inside facades or routes.
- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`). **Never add Co-Authored-By lines.**
- Run `bunx eslint --fix` on changed `.mts` files and `flutter analyze` on changed Dart before each commit. Both must be clean.
- Mobile tests: `flutter test`. API tests: `bun test`. Full suite must pass before each commit.
- Baseline at plan time: **197 Flutter tests passing.** Every task should raise this number, never lower it.
- "Review" means *gym check-in review*. The App Store prompt is named `AppRatingService` / `app_rating_prompt` and is never called "review".
- Never log or hardcode the Places API key. It comes from env through DI.

---

### Task 1: Favorites entry point

`FavoritesScreen` is routed at `/profile/favorites` but nothing navigates to it. The heart toggle on gym detail works and persists, so users build a favorites list they can never see.

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart:185`
- Test: `apps/mobile/test/features/profile_favorites_row_test.dart` (create)

**Interfaces:**
- Consumes: existing route `/profile/favorites`, `FavoritesScreen`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Write the failing test**

`ProfileScreen` needs auth, stats, and network to render, so a full widget pump is
disproportionate for a navigation row. Assert the wiring at the source level instead —
this catches the actual defect (a row that exists but points nowhere, or no row at all).

Create `apps/mobile/test/features/profile_favorites_row_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile settings wires a Favorites row to /profile/favorites', () {
    final source = File('lib/features/profile/screens/profile_screen.dart').readAsStringSync();

    expect(source, contains("Text('Favorites'"),
        reason: 'FavoritesScreen is unreachable without a row in the settings card');
    expect(source, contains("context.push('/profile/favorites')"),
        reason: 'the row must navigate to the existing favorites route');
  });

  test('the favorites route it points at still exists', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains("path: 'favorites'"));
    expect(router, contains('FavoritesScreen'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/features/profile_favorites_row_test.dart`
Expected: FAIL on the first test — `profile_screen.dart` contains neither string. The
second test passes already (the route exists; it is pinned so a future cleanup does not
silently delete the destination).

- [ ] **Step 3: Add the row**

In `apps/mobile/lib/features/profile/screens/profile_screen.dart`, inside the settings `Column(children: [...])`, insert **above** the existing "My Gyms" `ListTile` (currently at line 185):

```dart
                  ListTile(
                    leading: Icon(LucideIcons.heart, color: t.muted),
                    title: Text('Favorites', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.push('/profile/favorites'),
                  ),
                  Divider(height: 1, color: t.border),
```

- [ ] **Step 4: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass (199 total).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/profile/screens/profile_screen.dart apps/mobile/test/features/profile_favorites_row_test.dart
git commit -m "fix(mobile): add Favorites row to profile settings

FavoritesScreen was routed at /profile/favorites but unreachable —
users could favorite gyms from the heart toggle and never see the
list."
```

---

### Task 2: Join button sign-in gating

`JoinGymButton` passes `onTap: null` when signed out, so Flutter greys the button while the label still reads "Join". The roster-error branch renders identically. Two distinct states, one silent dead appearance.

**Files:**
- Modify: `apps/mobile/lib/features/membership/widgets/join_gym_button.dart`
- Modify: `apps/mobile/test/membership/join_gym_button_test.dart:169` (existing test asserts the old disabled behaviour and **will** fail)

**Interfaces:**
- Consumes: `currentUserIdProvider`, `rosterProvider(gymId)`, `membershipRepositoryProvider` (all existing in `join_gym_button.dart` / `membership_repository.dart`)
- Produces: `JoinButtonState` enum — `signedOut`, `error`, `member`, `nonMember` — used only within this file

- [ ] **Step 1: Update the existing test that pins the old behaviour**

In `apps/mobile/test/membership/join_gym_button_test.dart`, replace the test at line 169 (`'Join button is disabled when not authenticated'`) with:

```dart
    testWidgets('shows sign-in prompt when not authenticated', (tester) async {
      await pumpButton(tester, userId: null, roster: const []);
      expect(find.text('Sign in to join'), findsOneWidget);
      expect(find.text('Join'), findsNothing);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull, reason: 'must be tappable so the user can reach login');
    });
```

Note: `pumpButton` is the existing helper in that file — reuse it exactly as the other tests do; do not invent a new one.

- [ ] **Step 2: Add the error-state test**

Append to the same file, inside the same `group`:

```dart
    testWidgets('shows Retry when the roster fails to load', (tester) async {
      await pumpButtonWithRosterError(tester, userId: 'u1');
      expect(find.text('Retry'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });
```

Add the helper next to the existing `pumpButton`, mirroring its structure but overriding the roster provider with a failing future:

```dart
Future<void> pumpButtonWithRosterError(WidgetTester tester, {required String? userId}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        rosterProvider(kGymId).overrideWith((ref) => Future<List<RosterMember>>.error('boom')),
      ],
      child: MaterialApp(theme: appTheme(), home: const Scaffold(body: JoinGymButton(gymId: kGymId))),
    ),
  );
  await tester.pump();
}
```

Match the existing file's constant name for the gym id and its theme helper — read the top of the file and reuse what is already there.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd apps/mobile && flutter test test/membership/join_gym_button_test.dart`
Expected: FAIL — "Sign in to join" and "Retry" are not rendered.

- [ ] **Step 4: Implement the three states**

In `apps/mobile/lib/features/membership/widgets/join_gym_button.dart`, add above `class JoinGymButton`:

```dart
/// The mutually exclusive states the action button can be in. Modelled as an
/// enum rather than a `disabled` flag so "signed out" and "roster failed"
/// cannot collapse into the same silent grey button again.
enum JoinButtonState { signedOut, error, member, nonMember }
```

Replace the `build` method's `rosterAsync.when(...)` with:

```dart
  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final myId = ref.watch(currentUserIdProvider);
    final isAuthed = myId != null;
    final AppTokens? t = Theme.of(context).extension<AppTokens>();

    return rosterAsync.when(
      loading: () => _MembershipLayout(
        memberCount: 0,
        state: JoinButtonState.nonMember,
        loading: true,
        onTap: null,
        t: t,
      ),
      error: (err, st) => _MembershipLayout(
        memberCount: 0,
        state: JoinButtonState.error,
        loading: false,
        onTap: () => ref.invalidate(rosterProvider(widget.gymId)),
        t: t,
      ),
      data: (roster) {
        final count = roster.length;
        if (!isAuthed) {
          return _MembershipLayout(
            memberCount: count,
            state: JoinButtonState.signedOut,
            loading: false,
            onTap: () => context.push('/login'),
            t: t,
          );
        }
        final isMember = roster.any((m) => m.userId == myId);
        return _MembershipLayout(
          memberCount: count,
          state: isMember ? JoinButtonState.member : JoinButtonState.nonMember,
          loading: _busy,
          onTap: _busy ? null : () => _toggle(isMember: isMember),
          t: t,
        );
      },
    );
  }
```

Add `import 'package:go_router/go_router.dart';` to the imports.

Replace `_MembershipLayout`'s fields and `build` with:

```dart
class _MembershipLayout extends StatelessWidget {
  final int memberCount;
  final JoinButtonState state;
  final bool loading;
  final VoidCallback? onTap;
  final AppTokens? t;

  const _MembershipLayout({
    required this.memberCount,
    required this.state,
    required this.loading,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final label = memberCount == 1 ? '1 member' : '$memberCount members';
    final isMember = state == JoinButtonState.member;
    final primaryColor = t?.primary ?? Theme.of(context).colorScheme.primary;

    final String buttonLabel;
    final IconData icon;
    switch (state) {
      case JoinButtonState.signedOut:
        buttonLabel = 'Sign in to join';
        icon = LucideIcons.logIn;
      case JoinButtonState.error:
        buttonLabel = 'Retry';
        icon = LucideIcons.refreshCw;
      case JoinButtonState.member:
        buttonLabel = 'Leave';
        icon = LucideIcons.logOut;
      case JoinButtonState.nonMember:
        buttonLabel = 'Join';
        icon = LucideIcons.userPlus;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.users, size: 14, color: t?.muted ?? Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: (t?.miniStyle ?? Theme.of(context).textTheme.bodySmall)
                  ?.copyWith(color: t?.muted ?? Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: loading ? null : onTap,
          icon: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isMember ? primaryColor : Colors.white,
                  ),
                )
              : Icon(icon, size: 16),
          label: Text(buttonLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: isMember ? Colors.transparent : primaryColor,
            foregroundColor: isMember ? primaryColor : Colors.white,
            side: isMember ? BorderSide(color: primaryColor) : null,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: isMember ? 0 : 2,
          ),
        ),
      ],
    );
  }
}
```

Update the class doc comment on `JoinGymButton` to describe the four states instead of "disabled when no user is authenticated".

- [ ] **Step 5: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass (200 total). If `LucideIcons.logIn` or `refreshCw` do not exist, run `grep -o 'logIn\|refreshCw\|login\|refresh' ~/.pub-cache/hosted/pub.dev/lucide_icons-*/lib/lucide_icons.dart | sort -u` and use the actual names.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/membership/widgets/join_gym_button.dart apps/mobile/test/membership/join_gym_button_test.dart
git commit -m "fix(mobile): distinguish signed-out and error states on Join button

Signed out, the button greyed with the label still reading Join and no
explanation — identical to how it looked when the roster request failed.
Model the states explicitly: sign-in prompt, retry, join, leave."
```

---

### Task 3: App Store rating prompt

The listing has zero ratings and Apple hides the star display until a minimum accumulates.

**Files:**
- Modify: `apps/mobile/pubspec.yaml` (add `in_app_review`)
- Create: `apps/mobile/lib/core/rating/app_rating_service.dart`
- Modify: `apps/mobile/lib/features/checkins/screens/checkin_success_screen.dart`
- Test: `apps/mobile/test/app_rating_prompt_test.dart` (create)

**Interfaces:**
- Consumes: `myStatsProvider` from `apps/mobile/lib/features/profile/data/profile_stats.dart`, which returns the record `({int checkIns, int reviews, int gyms})`
- Produces:
  - `bool shouldPromptForRating({required int checkInCount, required bool alreadyPrompted})`
  - `class AppRatingService` with `Future<void> maybePrompt(int checkInCount)`
  - `final appRatingServiceProvider = Provider<AppRatingService>(...)`

- [ ] **Step 1: Add the dependency**

In `apps/mobile/pubspec.yaml`, under `dependencies:` alongside `url_launcher`:

```yaml
  in_app_review: ^2.0.10
```

Run: `cd apps/mobile && flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `apps/mobile/test/app_rating_prompt_test.dart`:

```dart
import 'package:bjj_open_mat/core/rating/app_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldPromptForRating', () {
    test('does not prompt below the third check-in', () {
      expect(shouldPromptForRating(checkInCount: 0, alreadyPrompted: false), isFalse);
      expect(shouldPromptForRating(checkInCount: 1, alreadyPrompted: false), isFalse);
      expect(shouldPromptForRating(checkInCount: 2, alreadyPrompted: false), isFalse);
    });

    test('prompts at exactly the third check-in', () {
      expect(shouldPromptForRating(checkInCount: 3, alreadyPrompted: false), isTrue);
    });

    test('still prompts beyond three if never prompted before', () {
      expect(shouldPromptForRating(checkInCount: 9, alreadyPrompted: false), isTrue);
    });

    test('never prompts twice', () {
      expect(shouldPromptForRating(checkInCount: 3, alreadyPrompted: true), isFalse);
      expect(shouldPromptForRating(checkInCount: 99, alreadyPrompted: true), isFalse);
    });

    test('treats a negative or nonsense count as not eligible', () {
      expect(shouldPromptForRating(checkInCount: -1, alreadyPrompted: false), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/app_rating_prompt_test.dart`
Expected: FAIL — `app_rating_service.dart` does not exist.

- [ ] **Step 4: Implement the service**

Create `apps/mobile/lib/core/rating/app_rating_service.dart`:

```dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';

/// Number of check-ins that marks a user as genuinely engaged.
const int kRatingPromptCheckInThreshold = 3;

/// Secure-storage key recording that the system prompt has been requested.
const String kRatingPromptedKey = 'app_rating_prompted';

/// Whether the App Store rating prompt should be requested now.
///
/// Apple caps the system prompt at three presentations per user per year, so
/// it must never be spent on launch or first run. Gate it on demonstrated
/// usage instead, and only ever ask once.
bool shouldPromptForRating({required int checkInCount, required bool alreadyPrompted}) {
  if (alreadyPrompted) return false;
  return checkInCount >= kRatingPromptCheckInThreshold;
}

/// Requests the native App Store rating prompt at an appropriate moment.
class AppRatingService {
  AppRatingService({InAppReview? inAppReview, FlutterSecureStorage? storage})
      : _inAppReview = inAppReview ?? InAppReview.instance,
        _storage = storage ?? const FlutterSecureStorage();

  final InAppReview _inAppReview;
  final FlutterSecureStorage _storage;

  /// Prompts once the user has enough check-ins, then records that it fired.
  ///
  /// `requestReview()` intentionally gives no success signal — iOS may show
  /// nothing at all. Never branch on the outcome and never claim to the user
  /// that a review was left.
  Future<void> maybePrompt(int checkInCount) async {
    try {
      final alreadyPrompted = await _storage.read(key: kRatingPromptedKey) != null;
      if (!shouldPromptForRating(checkInCount: checkInCount, alreadyPrompted: alreadyPrompted)) {
        return;
      }
      if (!await _inAppReview.isAvailable()) return;
      await _storage.write(key: kRatingPromptedKey, value: 'true');
      await _inAppReview.requestReview();
    } catch (e) {
      // A rating prompt is never worth interrupting the user for.
      debugPrint('rating prompt skipped: $e');
    }
  }
}

final appRatingServiceProvider = Provider<AppRatingService>((ref) => AppRatingService());
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd apps/mobile && flutter test test/app_rating_prompt_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Wire it into the check-in success screen**

In `apps/mobile/lib/features/checkins/screens/checkin_success_screen.dart`, inside `initState` (currently at line 20), after `super.initState()`:

```dart
    // Fire after the frame so the success screen is on-screen first; a prompt
    // over a half-built screen reads as a glitch.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stats = await ref.read(myStatsProvider.future);
      if (!mounted) return;
      await ref.read(appRatingServiceProvider).maybePrompt(stats.checkIns);
    });
```

Add imports:

```dart
import '../../../core/rating/app_rating_service.dart';
import '../../profile/data/profile_stats.dart';
```

If the screen is not already a `ConsumerStatefulWidget`, convert it — check the class declaration first and match the pattern used by `review_screen.dart`.

If `myStatsProvider` throws (offline), the `await` rejects inside the callback; wrap the body in `try { ... } catch (_) { /* no prompt */ }` so a missed prompt never surfaces an error. A missed prompt is cheaper than a wrong one.

- [ ] **Step 7: Run the full suite and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass (205 total).

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/lib/core/rating/app_rating_service.dart apps/mobile/lib/features/checkins/screens/checkin_success_screen.dart apps/mobile/test/app_rating_prompt_test.dart
git commit -m "feat(mobile): request App Store rating after third check-in

Apple caps the system prompt at three per user per year, so gate it on
demonstrated usage rather than spending one on launch. Count comes from
the server-side check-in list, not a local tally that resets on
reinstall."
```

---

### Task 4: Backend gym review-link endpoint

Returns the Google Maps "write a review" URI for a gym. Google forbids programmatic review submission; this is a hand-off link only.

**Files:**
- Modify: `packages/contract/src/schemas/gym.mts` (add optional `googleReviewUri`)
- Create: `apps/api/src/services/places-client.mts`
- Modify: `apps/api/src/config/env.mts` (add `GOOGLE_PLACES_API_KEY`)
- Modify: `apps/api/src/facades/gym.facade.mts`
- Modify: `apps/api/src/routes/gym.routes.mts`
- Modify: `apps/api/src/container.mts`
- Test: `apps/api/test/gym-review-link.test.mts` (create)

**Interfaces:**
- Consumes: `GymRepository` methods `findById` and `update`; `AppError` from `../http/errors.mts`; `data()` from `../http/envelope.mts`
- Produces:
  - `interface PlacesClient { writeAReviewUri(placeId: string): Promise<string | null> }`
  - `class GooglePlacesClient implements PlacesClient`
  - `GymFacade.reviewLink(id: string): Promise<{ writeAReviewUri: string | null }>`
  - Route `GET /api/v1/gyms/:id/review-link`
  - Container key `placesClient`

- [ ] **Step 1: Add the cache field to the Gym contract**

In `packages/contract/src/schemas/gym.mts`, add to the Gym object alongside `googlePlaceId`:

```typescript
  googleReviewUri: t.Optional(t.String()),
```

- [ ] **Step 2: Write the failing test**

Create `apps/api/test/gym-review-link.test.mts`:

```typescript
import { describe, expect, test } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { PlacesClient } from "../src/services/places-client.mts";

interface StubGym {
  readonly id: string;
  readonly googlePlaceId?: string;
  readonly googleReviewUri?: string;
}

function makeFacade(
  gym: StubGym | null,
  places: PlacesClient,
): { facade: GymFacade; updates: Record<string, unknown>[] } {
  const updates: Record<string, unknown>[] = [];
  const gyms = {
    findById: async (): Promise<StubGym | null> => gym,
    update: async (_id: string, patch: Record<string, unknown>): Promise<StubGym | null> => {
      updates.push(patch);
      return gym;
    },
    insert: async (): Promise<never> => { throw new Error("unused"); },
    list: async (): Promise<never> => { throw new Error("unused"); },
    listByOwner: async (): Promise<never> => { throw new Error("unused"); },
    findNearby: async (): Promise<never> => { throw new Error("unused"); },
  };
  const favorites = {
    add: async (): Promise<void> => {},
    remove: async (): Promise<void> => {},
    listGymIds: async (): Promise<string[]> => [],
  };
  const geocoder = { lookupZip: (): null => null };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const facade = new GymFacade(gyms as any, favorites as any, () => "id", geocoder as any, places);
  return { facade, updates };
}

describe("GymFacade.reviewLink", () => {
  test("returns the cached uri without calling Places", async () => {
    let called = false;
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        called = true;
        return "https://should-not-be-used";
      },
    };
    const { facade } = makeFacade(
      { id: "g1", googlePlaceId: "p1", googleReviewUri: "https://cached" },
      places,
    );

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: "https://cached" });
    expect(called).toBe(false);
  });

  test("fetches and persists on cache miss", async () => {
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => "https://fetched",
    };
    const { facade, updates } = makeFacade({ id: "g1", googlePlaceId: "p1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: "https://fetched" });
    expect(updates).toEqual([{ googleReviewUri: "https://fetched" }]);
  });

  test("returns null when the gym has no place id", async () => {
    let called = false;
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        called = true;
        return "x";
      },
    };
    const { facade } = makeFacade({ id: "g1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: null });
    expect(called).toBe(false);
  });

  test("returns null rather than throwing when Places fails", async () => {
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        throw new Error("places down");
      },
    };
    const { facade } = makeFacade({ id: "g1", googlePlaceId: "p1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: null });
  });
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd apps/api && bun test test/gym-review-link.test.mts`
Expected: FAIL — `places-client.mts` does not exist and `reviewLink` is not defined.

- [ ] **Step 4: Implement the Places client**

Create `apps/api/src/services/places-client.mts`:

```typescript
/// Reads Google Maps links for a place. Google does not permit programmatic
/// review submission — the returned URI hands the user off to Google Maps,
/// where they compose and submit the review themselves.
export interface PlacesClient {
  writeAReviewUri(placeId: string): Promise<string | null>;
}

interface PlaceDetailsResponse {
  readonly googleMapsLinks?: { readonly writeAReviewUri?: string };
}

export class GooglePlacesClient implements PlacesClient {

  public constructor(private readonly apiKey: string) {}

  public async writeAReviewUri(placeId: string): Promise<string | null> {
    if (!this.apiKey) return null;
    // Place Details (New) takes an unprefixed field mask. The `places.`-prefixed
    // form belongs to Text/Nearby Search responses and is rejected here.
    const url = `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`;
    const res = await fetch(url, {
      headers: {
        "X-Goog-Api-Key": this.apiKey,
        "X-Goog-FieldMask": "googleMapsLinks.writeAReviewUri",
      },
    });
    if (!res.ok) return null;
    const body = (await res.json()) as PlaceDetailsResponse;
    return body.googleMapsLinks?.writeAReviewUri ?? null;
  }
}

/// Used when no API key is configured, so local and test environments simply
/// omit the Google hand-off instead of failing.
export class NullPlacesClient implements PlacesClient {

  public async writeAReviewUri(): Promise<string | null> {
    return null;
  }
}
```

- [ ] **Step 5: Add the facade method**

In `apps/api/src/facades/gym.facade.mts`, add `places` as a fifth constructor parameter:

```typescript
    private readonly places: PlacesClient,
```

Import it: `import type { PlacesClient } from "../services/places-client.mts";`

Add the method next to `directions`:

```typescript
  /// Returns the Google Maps "write a review" link for a gym, or null when the
  /// gym has no Google place or Places yields nothing. Null is a normal result,
  /// not an error — the client simply omits the Google hand-off.
  public async reviewLink(id: string): Promise<{ writeAReviewUri: string | null }> {
    const gym = await this.getById(id);
    if (gym.googleReviewUri) return { writeAReviewUri: gym.googleReviewUri };
    if (!gym.googlePlaceId) return { writeAReviewUri: null };

    let uri: string | null = null;
    try {
      uri = await this.places.writeAReviewUri(gym.googlePlaceId);
    } catch {
      return { writeAReviewUri: null };
    }
    if (!uri) return { writeAReviewUri: null };

    // These links are stable, so cache to keep this one Places call per gym.
    await this.gyms.update(id, { googleReviewUri: uri });
    return { writeAReviewUri: uri };
  }
```

Widen the `gyms` constructor `Pick<>` to include `"update"` if it is not already listed.

- [ ] **Step 6: Add the route**

In `apps/api/src/routes/gym.routes.mts`, after the `/:id/directions` route (line 61):

```typescript
    .get("/:id/review-link", async ({ params }) => data(await gymFacade.reviewLink(params.id)))
```

- [ ] **Step 7: Wire config and container**

In `apps/api/src/config/env.mts`, add to the schema:

```typescript
  GOOGLE_PLACES_API_KEY: t.Optional(t.String()),
```

and to the returned config object:

```typescript
    googlePlacesApiKey: raw.GOOGLE_PLACES_API_KEY,
```

In `apps/api/src/container.mts`, add to the `Container` interface:

```typescript
  readonly placesClient: PlacesClient;
```

Construct it and pass it to the facade:

```typescript
    const placesClient: PlacesClient = config.googlePlacesApiKey
      ? new GooglePlacesClient(config.googlePlacesApiKey)
      : new NullPlacesClient();
```

Update the existing `gymFacade` construction (line 133) to:

```typescript
    gymFacade: new GymFacade(gymRepo, favoriteRepo, id, geocoder, placesClient),
```

Add `placesClient` to the returned container object. Import both classes and the type.

- [ ] **Step 8: Run tests and lint**

Run: `cd apps/api && bunx eslint --fix src/services/places-client.mts src/facades/gym.facade.mts src/routes/gym.routes.mts src/container.mts src/config/env.mts && bun test`
Expected: lint clean; all API tests pass including the 4 new ones. Existing `gym.facade.test.mts` constructs `GymFacade` — update those call sites to pass a `NullPlacesClient()` as the fifth argument.

- [ ] **Step 9: Document the new env var**

Add to `.env.example` (repo root or `apps/api/.env.example`, whichever exists):

```
# Google Places API (New) key. Optional — without it the gym review hand-off
# is simply omitted. Needs the Places API (New) enabled on the GCP project.
GOOGLE_PLACES_API_KEY=
```

- [ ] **Step 10: Commit**

```bash
git add packages/contract/src/schemas/gym.mts apps/api/src/services/places-client.mts apps/api/src/facades/gym.facade.mts apps/api/src/routes/gym.routes.mts apps/api/src/container.mts apps/api/src/config/env.mts apps/api/test/ .env.example
git commit -m "feat(api): add gym review-link endpoint backed by Places API

Google forbids programmatic review submission, so return the Maps
write-a-review URI for hand-off. Cached on the gym document — these
links are stable, so one Places call per gym. Missing key or place id
yields null, which the client treats as 'no Google step'."
```

---

### Task 5: Mobile Google review hand-off

**Files:**
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Create: `apps/mobile/lib/features/checkins/data/gym_review_link_repository.dart`
- Modify: `apps/mobile/lib/features/checkins/screens/review_screen.dart:75-90`
- Test: `apps/mobile/test/gym_review_link_test.dart` (create)

**Interfaces:**
- Consumes: `GET /api/v1/gyms/:id/review-link` returning `{ data: { writeAReviewUri: string | null } }` from Task 4; `apiClientProvider`; `url_launcher`
- Produces:
  - `bool shouldOfferGoogleReview({required int overallRating, required String? writeAReviewUri})`
  - `gymReviewLinkProvider` — `FutureProvider.family<String?, String>` keyed by gym id

- [ ] **Step 1: Add the endpoint constant**

In `apps/mobile/lib/core/api/endpoints.dart`, next to `gymDirections`:

```dart
  static String gymReviewLink(String id) => '/api/v1/gyms/$id/review-link';
```

- [ ] **Step 2: Write the failing test**

Create `apps/mobile/test/gym_review_link_test.dart`:

```dart
import 'package:bjj_open_mat/features/checkins/data/gym_review_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldOfferGoogleReview', () {
    const uri = 'https://maps.google.com/write';

    test('offers Google only for a positive rating', () {
      expect(shouldOfferGoogleReview(overallRating: 5, writeAReviewUri: uri), isTrue);
      expect(shouldOfferGoogleReview(overallRating: 4, writeAReviewUri: uri), isTrue);
    });

    test('never routes an unhappy reviewer to the public profile', () {
      expect(shouldOfferGoogleReview(overallRating: 3, writeAReviewUri: uri), isFalse);
      expect(shouldOfferGoogleReview(overallRating: 1, writeAReviewUri: uri), isFalse);
    });

    test('hidden when the gym has no Google link', () {
      expect(shouldOfferGoogleReview(overallRating: 5, writeAReviewUri: null), isFalse);
      expect(shouldOfferGoogleReview(overallRating: 5, writeAReviewUri: ''), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_review_link_test.dart`
Expected: FAIL — the repository file does not exist.

- [ ] **Step 4: Implement the repository**

Create `apps/mobile/lib/features/checkins/data/gym_review_link_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

/// Minimum overall rating before the Google hand-off is offered.
const int kGoogleReviewMinRating = 4;

/// Whether to offer the Google Maps hand-off after an in-app review.
///
/// The in-app review is always recorded in full regardless of score; this gate
/// governs only whether we point the user at the gym's public Google profile.
bool shouldOfferGoogleReview({required int overallRating, required String? writeAReviewUri}) {
  if (writeAReviewUri == null || writeAReviewUri.isEmpty) return false;
  return overallRating >= kGoogleReviewMinRating;
}

/// Google Maps "write a review" URI for a gym, or null when unavailable.
/// Null is a normal result, not an error — the caller omits the Google step.
final gymReviewLinkProvider = FutureProvider.family<String?, String>((ref, gymId) async {
  try {
    final res = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          Endpoints.gymReviewLink(gymId),
        );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data?['writeAReviewUri'] as String?;
  } catch (_) {
    return null;
  }
});
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_review_link_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Offer the hand-off after a successful submit**

In `apps/mobile/lib/features/checkins/screens/review_screen.dart`, the submit handler currently pops or navigates immediately after `submitReview` succeeds (lines 75-83). Before that navigation, insert:

```dart
      await _maybeOfferGoogleReview();
```

Add both methods to the state class. The gym id is derived from `sessionId` via
`sessionByIdProvider`, which already exists in this feature folder
(`apps/mobile/lib/features/checkins/data/attendance_repository.dart:46`) and returns an
`OpenMat` carrying `gymId`:

```dart
  /// Offers the Google hand-off when the review was positive and the gym has a
  /// Google link. Every failure path here is silent — the review is already
  /// saved, and nothing about the hand-off is worth an error message.
  Future<void> _maybeOfferGoogleReview() async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    try {
      final session = await ref.read(sessionByIdProvider(sessionId).future);
      if (!mounted) return;
      final uri = await ref.read(gymReviewLinkProvider(session.gymId).future);
      if (!mounted) return;
      final overall = _ratings['Overall']!.round();
      if (!shouldOfferGoogleReview(overallRating: overall, writeAReviewUri: uri)) return;
      await _offerGoogleReview(uri!);
    } catch (_) {
      // No hand-off. The in-app review is saved either way.
    }
  }

  Future<void> _offerGoogleReview(String uri) async {
    final t = Theme.of(context).extension<AppTokens>()!;
    final share = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Thanks for the review', style: t.h2Style),
        content: Text(
          'Want to share it on Google too? It opens Google Maps so you can post it there.',
          style: t.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Share on Google'),
          ),
        ],
      ),
    );
    if (share != true) return;
    await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
  }
```

Add imports:

```dart
import 'package:url_launcher/url_launcher.dart';
import '../data/attendance_repository.dart';
import '../data/gym_review_link_repository.dart';
```

- [ ] **Step 7: Run the full suite and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass (208 total).

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/core/api/endpoints.dart apps/mobile/lib/features/checkins/data/gym_review_link_repository.dart apps/mobile/lib/features/checkins/screens/review_screen.dart apps/mobile/test/gym_review_link_test.dart
git commit -m "feat(mobile): offer Google Maps hand-off after a positive gym review

Google forbids in-app review submission, so open the Maps composer.
Shown only at 4+ stars and only when the gym has a Google link — an
unhappy reviewer is never routed to the public profile."
```

---

### Task 6: Release the build and set the App Store category

Manual, performed by the account holder. No code.

**Files:** none

- [ ] **Step 1: Verify the whole suite is green**

```bash
cd apps/mobile && flutter analyze && flutter test
cd ../api && bunx eslint . && bun test
```
Expected: all clean.

- [ ] **Step 2: Run the app on the simulator and exercise each change**

```bash
open -a Simulator
cd apps/mobile && flutter run -d "iPhone 17 Pro" --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
```

Confirm by eye: Favorites row appears in Profile and opens the list; signed out, the Join button reads "Sign in to join" and reaches login; a 5-star review offers the Google hand-off and a 2-star one does not.

- [ ] **Step 3: Create version 1.1 in App Store Connect**

App Store Connect → BJJ OPEN MAT (`6787704999`) → Distribution → **⊕** next to iOS App → version `1.1` → Create.

- [ ] **Step 4: Set the secondary category**

App Information → Category → **Secondary: Health & Fitness**. Leave Primary as **Sports** — Health & Fitness is far more crowded and Sports gives a better shot at a chart position at current scale. Save.

- [ ] **Step 5: Build and upload**

```bash
cd apps/mobile && bun run mobile:ios
```
Upload the `.ipa` via Transporter. Wait for processing (10–30 min), then select the build on the 1.1 version page.

- [ ] **Step 6: Submit for review**

Add "What's New" text covering: Favorites list, clearer sign-in prompt when joining a gym, share reviews on Google, and sign-in reliability fixes. Then **Add for Review** → **Submit to App Review**.

---

## Notes for the implementer

- Tasks 1, 2, and 3 are fully independent and can be done in any order.
- **Task 5 depends on Task 4.** The mobile hand-off cannot be tested against a real link until the endpoint exists.
- Task 6 is last and requires the account holder.
- Item D of the spec (error and session fixes) is already committed as `822648e`. Do not redo it.
- If a task's test count differs from the number stated, that is fine — what matters is that the count never *drops*.
