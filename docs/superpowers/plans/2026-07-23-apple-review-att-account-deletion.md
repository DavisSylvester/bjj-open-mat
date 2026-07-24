# Implementation Plan — Apple Review Rejections
**Date:** 2026-07-23
**App:** BJJ Open Mat (`com.davissylvester.bjjOpenMat`)
**Rejections to fix:**
- **Guideline 5.1.2(i)** — No App Tracking Transparency (ATT) dialog despite privacy labels claiming Precise Location and Name are used for tracking.
- **Guideline 5.1.1(v)** — No account deletion path found by the reviewer.

---

## Situation Assessment

### Guideline 5.1.1(v) — Account Deletion

**Already implemented.** PR #21 (merged 2026-07-22, commit `fa7d0b7`) added the full end-to-end flow:

- **Mobile** (`apps/mobile/lib/features/settings/screens/settings_screen.dart`): Settings → Account → "Delete Account" → confirmation dialog → `authStateProvider.notifier.deleteAccount()` → `AuthService.deleteAccount()` → `DELETE /api/v1/users/me`.
- **API** (`apps/api/src/services/account-deletion.service.mts`): `AccountDeletionOrchestrator` deletes check-ins, favorites, RSVPs, notifications → Auth0 identity → user record (in that order so a partial failure is always retryable).

**Why Apple rejected it:** They reviewed an old binary (pre-PR #21). The fix is a new build that includes PR #21 (already in `main`), plus making the feature more discoverable — the current path (profile gear icon → `/settings` → Account section) requires two navigations that a reviewer script wouldn't find naturally.

**Discoverability fix:** Add "Delete Account" directly to the profile screen's settings list (where Sign Out already lives), so it's one tap from the profile tab with no secondary route.

### Guideline 5.1.2(i) — App Tracking Transparency

**Not implemented.** The app's App Store Connect privacy labels were set to say Precise Location and Name are collected "for tracking" (i.e., linked to cross-app/website advertising). This triggers Apple's mandatory ATT dialog requirement — but the app has no ATT dialog.

**Root cause choices:**
1. The privacy labels were filled out incorrectly (the app doesn't actually track across other apps).
2. `google_maps_flutter` sends device identifiers to Google for its own purposes, which Apple counts as tracking.

**Both must be fixed:**
- Correct the privacy labels in App Store Connect (Precise Location → App Functionality / not Tracking; Name → App Functionality / not Tracking).
- **And** implement the ATT dialog in the app as defense-in-depth, because Apple often requires it whenever a Google Maps SDK is present, regardless of label correction.

---

## Tasks

### Part 1 — Account Deletion Discoverability

#### Task 1: Add "Delete Account" to the profile screen settings section

**File:** `apps/mobile/lib/features/profile/screens/profile_screen.dart`

The profile screen already has a "settings" section with My Training / Notifications / Account / Switch Role / Sign Out. Add a "Delete Account" row at the bottom of that section, mirroring the implementation in `settings_screen.dart`.

Steps:
1. Extract the `_confirmDeleteAccount` helper (or import it) — simplest approach is to duplicate the dialog inline, since the function in `settings_screen.dart` is file-private. Move it to a shared location or just repeat the pattern.
2. Add a `Divider` + `ListTile` with `LucideIcons.trash2`, red text label "Delete Account", same `_confirmDeleteAccount` dialog logic.
3. TDD: The profile screen is a widget — verify it renders a tile labeled "Delete Account" and that tapping it shows the confirmation dialog.

No backend or auth changes needed for this task.

#### Task 2: Verify the Settings screen Delete Account is also reachable

No code change — just confirm the existing path works:
- Profile → gear icon (top right) → `/settings` → Account → Delete Account

Captures both paths for the reviewer screenshot/video.

---

### Part 2 — App Tracking Transparency

#### Task 3: Add `app_tracking_transparency` package

**File:** `apps/mobile/pubspec.yaml`

Add under `dependencies`:
```yaml
app_tracking_transparency: ^3.5.1
```

Run `flutter pub get` to regenerate `pubspec.lock`.

#### Task 4: Add `NSUserTrackingUsageDescription` to iOS Info.plist

**File:** `apps/mobile/ios/Runner/Info.plist`

Add inside the root `<dict>`:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>BJJ Open Mat uses your location to find open mat sessions near you. No data is shared with third parties for advertising.</string>
```

This string surfaces in the iOS system ATT permission dialog. Apple will reject a vague description, so be specific and honest.

#### Task 5: Create ATT service

**New file:** `apps/mobile/lib/core/privacy/att_service.dart`

```dart
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Requests App Tracking Transparency authorization on iOS 14+.
/// On Android (or if already determined) this is a no-op.
/// Call this once before requesting device location.
Future<void> requestTrackingIfNeeded() async {
  if (!Platform.isIOS) return;
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  if (status == TrackingStatus.notDetermined) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}
```

No Riverpod provider needed — this is a fire-and-forget call.

#### Task 6: Call ATT before location permission

**File:** `apps/mobile/lib/core/location/location_service.dart`

In `GeolocatorLocationService.current()`, add the ATT call before `Geolocator.requestPermission()`:

```dart
import '../privacy/att_service.dart';

// Inside current():
LocationPermission perm = await Geolocator.checkPermission();
if (perm == LocationPermission.denied) {
  await requestTrackingIfNeeded();   // ← add this line
  perm = await Geolocator.requestPermission();
}
```

ATT must be shown before (or at the same time as) location permission. iOS 14+ requires ATT before any IDFA or cross-app tracking data collection. Placing it here ensures it fires on first location use, which is early in the app lifecycle (discover tab / open-mat search).

#### Task 7: Fix App Store Connect privacy labels (manual)

In App Store Connect → your app → App Privacy:

| Data type | Current (wrong) | Correct |
|-----------|----------------|---------|
| **Precise Location** | Collected, used for Tracking | Collected, used for **App Functionality** (finding nearby open mats). **Not** used for tracking. |
| **Name** | Collected, used for Tracking | Collected, used for **App Functionality** (user profile display). Linked to identity. **Not** used for tracking. |

Steps:
1. Go to App Store Connect → Apps → BJJ Open Mat → App Privacy.
2. For **Location → Precise Location**: edit use cases, uncheck "Tracking", ensure "App Functionality" is checked. Set "Linked to Identity: No" (location is not linked to your account — it's ephemeral session data).
3. For **Contact Info → Name**: edit use cases, uncheck "Tracking", ensure "App Functionality" is checked. Set "Linked to Identity: Yes" (your display name is your account).
4. Save and confirm.

---

### Part 3 — Build, Test, and Respond

#### Task 8: Build a new iOS release binary

On a Mac with the Apple signing certificates and provisioning profiles:

```bash
cd apps/mobile
flutter pub get
flutter build ipa --release \
  --dart-define=AUTH0_DOMAIN=<your-tenant>.auth0.com \
  --dart-define=AUTH0_CLIENT_ID=<your-client-id> \
  --dart-define=AUTH0_AUDIENCE=<your-audience> \
  --dart-define=API_BASE_URL=<your-api-url>
```

Upload `build/ios/ipa/*.ipa` via Xcode Organizer or `xcrun altool`.

Reference: `docs/ios-build.md` and `docs/apple-app-registration.md` §4.2.

#### Task 9: End-to-end manual test on TestFlight

Before responding to Apple:

1. **ATT dialog**: Install TestFlight build → launch app → navigate to Discover → confirm the ATT dialog appears ("Allow BJJ Open Mat to track your activity…") before the location permission dialog.
2. **Account deletion**: Log in → Profile tab → scroll to settings section → tap "Delete Account" → confirm dialog → verify: app navigates to login, user cannot log back in, Auth0 dashboard no longer shows the user.
3. **Deletion via settings route**: Profile → gear icon → Settings → Delete Account → same verification.

#### Task 10: Respond in App Store Connect Resolution Center

**Note:** ATT was removed (the app does not track). 5.1.2(i) is resolved purely by
correcting the App Privacy labels to "no tracking" and shipping a binary that no
longer contains `NSUserTrackingUsageDescription`. Do NOT mention an ATT dialog.

Draft response:

> **Re: Guideline 5.1.2(i) — Data Use and Sharing**
>
> We have corrected our App Privacy labels in App Store Connect. Precise Location and Name are now marked as used only for App Functionality (finding nearby open mat sessions and displaying the user's profile) and are not used for tracking. BJJ Open Mat does not track users: it collects no advertising identifiers, integrates no third-party ad SDKs, and shares no data with data brokers. This build also removes the tracking usage description from the binary, so the app and its privacy labels are now consistent — the app requests no tracking permission because it performs no tracking.
>
> **Re: Guideline 5.1.1(v) — Account Deletion**
>
> Account deletion is available in this build via two paths:
> 1. Profile tab → Account section → "Delete Account"
> 2. Profile tab → gear icon (top right) → Settings → Account → "Delete Account"
>
> Both paths show a confirmation dialog, then permanently delete all user data (check-ins, favorites, RSVPs, notifications, and the Auth0 identity) before signing the user out. A screen recording demonstrating the flow from login through deletion is attached.

Attach a screen recording of the deletion flow (required by Apple to accept 5.1.1(v) fixes).

##### Final message posted to the Resolution Center (build 0.1.1 / 116, in review)

> Hello, and thank you for the welcome.
>
> We've submitted a new build (0.1.1, build 116) that resolves both issues from the previous review.
>
> **Guideline 5.1.1(v) — Account Deletion**
>
> Account deletion is now available directly in the app via two paths:
> 1. Profile tab → Account section → Delete Account
> 2. Profile tab → gear icon (top right) → Settings → Account → Delete Account
>
> Both show a confirmation dialog and then permanently delete all of the user's data — check-ins, favorites, RSVPs, notifications, and the account identity itself — before signing the user out. A screen recording of the full flow, from sign-in through deletion, is attached.
>
> **Guideline 5.1.2(i) — Data Use and Sharing**
>
> We've corrected our App Privacy labels: Precise Location and Name are now declared as used only for App Functionality (finding nearby open mat sessions and displaying the user's profile), not for tracking. BJJ Open Mat does not track users — it collects no advertising identifiers, includes no third-party advertising SDKs, and shares no data with data brokers. This build also removes the tracking usage description from the binary, so the app and its privacy labels are now fully consistent: the app requests no tracking permission because it performs no tracking.
>
> Please let us know if you need anything further. Thank you for your time reviewing our app.

Attach the account-deletion screen recording to this message (Simulator: `xcrun simctl io booted recordVideo ~/Desktop/delete-account.mov`, then walk Profile → Delete Account → confirm → login screen).

---

## File Change Summary

| File | Change |
|------|--------|
| `apps/mobile/pubspec.yaml` | Add `app_tracking_transparency: ^3.5.1` |
| `apps/mobile/ios/Runner/Info.plist` | Add `NSUserTrackingUsageDescription` |
| `apps/mobile/lib/core/privacy/att_service.dart` | New — `requestTrackingIfNeeded()` |
| `apps/mobile/lib/core/location/location_service.dart` | Call `requestTrackingIfNeeded()` before `Geolocator.requestPermission()` |
| `apps/mobile/lib/features/profile/screens/profile_screen.dart` | Add "Delete Account" ListTile to settings section |
| App Store Connect (manual) | Fix Precise Location + Name privacy labels |

---

## Commit Plan

```
feat(privacy): add App Tracking Transparency dialog before location permission
feat(profile): add Delete Account to profile screen settings section
```

One PR covering both, since they both target the same App Store submission.

---

## Definition of Done

- [ ] `flutter build ipa --release` succeeds with no new warnings
- [ ] ATT dialog appears before location dialog on first launch (TestFlight)
- [ ] Delete Account visible on Profile screen (no gear icon required)
- [ ] Full deletion flow confirmed against prod Auth0 (user disappears from Auth0 dashboard)
- [ ] App Store Connect privacy labels updated (no "Tracking" for Location or Name)
- [ ] Resolution Center response sent with screen recording
