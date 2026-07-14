# Play Policy — In-App Experience Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Resolve the two substantive findings in the Google Play "In-app experience" rejection evidence (`IN_APP_EXPERIENCE-2809.png`): (1) discovery shows empty for a reviewer whose GPS is a bogus `0,0` fix; (2) the Profile screen renders the raw Auth0 subject id as the user's name and email.

**Architecture:** Flutter mobile (Riverpod, go_router) + Elysia/Bun API. Discovery already has a working "browse-all" path (no lat/lng → API returns all live sessions); the bug is that a garbage `0,0` fix passes `hasCoords`, so the app runs a radius query around Null Island that matches nothing. Fixing the location layer to reject implausible coordinates routes BOTH Home and Search into the existing browse-all path. Profile identity is corrupted at user-creation (displayName seeded from the sub) and the `/auth/sync` patch is skipped for `auth0|` (database) users.

**Tech Stack:** Flutter, Riverpod, geolocator; Elysia, Bun, TypeBox, MongoDB.

## Global Constraints

- **Real data only — NO mock/seed/demo data.** Per user directive, the app must show only real data from the production DB. Remove the seed scripts.
- Strict TypeScript, no `any`; single quotes; explicit return types (API side).
- Dart: `flutter analyze` must stay clean; all existing tests must keep passing.
- Never show a synthetic identifier (raw `auth0-…` sub or `@users.bjj-open-mat.app` email) in the UI.
- Do not weaken the existing unique-email placeholder mechanism (it prevents E11000 on email-less social logins) — only stop leaking it into the *display name*, and hide the placeholder email in the UI.

---

### Task 9: Never-empty discovery — reject bogus coordinates

**Root cause:** Android emulator with no GPS returns `(0,0)`; `LocationService.current()` accepts it, `hasCoords` becomes true, and both screens run a geo query around `0,0` (matches nothing). Reverse-geocoding `0,0` yields the "Fpo, AP" label. Rejecting implausible coords → `LocationController` sets `unavailable` → `hasCoords` false → Home uses `const NearbyQuery()` (already) and Search leaves `_gpsLat/_gpsLng` null (seeded only when `hasCoords`) → both send no lat/lng → API browse-all returns all live sessions.

**Files:**
- Modify: `apps/mobile/lib/core/location/location_service.dart` (add a validity guard; apply in `current()` and `_lastKnown()`)
- Test: `apps/mobile/test/core/location/location_validity_test.dart` (new)

**Interfaces:**
- Produces: a pure predicate `bool isPlausibleFix(double lat, double lng)` (top-level function in `location_service.dart`) returning false for `(0,0)`/near-null-island (`lat.abs() < 0.01 && lng.abs() < 0.01`), out-of-range (`lat.abs() > 90 || lng.abs() > 180`), or non-finite values. `GeolocatorLocationService` returns `null` instead of a `CapturedLocation` when the fix is not plausible.

- [ ] **Step 1: Write the failing test** — `apps/mobile/test/core/location/location_validity_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';

void main() {
  group('isPlausibleFix', () {
    test('rejects Null Island (0,0)', () {
      expect(isPlausibleFix(0, 0), isFalse);
    });
    test('rejects near-zero garbage fixes', () {
      expect(isPlausibleFix(0.0001, -0.0001), isFalse);
    });
    test('rejects out-of-range coordinates', () {
      expect(isPlausibleFix(91, 10), isFalse);
      expect(isPlausibleFix(10, 200), isFalse);
    });
    test('rejects non-finite coordinates', () {
      expect(isPlausibleFix(double.nan, 10), isFalse);
      expect(isPlausibleFix(10, double.infinity), isFalse);
    });
    test('accepts a real US city fix (San Diego)', () {
      expect(isPlausibleFix(32.7157, -117.1611), isTrue);
    });
    test('accepts a real fix in the southern/eastern hemisphere', () {
      expect(isPlausibleFix(-33.8688, 151.2093), isTrue); // Sydney
    });
  });
}
```

- [ ] **Step 2: Run it, verify it fails** — `cd apps/mobile && flutter test test/core/location/location_validity_test.dart` — Expected: FAIL (`isPlausibleFix` undefined).

- [ ] **Step 3: Implement** — in `apps/mobile/lib/core/location/location_service.dart`, add the top-level predicate and apply it. Add after the imports:

```dart
/// True when a GPS fix is a plausible real-world location. Emulators and cold
/// GPS chips frequently report (0,0) (Null Island) or out-of-range/non-finite
/// values; those must NOT be treated as "near me" or the near-you query
/// matches nothing and discovery looks empty. Returning false here routes the
/// app into the location-less browse-all path.
bool isPlausibleFix(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat.abs() > 90 || lng.abs() > 180) return false;
  if (lat.abs() < 0.01 && lng.abs() < 0.01) return false; // Null Island
  return true;
}
```

Then guard both return sites. In `current()` replace the success return (currently line ~33):

```dart
        if (!isPlausibleFix(pos.latitude, pos.longitude)) return _lastKnown();
        return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
```

and in `_lastKnown()` replace the return (currently line ~48):

```dart
      if (pos == null || !isPlausibleFix(pos.latitude, pos.longitude)) return null;
      return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
```

- [ ] **Step 4: Run tests** — `cd apps/mobile && flutter test test/core/location/location_validity_test.dart` — Expected: PASS. Then `flutter analyze` — Expected: no new issues.

- [ ] **Step 5: Commit** — `git add apps/mobile/lib/core/location/location_service.dart apps/mobile/test/core/location/location_validity_test.dart && git commit -m "fix(mobile): reject bogus (0,0) GPS so discovery falls back to browse-all"`

---

### Task 10: Profile identity — never show the raw Auth0 sub

**Root cause:** `user.facade.mts:25` seeds `displayName` from the synthetic sub-email; `user.facade.mts:41` returns early from `syncFromProvider` for non-social (`auth0|`) users, dropping the real name/email the client sends. `profile_view.dart` renders both verbatim with no fallback.

**Files:**
- Modify: `apps/api/src/facades/user.facade.mts` (creation displayName; sync guard)
- Modify: `apps/mobile/lib/features/profile/widgets/profile_view.dart` (display fallback + hide synthetic email)
- Test: `apps/api/test/user-facade.test.mts` (new or extend if present)
- Test: `apps/mobile/test/features/profile/profile_identity_test.dart` (new — pure display helpers)

**Interfaces:**
- Produces (mobile, top-level pure fns in `profile_view.dart`): `String profileDisplayName(String displayName)` → `displayName.trim().isEmpty ? 'BJJ Practitioner' : displayName`; `String? profileEmailForDisplay(String email)` → `null` when email ends with `@users.bjj-open-mat.app` (the synthetic placeholder) OR is empty, else the email. The hero hides the email row when this is null.

**API changes:**

- [ ] **Step 1: Write failing API test** — `apps/api/test/user-facade.test.mts` (create if missing). Use an in-memory fake of the `Pick<UserRepository,...>` the facade needs.

```ts
import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { User } from "@bjj/contract";

function fakeRepo() {
  const store = new Map<string, User>();
  return {
    store,
    findById: async (id: string) => store.get(id) ?? null,
    insert: async (u: User) => { store.set(u.id, u); return u; },
    update: async (id: string, patch: Partial<User>) => {
      const cur = store.get(id); if (!cur) return null;
      const next = { ...cur, ...patch }; store.set(id, next); return next;
    },
    upsertByAuth0Id: async (u: User) => { store.set(u.id, u); return u; },
  };
}

describe("UserFacade identity", () => {
  it("does NOT seed displayName from the Auth0 sub on creation", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const u = await f.getOrCreate({ userId: "auth0|6a36dd6a90830c3d8fb430aa", role: "user", email: "" });
    expect(u.displayName).toBe("");
    expect(u.displayName).not.toContain("auth0");
  });

  it("applies provider name/email on sync for a database (auth0|) user", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const id = { userId: "auth0|6a36dd6a90830c3d8fb430aa", role: "user", email: "" } as const;
    await f.getOrCreate(id);
    const synced = await f.syncFromProvider(id, { displayName: "Danaher", email: "john@example.com" });
    expect(synced.displayName).toBe("Danaher");
    expect(synced.email).toBe("john@example.com");
  });

  it("does not overwrite an existing user-set name on sync", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const id = { userId: "auth0|abc", role: "user", email: "" } as const;
    await f.getOrCreate(id);
    await f.updateProfile("auth0|abc", { displayName: "My Name" });
    const synced = await f.syncFromProvider(id, { displayName: "Provider Name" });
    expect(synced.displayName).toBe("My Name");
  });
});
```

- [ ] **Step 2: Run it, verify it fails** — `cd apps/api && bun test test/user-facade.test.mts` — Expected: FAIL.

- [ ] **Step 3: Implement in `apps/api/src/facades/user.facade.mts`:**
  - Line 25: change `displayName: email.split("@")[0] ?? identity.userId,` to `displayName: "",`.
  - Replace the `syncFromProvider` body so it also fills database users, without clobbering a user-set name. Only fill `displayName`/`email` when the stored value is empty OR is the synthetic placeholder:

```ts
  public async syncFromProvider(identity: AuthIdentity, claims: AuthSyncRequest): Promise<User> {
    const user = await this.getOrCreate(identity);
    const isPlaceholderEmail = user.email.endsWith("@users.bjj-open-mat.app");
    const patch: Partial<User> = {};
    // Social users re-sync provider identity every login (they own no local
    // name). Database users get filled ONLY when the stored value is still the
    // empty/placeholder default, so a user-edited name is never overwritten.
    const social = isSocial(identity.userId);
    if (claims.displayName && (social || user.displayName.trim() === "")) patch.displayName = claims.displayName;
    if (claims.email && (social || isPlaceholderEmail)) patch.email = claims.email;
    if (claims.avatarUrl && (social || !user.avatarUrl)) patch.avatarUrl = claims.avatarUrl;
    if (Object.keys(patch).length === 0) return user;
    const updated = await this.users.update(identity.userId, patch);
    return updated ?? user;
  }
```

- [ ] **Step 4: Run API tests** — `cd apps/api && bun test test/user-facade.test.mts` — Expected: PASS. Also run `bun test test/contract-open-mat.test.mts` to confirm no regression.

- [ ] **Step 5: Write failing mobile test** — `apps/mobile/test/features/profile/profile_identity_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/profile/widgets/profile_view.dart';

void main() {
  group('profileDisplayName', () {
    test('falls back when empty', () {
      expect(profileDisplayName(''), 'BJJ Practitioner');
      expect(profileDisplayName('   '), 'BJJ Practitioner');
    });
    test('keeps a real name', () {
      expect(profileDisplayName('Danaher'), 'Danaher');
    });
  });
  group('profileEmailForDisplay', () {
    test('hides the synthetic placeholder email', () {
      expect(profileEmailForDisplay('auth0-6a36dd6a90830c3d8fb430aa@users.bjj-open-mat.app'), isNull);
    });
    test('hides an empty email', () {
      expect(profileEmailForDisplay(''), isNull);
    });
    test('keeps a real email', () {
      expect(profileEmailForDisplay('john@example.com'), 'john@example.com');
    });
  });
}
```

- [ ] **Step 6: Run it, verify it fails** — `cd apps/mobile && flutter test test/features/profile/profile_identity_test.dart` — Expected: FAIL (functions undefined).

- [ ] **Step 7: Implement in `apps/mobile/lib/features/profile/widgets/profile_view.dart`:** add the two top-level pure fns (near `_cap`, above `profileGlassHero`):

```dart
/// Never show an empty name — a placeholder is friendlier than a blank card
/// and prevents a raw provider id from surfacing.
String profileDisplayName(String displayName) =>
    displayName.trim().isEmpty ? 'BJJ Practitioner' : displayName.trim();

/// Hide the synthetic per-user placeholder email (and empty emails) so a raw
/// `auth0-…@users.bjj-open-mat.app` identifier is never displayed.
String? profileEmailForDisplay(String email) {
  if (email.trim().isEmpty) return null;
  if (email.endsWith('@users.bjj-open-mat.app')) return null;
  return email;
}
```

Then in `profileGlassHero`: set `final displayName = profileDisplayName(user.displayName);` (line 29) and `final email = profileEmailForDisplay(user.email);` (line 30). Change the email `Text(email, ...)` at line 69 to render only when non-null:

```dart
                if (email != null) ...[
                  Text(email, style: t.bodyStyle.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  const SizedBox(height: 9),
                ] else const SizedBox(height: 9),
```

(the existing `SizedBox(height: 3)` before the email should sit inside the `if` too, or be removed when email is hidden — keep the card visually balanced; the avatar `initial` at line 34 must use `displayName` so it stays a letter, which it already does.)

- [ ] **Step 8: Run tests** — `cd apps/mobile && flutter test test/features/profile/profile_identity_test.dart` — Expected: PASS. Then `flutter analyze` — no new issues.

- [ ] **Step 9: Commit** — `git add apps/api/src/facades/user.facade.mts apps/api/test/user-facade.test.mts apps/mobile/lib/features/profile/widgets/profile_view.dart apps/mobile/test/features/profile/profile_identity_test.dart && git commit -m "fix(profile): persist provider name/email for db users and never render raw Auth0 id"`

---

### Task 11: Remove mock/seed data

**Files:**
- Delete: `apps/api/src/data/seed.mts`
- Delete: `apps/api/src/data/seed-runner.mts`
- Modify: `apps/api/package.json` (remove the `"seed"` script on line 9)

- [ ] **Step 1: Confirm no imports** — `grep -rn "seed.mts\|seed-runner\|seedOpenMats\|seedAttendees" apps/api/src apps/api/test` — Expected: only `seed-runner.mts` importing `seed.mts` (both being deleted). If anything else references them, STOP and report.
- [ ] **Step 2: Delete the files** — `git rm apps/api/src/data/seed.mts apps/api/src/data/seed-runner.mts`
- [ ] **Step 3: Remove the npm script** — delete the `"seed": "bun src/data/seed-runner.mts",` line from `apps/api/package.json`.
- [ ] **Step 4: Verify** — `cd apps/api && bun test` — Expected: existing suite still passes (repo test may need local Mongo; that's an env-only failure, not a regression). `cat package.json` shows no `seed` script.
- [ ] **Step 5: Commit** — `git add apps/api/package.json && git commit -m "chore(api): remove mock seed data — real DB data only"`

---

### Task 12: Runtime verification + reviewer note + resubmission

Production data is real but sparse: the live open mat is near **ZIP 75495 (Van Alstyne, TX)** — "RM Elite Brazilian Jiu-Jitsu". The discovery fix makes browse-all surface it for a bogus-GPS reviewer; the reviewer note guides them to it directly.

- [ ] Rebuild on the emulator; confirm Home/Find show the real TX session via browse-all (bogus GPS), that searching ZIP `75495` shows "RM Elite Brazilian Jiu-Jitsu", and that Profile shows a real name / no synthetic email.
- [ ] **Add reviewer instructions in Play Console** → App content → App access → provide a free-text note (this is the field Google reviewers read):
  > "BJJ Open Mat is a community directory of Brazilian Jiu-Jitsu open-mat sessions. Sessions are real and community-submitted, so availability depends on location. To see a live session, open the Find tab and enter ZIP code **75495** (Van Alstyne, TX) — 'RM Elite Brazilian Jiu-Jitsu' will appear. Tap it to view session details, RSVP, directions, and check-in."
- [ ] Retake ALL en-US screenshots from the fixed build (no Schedule tab; real data — capture the 75495 result and gym detail), replacing the stale ones — see `docs/play-store-listing.md` step 2.
- [ ] Resubmit via Play Console → Publishing overview.
