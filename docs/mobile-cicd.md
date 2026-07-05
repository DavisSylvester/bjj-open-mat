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
