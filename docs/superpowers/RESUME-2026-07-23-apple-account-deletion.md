# Resume Notes — Apple Resubmission (ATT + Account Deletion)

**Date:** 2026-07-23
**App:** BJJ Open Mat (`com.davissylvester.bjjOpenMat`)
**Goal:** Fix two Apple rejection guidelines and resubmit.

---

## Actual Apple Rejection Reasons

1. **Guideline 5.1.2(i)** — App's privacy labels claim Precise Location and Name are collected for tracking, but the app shows no ATT (App Tracking Transparency) permission dialog.
2. **Guideline 5.1.1(v)** — Reviewer could not find account deletion. (The feature existed in code but wasn't discoverable from the profile tab.)

---

## ✅ Done this session

### Guideline 5.1.2(i) — ATT Implementation

- Added `app_tracking_transparency: ^3.5.1` to `apps/mobile/pubspec.yaml`.
- Added `NSUserTrackingUsageDescription` to `apps/mobile/ios/Runner/Info.plist`:
  > "BJJ Open Mat uses your location to find open mat sessions near you. No data is shared with third parties for advertising."
- Created `apps/mobile/lib/core/privacy/att_service.dart` — `requestTrackingIfNeeded()` wrapper (iOS-only, no-op on Android, no-op if status already determined).
- Updated `apps/mobile/lib/core/location/location_service.dart` to call `requestTrackingIfNeeded()` before `Geolocator.requestPermission()` — ATT fires on first location use.

### Guideline 5.1.1(v) — Account Deletion Discoverability

- Added "Delete Account" ListTile and confirmation dialog directly to the profile screen's Settings section (`apps/mobile/lib/features/profile/screens/profile_screen.dart`), after "Sign out".
- The feature is now reachable in **one tap from the Profile tab** — no gear icon or secondary route required.
- The SettingsScreen (`/settings`) also retains its own Delete Account (merged in PR #21).

---

## ⚠️ Not yet done / verify next session

1. **`flutter pub get` must be run on the build Mac** to resolve `app_tracking_transparency` and regenerate `pubspec.lock`. The lock file is not updated on Windows.
2. **No live end-to-end verification.** Nobody has deleted a real test account and confirmed the Auth0 user disappears from the Auth0 dashboard. Do this from the TestFlight build before responding to Apple.
3. **iOS binary not yet built or uploaded.** Must rebuild (`flutter build ipa --release`) on a Mac with signing certs and upload to App Store Connect.
4. **App Store Connect privacy labels must be corrected manually** (see plan Task 7):
   - Precise Location: change from "Tracking" → "App Functionality" only.
   - Name: change from "Tracking" → "App Functionality" only.
5. **Screen recording for Resolution Center response** — Apple requires a video demonstrating the deletion flow for 5.1.1(v).

---

## Next steps, in order

1. On the build Mac: `flutter pub get` in `apps/mobile/`, then `flutter build ipa --release`.
2. Upload to App Store Connect (Xcode Organizer or `xcrun altool`).
3. Fix privacy labels in App Store Connect (see plan Task 7 for exact steps).
4. Install TestFlight build → verify ATT dialog appears before location dialog.
5. Delete a test account end-to-end → confirm Auth0 user is gone.
6. Record screen capture of deletion flow (Profile → Delete Account → login screen).
7. Respond in Resolution Center (draft in `docs/superpowers/plans/2026-07-23-apple-review-att-account-deletion.md` Task 10).

---

## Key references

- **Plan:** `docs/superpowers/plans/2026-07-23-apple-review-att-account-deletion.md`
- `docs/apple-app-registration.md` — bundle id, build/upload commands, checklist.
- `docs/ios-build.md` — Mac build/run instructions.
- PR #21 (merged 2026-07-22) — original account deletion implementation.
