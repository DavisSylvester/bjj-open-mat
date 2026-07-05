# Mobile Release CI/CD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and distribute signed Android and iOS builds of `apps/mobile` from a single GitHub Actions workflow on each new release — Android `.aab`→Google Play (internal) + `.apk`→Release, iOS `.ipa`→TestFlight + `.ipa`→Release.

**Architecture:** One workflow `.github/workflows/mobile-release.yml` with a `version` job feeding two independent, parallel build jobs (`android` on ubuntu, `ios` on macOS). Signing uses community actions (no Fastlane): `apple-actions/*` for iOS, `r0adkll/upload-google-play` for Android. Replaces the existing `mobile-android.yml` and `mobile-ios.yml`.

**Tech Stack:** GitHub Actions, Flutter 3.41.4 (`subosito/flutter-action@v2`), `r0adkll/upload-google-play@v1`, `apple-actions/import-codesign-certs@v3`, `apple-actions/upload-testflight-build@v3`, `softprops/action-gh-release@v2`, `actionlint` (local YAML validation).

## Global Constraints

- Flutter pinned to **3.41.4** (matches the existing workflows).
- Android `applicationId` / Play `packageName` = **`com.davissylvester.bjjopenmat`** (all lowercase). NOTE: the spec (`docs/superpowers/specs/2026-07-05-mobile-release-cicd-design.md`) says `com.davissylvester.bjjOpenMat` — that is the **iOS bundle id**; the Play packageName must be the lowercase Android `applicationId`. Fix the spec line in Task 4.
- iOS bundle id = **`com.davissylvester.bjjOpenMat`** (camelCase).
- Build config passed at build time via `--dart-define`: `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`. Android also needs `-Pauth0Domain` + `-PmapsApiKey`.
- `build-name` derived from the `v*` tag (leading `v` stripped) or `workflow_dispatch` input; `build-number` = `github.run_number`.
- Play upload defaults: `track: internal`, `status: draft` (no auto-promotion). iOS goes to TestFlight only (no App Store review submission).
- `android` and `ios` jobs are independent — neither in the other's `needs`; a failure in one must not cancel the other.
- Never commit Apple team ids, certs, profiles, or service-account JSON — all via GitHub secrets.

---

### Task 1: Workflow skeleton + `version` job

Creates the workflow with triggers, concurrency, permissions, and the `version` job that both build jobs consume. No build jobs yet — this task's deliverable is a valid workflow whose `version` job computes correct outputs.

**Files:**
- Create: `.github/workflows/mobile-release.yml`

**Interfaces:**
- Produces: job `version` with outputs `build_name` (string, e.g. `0.1.0`) and `build_number` (string, e.g. `42`), consumed by Tasks 2 and 3 via `needs.version.outputs.*`.

- [ ] **Step 1: Install actionlint (one-time, for local validation)**

Run: `brew install actionlint`
Expected: actionlint installed; `actionlint --version` prints a version.

- [ ] **Step 2: Create the workflow with triggers, concurrency, and the version job**

Create `.github/workflows/mobile-release.yml`:

```yaml
name: Mobile Release

on:
  release:
    types: [published]
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      build_name:
        description: 'Version name (e.g. 1.2.3); required for manual runs'
        required: false
      play_track:
        description: 'Google Play track'
        default: internal
        required: false

permissions:
  contents: write   # attach artifacts to the GitHub Release

concurrency:
  group: mobile-release-${{ github.ref }}
  cancel-in-progress: true

jobs:
  version:
    runs-on: ubuntu-latest
    outputs:
      build_name: ${{ steps.v.outputs.build_name }}
      build_number: ${{ steps.v.outputs.build_number }}
    steps:
      - name: Derive version
        id: v
        run: |
          NAME="${{ github.event.inputs.build_name }}"
          if [ -z "$NAME" ]; then
            case "${GITHUB_REF}" in
              refs/tags/v*) NAME="${GITHUB_REF_NAME#v}" ;;
              *) echo "::error::No version. Push a v* tag or pass build_name."; exit 1 ;;
            esac
          fi
          echo "build_name=$NAME" >> "$GITHUB_OUTPUT"
          echo "build_number=${{ github.run_number }}" >> "$GITHUB_OUTPUT"
          echo "Resolved version $NAME (+${{ github.run_number }})"
```

- [ ] **Step 3: Validate the workflow**

Run: `actionlint .github/workflows/mobile-release.yml`
Expected: no output (exit 0). Any output = a syntax/expression error to fix before continuing.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/mobile-release.yml
git commit -m "ci(mobile): add release workflow skeleton with version job"
```

---

### Task 2: Android job + remove old Android workflow

Adds the `android` job (AAB→Play, APK→Release) and deletes the superseded `mobile-android.yml`.

**Files:**
- Modify: `.github/workflows/mobile-release.yml` (append `android` job under `jobs:`)
- Delete: `.github/workflows/mobile-android.yml`

**Interfaces:**
- Consumes: `needs.version.outputs.build_name`, `needs.version.outputs.build_number` from Task 1.

- [ ] **Step 1: Append the `android` job**

Add under `jobs:` in `.github/workflows/mobile-release.yml` (after the `version` job):

```yaml
  android:
    needs: version
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.41.4

      - name: Decode keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks

      - name: Write key.properties
        run: |
          cat > android/key.properties <<EOF
          storeFile=${{ github.workspace }}/apps/mobile/android/upload-keystore.jks
          storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          EOF

      - name: Flutter pub get
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test

      - name: Build App Bundle (AAB)
        run: |
          flutter build appbundle --release \
            --build-name=${{ needs.version.outputs.build_name }} \
            --build-number=${{ needs.version.outputs.build_number }} \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
            --dart-define=AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN }} \
            --dart-define=AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID }} \
            --dart-define=AUTH0_AUDIENCE=${{ secrets.AUTH0_AUDIENCE }} \
            -Pauth0Domain=${{ secrets.AUTH0_DOMAIN }} \
            -PmapsApiKey=${{ secrets.MAPS_API_KEY }}

      - name: Build APK
        run: |
          flutter build apk --release \
            --build-name=${{ needs.version.outputs.build_name }} \
            --build-number=${{ needs.version.outputs.build_number }} \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
            --dart-define=AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN }} \
            --dart-define=AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID }} \
            --dart-define=AUTH0_AUDIENCE=${{ secrets.AUTH0_AUDIENCE }} \
            -Pauth0Domain=${{ secrets.AUTH0_DOMAIN }} \
            -PmapsApiKey=${{ secrets.MAPS_API_KEY }}

      - name: Upload AAB to Google Play
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.davissylvester.bjjopenmat
          releaseFiles: apps/mobile/build/app/outputs/bundle/release/app-release.aab
          track: ${{ github.event.inputs.play_track || 'internal' }}
          status: draft

      - name: Attach APK to GitHub Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 2: Delete the superseded Android workflow**

```bash
git rm .github/workflows/mobile-android.yml
```

- [ ] **Step 3: Validate**

Run: `actionlint .github/workflows/mobile-release.yml`
Expected: no output (exit 0).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/mobile-release.yml
git commit -m "ci(mobile): build AAB->Play and APK->Release; drop mobile-android.yml"
```

---

### Task 3: iOS job + remove old iOS workflow

Adds the signed `ios` job (IPA→TestFlight, IPA→Release) and deletes the compile-check-only `mobile-ios.yml`.

**Files:**
- Modify: `.github/workflows/mobile-release.yml` (append `ios` job under `jobs:`)
- Delete: `.github/workflows/mobile-ios.yml`

**Interfaces:**
- Consumes: `needs.version.outputs.build_name`, `needs.version.outputs.build_number` from Task 1.

- [ ] **Step 1: Append the `ios` job**

Add under `jobs:` in `.github/workflows/mobile-release.yml` (after the `android` job):

```yaml
  ios:
    needs: version
    runs-on: macos-14
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.41.4

      - name: Flutter pub get
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test

      - name: Import distribution certificate
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.IOS_DIST_CERT_P12_BASE64 }}
          p12-password: ${{ secrets.IOS_DIST_CERT_PASSWORD }}

      - name: Install provisioning profile
        env:
          PROFILE_B64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
        run: |
          PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
          mkdir -p "$PROFILE_DIR"
          echo "$PROFILE_B64" | base64 -d > "$PROFILE_DIR/dist.mobileprovision"
          # extract the profile name for manual signing
          security cms -D -i "$PROFILE_DIR/dist.mobileprovision" > /tmp/profile.plist
          PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /tmp/profile.plist)
          echo "PROFILE_NAME=$PROFILE_NAME" >> "$GITHUB_ENV"

      - name: Configure manual signing for archive
        run: |
          cat >> ios/Flutter/Release.xcconfig <<EOF
          DEVELOPMENT_TEAM=${{ secrets.IOS_TEAM_ID }}
          CODE_SIGN_STYLE=Manual
          CODE_SIGN_IDENTITY=Apple Distribution
          PROVISIONING_PROFILE_SPECIFIER=$PROFILE_NAME
          EOF

      - name: Write ExportOptions.plist
        run: |
          cat > ios/ExportOptions.plist <<EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key><string>app-store</string>
            <key>signingStyle</key><string>manual</string>
            <key>teamID</key><string>${{ secrets.IOS_TEAM_ID }}</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>com.davissylvester.bjjOpenMat</key><string>$PROFILE_NAME</string>
            </dict>
          </dict>
          </plist>
          EOF

      - name: Build signed IPA
        run: |
          flutter build ipa --release \
            --build-name=${{ needs.version.outputs.build_name }} \
            --build-number=${{ needs.version.outputs.build_number }} \
            --export-options-plist ios/ExportOptions.plist \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
            --dart-define=AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN }} \
            --dart-define=AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID }} \
            --dart-define=AUTH0_AUDIENCE=${{ secrets.AUTH0_AUDIENCE }}

      - name: Decode App Store Connect API key
        env:
          ASC_KEY_B64: ${{ secrets.ASC_API_KEY_P8_BASE64 }}
        run: echo "$ASC_KEY_B64" | base64 -d > /tmp/asc_key.p8

      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v3
        with:
          app-path: apps/mobile/build/ios/ipa/*.ipa
          issuer-id: ${{ secrets.ASC_ISSUER_ID }}
          api-key-id: ${{ secrets.ASC_KEY_ID }}
          api-private-key: ${{ secrets.ASC_API_KEY_P8_BASE64 }}

      - name: Attach IPA to GitHub Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: apps/mobile/build/ios/ipa/*.ipa
```

> Implementation note: `apple-actions/upload-testflight-build@v3` accepts the base64 `.p8` directly via `api-private-key`; the `/tmp/asc_key.p8` decode step is a fallback if a raw-file form is needed. Confirm the action's input format during the first dry run and drop the unused step. If `flutter build ipa` fails the archive-signing step, verify the `Release.xcconfig` append landed and `PROFILE_NAME` matches the profile embedded in the cert.

- [ ] **Step 2: Delete the superseded iOS workflow**

```bash
git rm .github/workflows/mobile-ios.yml
```

- [ ] **Step 3: Validate**

Run: `actionlint .github/workflows/mobile-release.yml`
Expected: no output (exit 0).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/mobile-release.yml
git commit -m "ci(mobile): build signed IPA->TestFlight and Release; drop mobile-ios.yml"
```

---

### Task 4: Documentation + secrets checklist

Rewrites `docs/mobile-cicd.md` for the consolidated workflow and fixes the Play packageName in the spec.

**Files:**
- Modify: `docs/mobile-cicd.md`
- Modify: `docs/superpowers/specs/2026-07-05-mobile-release-cicd-design.md` (packageName fix)

- [ ] **Step 1: Replace `docs/mobile-cicd.md` body**

Replace the file contents with:

````markdown
# Mobile CI/CD

`.github/workflows/mobile-release.yml` builds **both** apps and ships them to their beta channels. It runs on `release: published`, on `v*` tag pushes, and via manual **Run workflow** (`workflow_dispatch`).

- **Android:** signed `.aab` → Google Play **internal** track (`draft`), and signed `.apk` attached to the GitHub Release.
- **iOS:** signed `.ipa` → **TestFlight**, and the `.ipa` attached to the GitHub Release.

Version name comes from the tag (`v1.2.3` → `1.2.3`) or the `build_name` input on manual runs; build number is the workflow run number.

## Required GitHub Actions secrets

Repo → Settings → Secrets and variables → Actions.

| Secret | What |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` output |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console service-account JSON (release perms) |
| `API_BASE_URL` | deployed backend base URL |
| `AUTH0_DOMAIN` | Auth0 tenant domain |
| `AUTH0_CLIENT_ID` | Auth0 SPA client id |
| `AUTH0_AUDIENCE` | Auth0 API audience |
| `MAPS_API_KEY` | Google Maps SDK for Android key |
| `IOS_DIST_CERT_P12_BASE64` | base64 of the Apple Distribution cert `.p12` |
| `IOS_DIST_CERT_PASSWORD` | password for that `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 of the App Store provisioning profile |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | App Store Connect issuer id |
| `ASC_API_KEY_P8_BASE64` | base64 of the App Store Connect `.p8` key |

## One-time manual prerequisites

**Apple**
1. Apple Developer Program membership.
2. App record in App Store Connect for bundle id `com.davissylvester.bjjOpenMat`.
3. Apple Distribution certificate exported as `.p12`.
4. App Store provisioning profile for that App ID.
5. App Store Connect API key (`.p8`) — note the Key ID and Issuer ID.

**Google Play** (package `com.davissylvester.bjjopenmat`)
1. App created in Play Console.
2. **Upload the first `.aab` manually** — Play rejects API uploads until an initial bundle exists.
3. Service account with release permissions; download its JSON key.

## Cut a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or publish a GitHub Release, or use **Actions → Mobile Release → Run workflow** (pass `build_name` on manual runs). The Android bundle lands on Play's `internal` track as a **draft** — promote it manually. The iOS build lands in **TestFlight**.

## Build locally

Android APK: see `bun run mobile:apk` (fills `.env` + `key.properties`).
iOS (macOS): `bun run mobile:ios` (unsigned release) or open `ios/Runner.xcworkspace` in Xcode to sign and archive.
````

- [ ] **Step 2: Fix the packageName note in the spec**

In `docs/superpowers/specs/2026-07-05-mobile-release-cicd-design.md`, change the Android upload `packageName` from `com.davissylvester.bjjOpenMat` to `com.davissylvester.bjjopenmat` (the lowercase Android `applicationId`).

Run: `grep -n "packageName" docs/superpowers/specs/2026-07-05-mobile-release-cicd-design.md`
Expected: the line shows `com.davissylvester.bjjopenmat`.

- [ ] **Step 3: Commit**

```bash
git add docs/mobile-cicd.md docs/superpowers/specs/2026-07-05-mobile-release-cicd-design.md
git commit -m "docs(cicd): document consolidated mobile release workflow + secrets"
```

---

## Post-implementation verification (requires maintainer-supplied secrets)

Not part of the task commits — run once the secrets exist:

1. **Static:** `actionlint .github/workflows/mobile-release.yml` → clean.
2. **Dry run:** Actions → Mobile Release → Run workflow with `build_name=0.1.0-ci-test`. Confirm the `android` job lands an AAB on Play's **internal/draft** track and the `ios` job lands a build in **TestFlight**. Both channels are non-public.
3. If iOS archive signing fails, verify `Release.xcconfig` received the team/profile lines and `PROFILE_NAME` matches the installed profile.
