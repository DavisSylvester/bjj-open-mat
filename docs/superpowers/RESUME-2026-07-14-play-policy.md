# Resume Notes — Google Play "Misleading Claims" Resubmission

**Date:** 2026-07-14
**App:** BJJ Open Mat (`com.davissylvester.bjjopenmat`)
**Work branch:** `feature/play-policy-real-features` → **PR #17** (base `main`)
**This branch:** `feature/play-policy-resume` (adds only this doc)

---

## TL;DR — where we are

Google rejected the app under the **Misleading Claims** policy. Root causes:
1. Store screenshot showed a **"Schedule" tab that no longer exists**.
2. In-app: **empty discovery** for a reviewer with no nearby mats, and the profile
   screen showed a **raw `auth0-…` subject id** as the name (evidence `IN_APP_EXPERIENCE-2809.png`).

All fixes are **coded, committed, tested, and on PR #17**. A signed release AAB
(**versionCode 16**) was built and verified on the emulator. The production DB was
cleaned to contain only real data. **Remaining work is manual Play Console steps.**

---

## ✅ Done

- **Discovery fix** — bogus `(0,0)` GPS now falls back to browse-all (`location_service.dart`).
- **Profile identity fix** — API persists provider name/email for db users; client guards
  against a leaked raw provider id / synthetic email (`user.facade.mts`, `profile_view.dart`).
- **Mock data purged** — seed script deleted AND the seeded records were **deleted from the
  production Atlas DB**. Prod now returns exactly **one** open mat: **RM Elite Brazilian
  Jiu-Jitsu** (Van Alstyne, TX, ZIP 75495). Also removed "Logo Test Academy" and an
  orphaned duplicate "Renzo Westwood" open mat.
- **`gymId` filter** honored on the open-mats list endpoint.
- **Real-feature wiring** (were stubs): My Training, Favorites, Gym Detail, Notifications, Directions.
- **Version bumped** to `0.1.0+16` (commit `b635bcc`).
- **Branch pushed**, **PR #17 opened** to `main`.

## 📦 Artifacts (on the ORIGINAL Mac's Desktop — not in git)

- `~/Desktop/bjj-open-mat-v0.1.0-build16.aab` — signed release AAB, versionCode 16.
- `~/Desktop/bjj-play-screenshots/` — 3 store screenshots (1080×2160, 2:1):
  `1-find-open-mat-by-zip.png`, `2-open-mat-details.png`, `3-your-profile.png`.

> These are NOT committed. If resuming on another machine, **rebuild the AAB** (see below)
> and **re-capture screenshots** (or copy these files over).

---

## ⏭️ Remaining work — Play Console (manual)

Do these in order:

1. **Publishing overview → Remove changes** — pull the old in-review Production release
   (it contains the OLD, rejected binary) out of review. Screenshots stay as drafts.
2. **Test and release → App bundle explorer** — confirm the highest uploaded versionCode
   is ≤ 15. If it's already ≥ 16, rebuild with a higher build number.
3. **Test and release → Production → Create new release** → upload the **versionCode 16** AAB.
   - Release name: `0.1.0 (16) – policy fixes`
   - Release notes: "Fixed open-mat discovery so nearby sessions load reliably, cleaned up
     the profile screen, and removed all placeholder data. The app now shows only real,
     community-submitted open mats."
4. **Test and release → App content → App access** → "All or some functionality is
   restricted" → add reviewer instructions:
   ```
   1. Sign in with the credentials above.
   2. Tap "Find" at the bottom, enter ZIP 75495 in the ZIP field, submit.
   3. A live open mat appears: "RM Elite Brazilian Jiu-Jitsu", Van Alstyne, TX.
   4. Tap it for details, directions, RSVP, and check-in.
   Results are location-based; other areas may show none, which is expected.
   ```
   (Include a working demo login username/password.)
5. **Review release → Start rollout** → **Publishing overview → Send changes for review.**

---

## 🔨 How to rebuild the AAB on another machine

**You need three things that are NOT in git** (they are gitignored secrets):

1. **Upload keystore** — on the original Mac at `/Users/dsylvester/keys/bjj-open-mat/upload-keystore.jks`.
   Copy it to the new machine (any path) and update `android/key.properties`.
2. **`apps/mobile/android/key.properties`** — points at the keystore and holds the
   store/key passwords + alias. Recreate it:
   ```
   storeFile=/absolute/path/to/upload-keystore.jks
   storePassword=<from original>
   keyAlias=<from original>
   keyPassword=<from original>
   ```
3. **`apps/mobile/.env`** — holds `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_AUDIENCE`.

Then build:
```bash
cd apps/mobile
flutter pub get
flutter build appbundle --release \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io
# Output: build/app/outputs/bundle/release/app-release.aab  (versionCode 16)
```

**Alternative — build via CI (no local secrets needed):** the `mobile-release` GitHub
Actions workflow has the keystore + Auth0 + Play service-account credentials as secrets.
Trigger it (`workflow_dispatch`, or a `v*` tag) to build/sign the AAB and upload a draft
to the Internal track, then promote it in Play Console. This is the easiest path on a
fresh machine.

---

## ⚠️ Gotchas / decisions on record

- **Merging PR #17 to `main` triggers `api-deploy` and DEPLOYS THE API to production**
  (branch touches `apps/api/**`). Decide when you want that. The client already guards the
  profile-id issue without the API deploy, so merging is optional for the Play fix.
- **API deploy was intentionally deferred** ("build only, don't deploy API yet").
- The emulator screenshots reflect the FIXED local code (the app was run from source with
  all commits). The API deployed in prod is still the OLD version, but the client-side
  guard makes the profile show "BJJ Practitioner" regardless.
- Prod API base URL: `https://api.bjj-open-mat.dsylvester.io`. Prod DB: Atlas `bjj_open_mat`.
- Auth: SPA client id ends `…HYX0qf`; AUTH0_DOMAIN `dev-vhvwupdn45hk7gct.us.auth0.com`.

---

## Key commits (on `feature/play-policy-real-features`)

```
b635bcc chore(mobile): bump versionCode to 16 for Play resubmission
b6db872 fix(profile): client-side guard so a leaked raw provider id never shows as a name
639157c test(api): fix fake repo types in user-facade test
1b66ac4 chore(api): remove mock seed data — real DB data only
ae92710 fix(profile): persist provider name/email for db users and never render raw Auth0 id
0ff4eb6 fix(mobile): reject bogus (0,0) GPS so discovery falls back to browse-all
ccf69ee fix(api): honor gymId filter on open-mats list endpoint
```
