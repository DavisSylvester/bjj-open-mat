# Android APK Build + Mobile CI/CD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a signed, installable Android release APK and a tag-triggered GitHub Actions pipeline that builds/delivers the Android APK (Release + artifact) and compile-checks iOS.

**Architecture:** Wire real release signing + config (Auth0 domain, Maps key) into the existing Flutter Android Gradle build via `key.properties` / gradle properties, sourced from `--dart-define` + secrets. Two GitHub Actions workflows (Android build on `ubuntu-latest`, iOS compile-check on `macos-latest`) trigger on `v*` tags and manual dispatch. iOS platform is scaffolded and committed but not signed.

**Tech Stack:** Flutter 3.41.x (stable), Android Gradle Plugin 8.11 (Kotlin DSL), `subosito/flutter-action`, `softprops/action-gh-release`, `actions/setup-java` (Temurin 17), `keytool`.

**Reference spec:** `docs/superpowers/specs/2026-07-04-android-apk-and-mobile-cicd-design.md`

---

## Key facts (verified against the repo)

- App root: `apps/mobile`. Platforms present: `android/`, `web/` only (no `ios/`).
- `MainActivity.kt` package is `com.example.bjj_open_mat` → **`namespace` stays `com.example.bjj_open_mat`**; only `applicationId` changes (they are decoupled; changing namespace would require moving the Kotlin file).
- `android/app/build.gradle.kts` already declares `manifestPlaceholders["auth0Domain"]="your-tenant.auth0.com"` and `["auth0Scheme"]="https"` — used by `auth0_flutter` for the login callback intent. This must receive the real Auth0 domain at build time.
- Compile-time config via `--dart-define`: `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`.
- No Google Maps key in the manifest yet.
- Root `.gitignore` ignores `.env` / `.env.*` (keeps `.env.example`).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `apps/mobile/.gitignore` | Modify | Ignore keystores + `key.properties` |
| `apps/mobile/android/app/build.gradle.kts` | Modify | Real applicationId, release signingConfig, gradle-property-driven `auth0Domain` + `MAPS_API_KEY` placeholders |
| `apps/mobile/android/key.properties.example` | Create | Documented template for local signing |
| `apps/mobile/android/app/src/main/AndroidManifest.xml` | Modify | Add Google Maps `meta-data` using `${MAPS_API_KEY}` placeholder |
| `apps/mobile/.env.example` | Create | Documents dart-define keys for local `mobile:apk` builds |
| `package.json` | Modify | Add `mobile:apk` script |
| `apps/mobile/ios/**` | Create | Scaffolded iOS platform (via `flutter create`) |
| `.github/workflows/mobile-android.yml` | Create | Tag-triggered signed APK build + Release + artifact |
| `.github/workflows/mobile-ios.yml` | Create | Tag-triggered iOS compile-check (no signing) |
| `docs/mobile-cicd.md` | Create | Secrets inventory + how to build/tag/install |

> **Note on verification:** This is an infrastructure plan; "tests" are build-and-observe checks (Gradle/Flutter builds), not unit tests. Each task ends by running a real build/command and confirming output.

---

## Task 1: Ignore signing secrets from git

**Files:**
- Modify: `apps/mobile/.gitignore`

- [ ] **Step 1: Append keystore ignore rules**

Add to the end of `apps/mobile/.gitignore`:

```gitignore
# Android signing (never commit)
/android/key.properties
**/*.jks
**/*.keystore
```

- [ ] **Step 2: Verify the rules are effective**

Run:
```bash
cd apps/mobile && printf 'x' > android/key.properties && printf 'x' > android/app/test.jks
git check-ignore android/key.properties android/app/test.jks
rm android/key.properties android/app/test.jks
```
Expected: both paths are printed (meaning they are ignored).

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/.gitignore
git commit -m "chore(mobile): gitignore android keystores and key.properties"
```

---

## Task 2: Set a real application ID

**Files:**
- Modify: `apps/mobile/android/app/build.gradle.kts:22-24`

- [ ] **Step 1: Change the applicationId**

Replace lines 23-24:

```kotlin
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bjj_open_mat"
```

with:

```kotlin
        applicationId = "com.davissylvester.bjjopenmat"
```

Leave `namespace = "com.example.bjj_open_mat"` (line 9) **unchanged** — it must keep matching the `MainActivity.kt` package.

- [ ] **Step 2: Verify Gradle still configures**

Run:
```bash
cd apps/mobile && flutter pub get && flutter build apk --debug
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/android/app/build.gradle.kts
git commit -m "chore(mobile): set real applicationId com.davissylvester.bjjopenmat"
```

---

## Task 3: Add release signing config driven by key.properties / env

**Files:**
- Modify: `apps/mobile/android/app/build.gradle.kts`
- Create: `apps/mobile/android/key.properties.example`

- [ ] **Step 1: Add key.properties loading at the top of the file**

Insert immediately after the `plugins { ... }` block (before `android {`):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Resolve a signing value from key.properties first, then an env var (CI).
fun signingValue(propKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propKey) ?: System.getenv(envKey)
```

- [ ] **Step 2: Declare the release signingConfig and use it**

Replace the entire `buildTypes { ... }` block (lines 35-41) with:

```kotlin
    signingConfigs {
        create("release") {
            val storeFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore when configured; otherwise fall back to
            // debug signing so a fresh clone without key.properties still builds.
            signingConfig = if (signingValue("storeFile", "ANDROID_KEYSTORE_PATH") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 3: Create the template file**

Create `apps/mobile/android/key.properties.example`:

```properties
# Copy to key.properties (gitignored) for local release signing.
# Generate the keystore with (run once):
#   keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
#     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=CHANGE_ME
keyAlias=upload
keyPassword=CHANGE_ME
```

- [ ] **Step 4: Verify config still resolves without key.properties (debug fallback)**

Run:
```bash
cd apps/mobile && flutter build apk --debug
```
Expected: build succeeds (no `key.properties` present → debug fallback path taken).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/android/app/build.gradle.kts apps/mobile/android/key.properties.example
git commit -m "feat(mobile): release signing config from key.properties or env"
```

---

## Task 4: Generate the release keystore (local, not committed)

**Files:** none committed — produces `apps/mobile/android/upload-keystore.jks` (gitignored) and local `key.properties`.

- [ ] **Step 1: Generate the keystore**

Run (replace passwords; keytool ships with the JDK Flutter uses):
```bash
cd apps/mobile/android
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Answer the prompts (name/org/etc.); note the store + key passwords.

- [ ] **Step 2: Create local key.properties**

Create `apps/mobile/android/key.properties` (gitignored) from the example, with the real absolute `storeFile` path and passwords.

- [ ] **Step 3: Verify a signed release APK builds**

Run:
```bash
cd apps/mobile && flutter build apk --release \
  --dart-define=API_BASE_URL=https://example.invalid \
  --dart-define=AUTH0_DOMAIN=example.auth0.com \
  --dart-define=AUTH0_CLIENT_ID=x --dart-define=AUTH0_AUDIENCE=x
```
Expected: `✓ Built .../app-release.apk`. (URLs are throwaway here — this only proves signing works.)

- [ ] **Step 4: Confirm the APK is signed with the release key (not debug)**

Run:
```bash
cd apps/mobile && unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "META-INF/.*\.\(RSA\|SF\)"
```
Expected: a `META-INF/UPLOAD.(RSA|SF)`-style entry appears (alias `upload`), confirming release signing.

- [ ] **Step 5: Produce the base64 for the GitHub secret**

Run:
```bash
cd apps/mobile/android && base64 -w0 upload-keystore.jks > upload-keystore.b64
echo "Wrote upload-keystore.b64 — paste its contents into the ANDROID_KEYSTORE_BASE64 secret, then delete the file."
```
No commit (all artifacts are gitignored). Report the secret values to the user; do not commit or print the keystore contents into any tracked file.

---

## Task 5: Wire Auth0 domain + Google Maps key into the manifest via gradle properties

**Files:**
- Modify: `apps/mobile/android/app/build.gradle.kts` (`defaultConfig` placeholders)
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Drive placeholders from gradle properties / env with safe defaults**

In `build.gradle.kts`, replace the two existing placeholder lines (currently lines 31-32):

```kotlin
        manifestPlaceholders["auth0Domain"] = "your-tenant.auth0.com"
        manifestPlaceholders["auth0Scheme"] = "https"
```

with:

```kotlin
        // Overridable at build time: -Pauth0Domain=... -PmapsApiKey=... (CI passes these from secrets).
        manifestPlaceholders["auth0Domain"] =
            (project.findProperty("auth0Domain") as String?) ?: System.getenv("AUTH0_DOMAIN") ?: "your-tenant.auth0.com"
        manifestPlaceholders["auth0Scheme"] = "https"
        manifestPlaceholders["mapsApiKey"] =
            (project.findProperty("mapsApiKey") as String?) ?: System.getenv("MAPS_API_KEY") ?: ""
```

- [ ] **Step 2: Add the Maps meta-data to the manifest**

In `AndroidManifest.xml`, add inside `<application>` (immediately after line 5, the opening `<application ...>` tag closes with `>`):

```xml
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${mapsApiKey}"/>
```

- [ ] **Step 3: Verify placeholder override works**

Run:
```bash
cd apps/mobile && flutter build apk --debug -Pauth0Domain=my-tenant.auth0.com -PmapsApiKey=TESTKEY123
unzip -p build/app/outputs/flutter-apk/app-debug.apk AndroidManifest.xml | strings | grep -i -E "TESTKEY123|my-tenant" || echo "check manually"
```
Expected: the build succeeds. (Binary manifest is compiled; the grep is best-effort — success of the build with placeholders resolved is the real signal.)

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/android/app/build.gradle.kts apps/mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat(mobile): inject auth0 domain and google maps key via gradle properties"
```

---

## Task 6: Local APK build script + env template

**Files:**
- Modify: `package.json` (scripts)
- Create: `apps/mobile/.env.example`

- [ ] **Step 1: Create the dart-define env template**

Create `apps/mobile/.env.example`:

```dotenv
# Copy to apps/mobile/.env (gitignored) and fill in before building the APK.
# Consumed via --dart-define-from-file=.env
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-spa-client-id
AUTH0_AUDIENCE=https://your-api-audience
```

- [ ] **Step 2: Add the mobile:apk script**

In root `package.json`, add after the `"mobile:build"` line (keep it comma-correct):

```json
    "mobile:apk": "cd apps/mobile && flutter build apk --release --dart-define-from-file=.env --dart-define=API_BASE_URL=${API_BASE_URL:-https://example.invalid} -Pauth0Domain=$AUTH0_DOMAIN -PmapsApiKey=$MAPS_API_KEY"
```

> Local usage: set `API_BASE_URL`, `AUTH0_DOMAIN`, `MAPS_API_KEY` in your shell (or export from a local env file), ensure `apps/mobile/.env` exists, then `bun run mobile:apk`. The APK lands at `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 3: Verify the script is registered**

Run:
```bash
bun run mobile:apk --help 2>/dev/null || npm run 2>/dev/null | grep mobile:apk || grep mobile:apk package.json
```
Expected: `mobile:apk` appears.

- [ ] **Step 4: Commit**

```bash
git add package.json apps/mobile/.env.example
git commit -m "feat(mobile): add mobile:apk release build script and env template"
```

---

## Task 7: Scaffold and commit the iOS platform

**Files:**
- Create: `apps/mobile/ios/**`

- [ ] **Step 1: Generate the iOS platform folder**

Run:
```bash
cd apps/mobile && flutter create --platforms=ios --project-name bjj_open_mat .
```
Expected: creates `ios/Runner.xcodeproj`, `ios/Runner/Info.plist`, `ios/Flutter/`, etc.

- [ ] **Step 2: Verify the workspace still resolves**

Run:
```bash
cd apps/mobile && flutter pub get
```
Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/ios
git commit -m "chore(mobile): scaffold ios platform for compile-check CI"
```

---

## Task 8: Android build & release workflow

**Files:**
- Create: `.github/workflows/mobile-android.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/mobile-android.yml`:

```yaml
name: Mobile Android

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

permissions:
  contents: write   # needed to create/update the GitHub Release

jobs:
  build-android:
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
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks

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

      - name: Build release APK
        run: |
          flutter build apk --release \
            --build-number=${{ github.run_number }} \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
            --dart-define=AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN }} \
            --dart-define=AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID }} \
            --dart-define=AUTH0_AUDIENCE=${{ secrets.AUTH0_AUDIENCE }} \
            -Pauth0Domain=${{ secrets.AUTH0_DOMAIN }} \
            -PmapsApiKey=${{ secrets.MAPS_API_KEY }}

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: bjj-open-mat-apk
          path: apps/mobile/build/app/outputs/flutter-apk/app-release.apk

      - name: Publish to GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 2: Validate YAML syntax locally**

Run:
```bash
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/mobile-android.yml')); print('YAML OK')"
```
Expected: `YAML OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/mobile-android.yml
git commit -m "ci(mobile): build and release signed android apk on tags"
```

---

## Task 9: iOS compile-check workflow

**Files:**
- Create: `.github/workflows/mobile-ios.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/mobile-ios.yml`:

```yaml
name: Mobile iOS (compile check)

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-ios:
    runs-on: macos-latest
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

      - name: Build iOS (no code signing)
        run: |
          flutter build ios --release --no-codesign \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
            --dart-define=AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN }} \
            --dart-define=AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID }} \
            --dart-define=AUTH0_AUDIENCE=${{ secrets.AUTH0_AUDIENCE }}
```

- [ ] **Step 2: Validate YAML syntax locally**

Run:
```bash
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/mobile-ios.yml')); print('YAML OK')"
```
Expected: `YAML OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/mobile-ios.yml
git commit -m "ci(mobile): add ios compile-check workflow on tags"
```

---

## Task 10: Document secrets + build/tag/install procedure

**Files:**
- Create: `docs/mobile-cicd.md`

- [ ] **Step 1: Write the doc**

Create `docs/mobile-cicd.md`:

```markdown
# Mobile CI/CD

Builds run on git tags matching `v*` (and manual **Run workflow**).

## Required GitHub Actions secrets
Repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | What |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` output |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password |
| `API_BASE_URL` | deployed backend base URL |
| `AUTH0_DOMAIN` | Auth0 tenant domain |
| `AUTH0_CLIENT_ID` | Auth0 SPA client id |
| `AUTH0_AUDIENCE` | Auth0 API audience |
| `MAPS_API_KEY` | Google Maps SDK for Android key |

## Cut a build
```bash
git tag v0.1.0
git push origin v0.1.0
```
The Android job builds a signed APK, uploads it as the `bjj-open-mat-apk` artifact, and attaches it to the GitHub Release for the tag. The iOS job compile-checks only.

## Build an APK locally
1. `cp apps/mobile/.env.example apps/mobile/.env` and fill in Auth0 values.
2. `cp apps/mobile/android/key.properties.example apps/mobile/android/key.properties` and fill in.
3. `export API_BASE_URL=https://your-api MAPS_API_KEY=... AUTH0_DOMAIN=...`
4. `bun run mobile:apk`
5. Install: `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

## iOS (deferred)
`ios/` is scaffolded and compile-checked in CI. Installable iOS builds require an Apple Developer account (signing certs + provisioning) and are out of scope until then.
```

- [ ] **Step 2: Commit**

```bash
git add docs/mobile-cicd.md
git commit -m "docs(mobile): document mobile CI/CD secrets and build procedure"
```

---

## Manual acceptance (after secrets are set by the user)

- [ ] User sets all secrets from `docs/mobile-cicd.md`.
- [ ] Push a `v*` tag; confirm the Android workflow is green and a Release with `app-release.apk` appears.
- [ ] Download + `adb install` the APK on a physical device.
- [ ] Launch: app reaches the deployed API, Auth0 login succeeds, Google Maps renders.
- [ ] Confirm the iOS compile-check job is green.

## Out of scope

iOS signing/TestFlight, Play Store publishing, Firebase App Distribution, web deploy.
