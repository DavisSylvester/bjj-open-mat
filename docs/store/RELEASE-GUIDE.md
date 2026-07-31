# BJJ Open Mat — Release Guide (Google Play)

Status of what's already done in the repo:

- ✅ `INTERNET` + location permissions added to the release manifest
- ✅ App display name set to **BJJ Open Mat**
- ✅ Brand app icons generated (Android adaptive + iOS)
- ✅ Version set in `apps/mobile/pubspec.yaml` (bump the `+N` build number every upload)
- ✅ Upload keystore created + `android/key.properties` wired
- ✅ Signed release bundle built & verified:
  `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- ✅ Store copy: `docs/store/privacy-policy.html`, `play-listing.md`
- ⬜ Store graphics: the 512×512 icon and 1024×500 feature graphic still need to
  be rendered from the current brand kit (`apps/mobile/tool/branding/`, source
  `brand/openmat-logo-stacked.svg`). `tool/branding/app-icon-512.png` is the
  current icon art; the feature graphic has no source yet.

Below are the steps that require **your** accounts/logins.

---

## 0. 🔐 BACK UP YOUR KEYSTORE (do this first, once)

If you lose this you cannot ship updates the normal way. Copy **all** of it to a
password manager / secure backup:

- File: `~/keys/bjj-open-mat/upload-keystore.jks`
- Alias: `upload`
- Password: (shown when it was generated — it's also in
  `apps/mobile/android/key.properties`, which is git-ignored)

Upload cert fingerprints (for reference):
- SHA-1: `29:88:E8:E2:2F:42:2E:D7:CE:1B:02:3C:C3:EF:67:44:FF:2B:92:12`
- SHA-256: `9C:60:B2:97:A5:AB:6A:95:AF:9B:AD:B0:2C:60:05:2E:DB:D1:4C:3B:6A:03:85:3A:08:81:26:09:89:8A:02:E5`

---

## 1. Google Maps API key (map is grey without this)

1. Go to <https://console.cloud.google.com> → create/select a project.
2. **APIs & Services → Enable APIs**: enable **Maps SDK for Android**
   (and **Geocoding** / **Places** if you use search).
3. **Credentials → Create credentials → API key.**
4. Restrict the key:
   - **Application restrictions → Android apps.**
   - Add package `com.davissylvester.bjjopenmat` + the **app-signing SHA-1**.
     Because Play re-signs your app (Play App Signing), the SHA-1 that matters in
     production is **Google's app-signing cert**, which you get in Play Console
     *after your first upload* (§4). For now you can also add the upload SHA-1
     above so internal-testing builds work.
   - **API restrictions → restrict to** the Maps APIs you enabled.
5. Rebuild with the key baked into the native manifest (§3).

## 2. Auth0 callback URLs (REQUIRED — login fails without this)

The app uses **custom URL schemes** for the Auth0 redirect (not https App Links —
see the login fix below). Auth0 must allow these exact URLs or `/authorize`
returns "Callback URL mismatch".

In Auth0 Dashboard → Applications → your app → **Settings**:

**Allowed Callback URLs** (add both, comma-separated):
```
com.davissylvester.bjjopenmat://dev-vhvwupdn45hk7gct.us.auth0.com/android/com.davissylvester.bjjopenmat/callback,
com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
```

**Allowed Logout URLs** (same two URLs):
```
com.davissylvester.bjjopenmat://dev-vhvwupdn45hk7gct.us.auth0.com/android/com.davissylvester.bjjopenmat/callback,
com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
```

Notes:
- Android scheme/id is lowercase (`com.davissylvester.bjjopenmat`); iOS keeps the
  bundle-id casing (`com.davissylvester.bjjOpenMat`). Copy exactly.
- These match the dev tenant currently in `apps/mobile/.env`. If you move to a
  production Auth0 tenant, swap the domain in the URLs and in `.env`.
- Save, then rebuild the app (§3). The custom scheme needs **no** Digital Asset
  Links / SHA registration — that requirement only applied to the old https flow.

### The login "Not found." bug — fixed in code (2026-07-06)
Two compounding bugs caused the post-Google "Not found." page:
1. `auth0Scheme` was `"https"` (an App Link needing domain verification Auth0
   doesn't provide) → now a custom scheme in `android/app/build.gradle.kts` +
   `auth_service.dart`.
2. The manifest `auth0Domain` placeholder defaulted to `your-tenant.auth0.com`
   because `--dart-define-from-file` doesn't reach Gradle → `build.gradle.kts`
   now reads `AUTH0_DOMAIN` from `apps/mobile/.env`, matching the Dart side.

## 3. Rebuild the production bundle (with the Maps key)

```bash
cd apps/mobile
export MAPS_API_KEY="<your-android-maps-key>"
flutter build appbundle --release --dart-define-from-file=.env
# -> build/app/outputs/bundle/release/app-release.aab
```

Bump `version:` in `pubspec.yaml` for every new upload (e.g. `1.0.1+2`).

---

## 4. Play Console — create & submit

<https://play.google.com/console> (you already have the account).

1. **Create app**: name *BJJ Open Mat*, language English (US), **App**, **Free**.
2. **Test first (recommended): Testing → Internal testing → Create release.**
   - Upload `app-release.aab`. Add yourself as a tester. Install via the opt-in
     link and confirm login, map, and location all work end-to-end.
   - On the first upload Play enrolls you in **Play App Signing** — go to
     **Release → Setup → App signing** and copy the **SHA-1 and SHA-256 of the
     app-signing certificate**. Feed those into Maps (§1) and Auth0 (§2).
3. **Complete "App content"** (left nav) — all required declarations:
   - **Privacy policy**: paste the hosted URL of `privacy-policy.html`
     (host it on GitHub Pages, Netlify, or any static host).
   - **Data safety**: enter the table in `play-listing.md`.
   - **Content rating**: questionnaire answers in `play-listing.md`.
   - **Target audience**, **Ads (No)**, **Government/Financial/Health (none)**,
     **News (No)**.
4. **Main store listing**: paste name / short / full description, upload the
   512×512 app icon and 1024×500 feature graphic (render both from the brand kit
   in `apps/mobile/tool/branding/` — see the checklist above), and 2–8
   screenshots from `docs/ios/images/`.
5. **Production → Create release**: upload the same (or a fresh) `.aab`, add
   release notes, select countries, **Review release → Roll out to production**.
6. First review typically takes a few hours to a few days.

---

## 5. Updating later

```bash
# bump version (e.g. 1.0.1+2) in apps/mobile/pubspec.yaml, then:
cd apps/mobile
export MAPS_API_KEY="<key>"
flutter build appbundle --release --dart-define-from-file=.env
```
Upload the new `.aab` to a new release. Same keystore, always.

## Notes / decisions still open
- **Support email**: `play-listing.md` and `privacy-policy.html` use a
  placeholder `support@bjj-open-mat.example`. Replace with a real inbox you
  monitor (Play shows it publicly).
- **Account deletion**: Play requires apps with sign-in to offer data deletion.
  Email-based request is covered by the privacy policy; an in-app "Delete
  account" action is the stronger form and may be requested during review.
- **Auth0 tenant**: dev vs. production — your call before public rollout.
