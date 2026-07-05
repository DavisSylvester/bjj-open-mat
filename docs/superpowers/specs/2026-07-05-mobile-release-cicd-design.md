# Mobile Release CI/CD — Android + iOS on each release

**Date:** 2026-07-05
**Status:** Approved design
**Scope:** Build and distribute both the Android and iOS Flutter apps from GitHub Actions on each new release.

## Goal

On each new release, produce signed, distributable builds of the `apps/mobile` Flutter app for both platforms and ship them to their beta channels:

- **Android** → signed `.aab` uploaded to **Google Play** (internal track) **and** a signed `.apk` attached to the GitHub Release.
- **iOS** → signed `.ipa` uploaded to **TestFlight** (App Store Connect) **and** the `.ipa` attached to the GitHub Release.

Signing approach: **community GitHub Actions, no Fastlane** — `apple-actions/*` for iOS, `r0adkll/upload-google-play` for Android. This keeps everything in workflow YAML and reuses the existing signed-APK Android setup.

## Current state

- `.github/workflows/mobile-android.yml` — builds a signed APK on `v*` tags, attaches it to the GitHub Release. Runs `flutter analyze` + `flutter test`.
- `.github/workflows/mobile-ios.yml` — **compile-check only** (`flutter build ios --release --no-codesign`); produces nothing distributable.
- `apps/mobile/ios/` — deployment target 14.0 (bumped for `auth0_flutter`/`Auth0` 2.18.0), CocoaPods integrated, `Podfile.lock` committed. Bundle id `com.davissylvester.bjjOpenMat`. `CODE_SIGN_STYLE = Automatic`, **no `DEVELOPMENT_TEAM` set** in the Xcode project.
- The Flutter app reads config at build time via `--dart-define`: `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`. It does **not** use a Google Maps widget, so no iOS Maps key is required at build time.

## Architecture

Replace the two existing mobile workflow files with a single **`.github/workflows/mobile-release.yml`** containing three jobs:

```
version  (ubuntu-latest)          → outputs: build_name, build_number
  ├── android (ubuntu-latest, needs: version)   → AAB → Play (internal), APK → Release
  └── ios     (macos-14,      needs: version)    → IPA → TestFlight,       IPA → Release
```

- `android` and `ios` run **in parallel** and are **independent**: neither is in the other's `needs`, so one failing does not cancel the other.
- Both depend only on `version` for consistent version metadata.

Rationale for consolidation: one file gives a single shared trigger, one version source, and one place to reason about a release. The two old files are deleted.

### Triggers

```yaml
on:
  release:
    types: [published]
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      build_name:
        description: 'Override version name (e.g. 1.2.3); defaults to tag'
        required: false
      play_track:
        description: 'Google Play track'
        default: internal
        required: false
```

### Concurrency

```yaml
concurrency:
  group: mobile-release-${{ github.ref }}
  cancel-in-progress: true
```

## Job: version

Derives version metadata once and exposes it as outputs consumed by both build jobs.

- **build_name**: from `workflow_dispatch.inputs.build_name` if provided; else the ref tag with the leading `v` stripped (`refs/tags/v1.2.3` → `1.2.3`; `release.tag_name` for the `release` event). Fail the job if no version can be derived.
- **build_number**: `${{ github.run_number }}` (monotonic across runs).

These are passed to Flutter as `--build-name=<build_name> --build-number=<build_number>` so Play and App Store Connect receive consistent, ever-increasing versions.

## Job: android (ubuntu-latest)

Working directory: `apps/mobile`.

1. `actions/checkout@v4`
2. `actions/setup-java@v4` (temurin 17)
3. `subosito/flutter-action@v2` (channel stable, version 3.41.x — pin to match the repo)
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. Decode keystore + write `android/key.properties` (unchanged from the current workflow; uses existing `ANDROID_*` secrets).
8. Build the app bundle:
   ```
   flutter build appbundle --release \
     --build-name=<build_name> --build-number=<build_number> \
     --dart-define=API_BASE_URL=$API_BASE_URL \
     --dart-define=AUTH0_DOMAIN=$AUTH0_DOMAIN \
     --dart-define=AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID \
     --dart-define=AUTH0_AUDIENCE=$AUTH0_AUDIENCE \
     -Pauth0Domain=$AUTH0_DOMAIN -PmapsApiKey=$MAPS_API_KEY
   ```
9. Build the APK the same way (`flutter build apk --release ...`) for the Release artifact.
10. Upload the `.aab` to Google Play with `r0adkll/upload-google-play@v1`:
    - `serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}`
    - `packageName: com.davissylvester.bjjopenmat` (confirm against `android/app/build.gradle` `applicationId` when implementing)
    - `releaseFiles: apps/mobile/build/app/outputs/bundle/release/app-release.aab`
    - `track: ${{ inputs.play_track || 'internal' }}`
    - `status: draft` (safe default; promotion to a live track is manual)
11. Attach the `.apk` to the GitHub Release with `softprops/action-gh-release@v2` (only when the run is tag/release-triggered).

## Job: ios (macos-14)

Working directory: `apps/mobile`.

1. `actions/checkout@v4`
2. `subosito/flutter-action@v2` (channel stable, version 3.41.x)
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test`
6. Import the distribution certificate with `apple-actions/import-codesign-certs@v3`:
   - `p12-file-base64: ${{ secrets.IOS_DIST_CERT_P12_BASE64 }}`
   - `p12-password: ${{ secrets.IOS_DIST_CERT_PASSWORD }}`
7. Install the provisioning profile: decode `IOS_PROVISIONING_PROFILE_BASE64` into `~/Library/MobileDevice/Provisioning Profiles/`.
8. Generate `ExportOptions.plist` in the workflow (not committed):
   - `method: app-store`
   - `signingStyle: manual`
   - `teamID: ${{ secrets.IOS_TEAM_ID }}`
   - `provisioningProfiles: { com.davissylvester.bjjOpenMat: <profile name> }`
   - The Xcode project has no `DEVELOPMENT_TEAM`; the team is supplied here (and via `--build-name`/build settings as needed) so nothing team-specific is committed.
9. Build the signed IPA:
   ```
   flutter build ipa --release \
     --build-name=<build_name> --build-number=<build_number> \
     --export-options-plist ios/ExportOptions.plist \
     --dart-define=API_BASE_URL=$API_BASE_URL \
     --dart-define=AUTH0_DOMAIN=$AUTH0_DOMAIN \
     --dart-define=AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID \
     --dart-define=AUTH0_AUDIENCE=$AUTH0_AUDIENCE
   ```
10. Upload to TestFlight with `apple-actions/upload-testflight-build@v3` using an App Store Connect API key:
    - `app-path: apps/mobile/build/ios/ipa/*.ipa`
    - `issuer-id: ${{ secrets.ASC_ISSUER_ID }}`
    - `api-key-id: ${{ secrets.ASC_KEY_ID }}`
    - `api-private-key: ${{ secrets.ASC_API_KEY_P8_BASE64 }}` (decoded in-step if the action expects raw)
11. Attach the `.ipa` to the GitHub Release with `softprops/action-gh-release@v2` (tag/release-triggered runs only).

## Secrets

**Already configured (reused):**
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`, `MAPS_API_KEY`.

**New — Android:**
- `PLAY_SERVICE_ACCOUNT_JSON` — Play Console service-account JSON with release permissions.

**New — iOS:**
- `IOS_DIST_CERT_P12_BASE64` — base64 of the Apple Distribution certificate `.p12`.
- `IOS_DIST_CERT_PASSWORD` — password for that `.p12`.
- `IOS_PROVISIONING_PROFILE_BASE64` — base64 of the App Store provisioning profile.
- `IOS_TEAM_ID` — Apple Developer Team ID.
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64` — App Store Connect API key (id, issuer, base64 of the `.p8`).

Bundle id `com.davissylvester.bjjOpenMat` is a constant, not a secret.

## One-time manual prerequisites (documented, not automated)

**Apple:**
1. Apple Developer Program membership.
2. App ID + app record created in App Store Connect (bundle id `com.davissylvester.bjjOpenMat`), with a TestFlight-eligible build slot.
3. Apple Distribution certificate exported as `.p12`.
4. App Store provisioning profile for the App ID.
5. App Store Connect API key (`.p8`) with the Issuer ID and Key ID.

**Google Play:**
1. App created in Play Console under `com.davissylvester.bjjOpenMat`.
2. **First `.aab` uploaded manually** — Play rejects API uploads until an initial bundle exists.
3. Service account created with release permissions; JSON key downloaded.

These are captured as a checklist in `docs/mobile-cicd.md`; they are not part of the workflow.

## Error handling & isolation

- `android` and `ios` are independent jobs; a failure in one leaves the other's result intact.
- Play upload defaults to `track: internal`, `status: draft` — nothing reaches production without a manual promotion.
- TestFlight is an internal channel; App Store review submission is **not** part of this workflow.
- `analyze` + `test` gate each platform build before signing/upload.

## Verification plan

Signed builds require the real secrets, which aren't available in this repo during implementation. Verification is therefore staged:

1. **Static:** run `actionlint` on `mobile-release.yml`; confirm job graph, triggers, and expression syntax.
2. **Dry run:** after the maintainer adds the secrets, trigger `workflow_dispatch` with a test `build_name`. Android targets the **internal/draft** Play track; iOS lands in **TestFlight** — both non-public, safe to exercise.
3. **Docs:** `docs/mobile-cicd.md` updated with the new secrets, the consolidated workflow, and the prerequisites checklist so a maintainer can complete setup without reading the YAML.

## Out of scope

- Fastlane / `match` (Option B) — can be adopted later if manual cert/profile rotation becomes painful.
- Automatic submission to App Store review or promotion to a live Play track.
- Web build/deploy (separate concern).
- Changing the API deploy workflow (`api-deploy.yml`).
