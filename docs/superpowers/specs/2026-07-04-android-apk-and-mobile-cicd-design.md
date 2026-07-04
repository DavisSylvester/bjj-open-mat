# Android APK Build + Mobile CI/CD — Design

**Date:** 2026-07-04
**Scope:** `apps/mobile` (Flutter app `bjj_open_mat`)
**Status:** Approved (pending spec review)

## Goal

1. Produce a **signed release APK** you can sideload onto your Android device today.
2. Set up **GitHub Actions CI/CD** that builds the Android APK and delivers it via a GitHub Release + workflow artifact.
3. Add an **iOS compile-check** job (scaffold `ios/`, build with `--no-codesign`) — no device install / signing until an Apple Developer account exists.
4. Builds trigger on **version tags** (not every push to main), plus manual dispatch.

## Decisions (locked)

| Decision | Choice |
| --- | --- |
| Platform priority | Android first; iOS scaffold + compile-check only |
| APK signing | Generate a real release keystore |
| Delivery | GitHub Release (APK attached) **+** workflow artifact |
| Runtime config | Deployed API + real Auth0, injected via `--dart-define` from GitHub secrets |
| CI trigger | Version tags (`v*`) + `workflow_dispatch` |

## Current state (findings)

- Only `android/` and `web/` platform folders exist — **no `ios/`**.
- Release build still signs with **debug keys** (`android/app/build.gradle.kts` line ~37 TODO).
- `applicationId = com.example.bjj_open_mat` (placeholder).
- **No Google Maps API key** in `AndroidManifest.xml` — maps will not render on device until added. App depends on `google_maps_flutter`.
- Compile-time config via `--dart-define` / `--dart-define-from-file=.env`:
  `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`
  (plus optional `DEV_BYPASS` / `AUTH_BYPASS_TOKEN`).
- No `.github/workflows/` yet.
- Root `.gitignore` ignores `.env` / `.env.*` (keeps `.env.example`). Mobile `.gitignore` does **not** yet ignore keystores.

---

## Chunk A — App config & signing (foundation)

### A1. Release keystore & signing

- Generate `upload-keystore.jks` locally via `keytool` (RSA 2048, ~10000-day validity).
- Create `apps/mobile/android/key.properties` (gitignored) for local builds:
  ```
  storeFile=<abs path to upload-keystore.jks>
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```
- Edit `android/app/build.gradle.kts`:
  - Load `key.properties` if present; otherwise fall back to env vars (CI); otherwise debug signing (fresh clone still builds).
  - Define a real `release` signingConfig and point `buildTypes.release.signingConfig` at it.
- `.gitignore` additions (mobile): `key.properties`, `*.jks`, `*.keystore`.
- The keystore file itself is **never committed**. It is stored base64-encoded as the `ANDROID_KEYSTORE_BASE64` GitHub secret.

### A2. Real application ID

- Change `com.example.bjj_open_mat` → `com.davissylvester.bjjopenmat` in `android/app/build.gradle.kts`.
- Rationale: changing the ID after the first install makes Android treat it as a different app. Set it before the first sideload.

### A3. Google Maps key plumbing

- Add to `AndroidManifest.xml` inside `<application>`:
  ```xml
  <meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}"/>
  ```
- Provide `MAPS_API_KEY` via `manifestPlaceholders` in `build.gradle.kts`, sourced from a gradle property / env var (CI secret; local property). Native key — separate from the dart-define Auth0 values.

### A4. Local build path (immediate APK)

- Add script (root `package.json`):
  ```
  "mobile:apk": "cd apps/mobile && flutter build apk --release --dart-define-from-file=.env --dart-define=API_BASE_URL=<deployed-url>"
  ```
- Output: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`.
- Install: `adb install -r <apk>` or copy to phone and open.

---

## Chunk B — CI/CD workflows

### B1. `.github/workflows/mobile-android.yml` (runner: `ubuntu-latest`)

- **Triggers:** `push` tags matching `v*`; `workflow_dispatch`.
- **Steps:**
  1. `actions/checkout`
  2. `actions/setup-java` (Temurin 17)
  3. `subosito/flutter-action` (pinned Flutter version matching `pubspec` `^3.29.0`)
  4. Decode `ANDROID_KEYSTORE_BASE64` → `upload-keystore.jks`; write `key.properties` from secrets
  5. `flutter pub get`
  6. `flutter analyze` + `flutter test` (gate — fail build on error)
  7. `flutter build apk --release` with `--dart-define` values from secrets + `-PMAPS_API_KEY=...`
  8. `actions/upload-artifact` (the APK)
  9. `softprops/action-gh-release` — attach APK to the release for the tag
- **Versioning:** derive `versionCode` from `github.run_number` (and/or the tag) so each build is unique; pass via `--build-number`.

### B2. `.github/workflows/mobile-ios.yml` (runner: `macos-latest`)

- **One-time (local, committed):** generate `ios/` via `flutter create --platforms=ios .` and commit it.
- **Triggers:** `push` tags matching `v*`; `workflow_dispatch`.
- **Steps:** checkout → flutter-action → `flutter pub get` → `flutter build ios --no-codesign` with dart-defines. Compile check only; no artifact, no signing.

### B3. GitHub secrets (repo → Settings → Secrets and variables → Actions)

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (`upload`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `API_BASE_URL` | deployed backend base URL |
| `AUTH0_DOMAIN` | Auth0 tenant domain |
| `AUTH0_CLIENT_ID` | Auth0 SPA client id |
| `AUTH0_AUDIENCE` | Auth0 API audience |
| `MAPS_API_KEY` | Android Google Maps key |

A `docs/` note will list these names + how to set them.

---

## Testing & verification

- CI gates on `flutter analyze` + `flutter test` before building.
- **Manual acceptance:** install the CI-produced APK on a physical device; confirm the app launches, reaches the deployed API, Auth0 login works, and Google Maps renders.
- A green `bun test`/`flutter test` alone is not sufficient — the APK must install and run.

## Out of scope

- iOS signing / TestFlight / device install (deferred to Apple Developer account).
- Play Store / App Store publishing.
- Firebase App Distribution.
- Web build/deploy pipeline.

## Sequencing

1. Chunk A (config + signing + local APK) — gets you an installable APK immediately.
2. Generate keystore, report base64 + secret names.
3. Chunk B workflows.
4. Scaffold + commit `ios/`.
5. You set GitHub secrets; cut a `v*` tag to exercise CI.
