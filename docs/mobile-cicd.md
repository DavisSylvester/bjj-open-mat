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
