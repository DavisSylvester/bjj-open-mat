# Outstanding TODO

Follow-ups deferred after shipping the mobile APK + AWS API deploy + custom domain + Auth0 login (all working end-to-end as of 2026-07-05). None are blocking; ordered roughly by value.

## Shipped 2026-07-06 (merged to main, PR #9 + prior)
- Gym logo upload (S3 presigned URL) + display; "I'm going" RSVP fix + attendee card; ZIP→city search.
- Glass-only theme (Sport removed); bottom nav restructure (Schedule→Profile, Report tab in both shells).
- Branded belt icons + paged attendee grid; server-synced search preferences.
- In-app Report (bug/feature) → Mongo + GitHub issue; CDK resources renamed to `bjj-open-mat-*`.
- Spec/plan: `docs/superpowers/{specs,plans}/2026-07-05-nav-report-belt-prefs-glass-*.md`.

## New follow-ups from the 2026-07-06 session
- [ ] **Activate Report→GitHub in prod.** Add a `repo`-scoped PAT as `GITHUB_TOKEN` (and optionally `GITHUB_REPO`) to the `bjj-open-mat/app` secret (`aws secretsmanager put-secret-value ...`); the API picks it up on next cold start. Until then reports save to Mongo only. Confirm the repo has `bug` and `enhancement` labels (GitHub defaults).
- [x] **GPS chip fixed** (2026-07-07). Root cause was missing `ACCESS_FINE/COARSE_LOCATION` in AndroidManifest — the runtime permission auto-denied, so `current()` returned null and the chip silently no-op'd. Declared both permissions; also switched capture to medium accuracy + 10s, added a `getLastKnownPosition()` fallback on timeout, and a SnackBar on failure. First open now prompts for location and auto-searches nearby (v9).
- [ ] **Emulator smoke-test the new UI** on a fresh build: Home/Find/Profile/Report nav, My Training under Profile, Report form submit, belt-icon paged attendee grid, "Save as default" search prefs.

## Infra / security
- [ ] **Harden MongoDB Atlas network access.** Currently the Atlas IP allowlist is `0.0.0.0/0` (protected only by SCRAM auth + TLS). Lambda has no fixed egress IP, so real hardening needs either Atlas **PrivateLink** + Lambda-in-VPC, or a **VPC + NAT Gateway** (static egress IP, ~$32/mo) to allowlist. Its own brainstorm → plan effort.
- [ ] **Bump CI actions off Node 20.** `api-deploy.yml` (and the mobile workflows) use `actions/*@v4` on Node 20, which GitHub deprecated (runner forces Node 24). Bump `setup-node` to `node-version: '24'` and refresh action versions. Cosmetic warning today.

## Mobile release CI (tag-triggered Android build)
- [x] **GitHub secrets set** (2026-07-06) so `mobile-release.yml` (tag `v*`) builds + signs + uploads. All present: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`, `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` (Native id `su1v…`), `AUTH0_AUDIENCE`, `MAPS_API_KEY`, `PLAY_SERVICE_ACCOUNT_JSON` (SA `github@bjj-open-mat-501702…`, granted "Release to testing tracks" via Play Console → Users and permissions).
- [ ] **versionCode gotcha before first CI publish.** `mobile-release.yml` sets `--build-number=${{ github.run_number }}`. Play requires a strictly-increasing versionCode; the manual v6 upload is versionCode 6, so the first CI run must have `run_number > 6` (or override via the `build_name`/a build-number bump) or Play rejects it. Check the Actions run count before tagging.
- [ ] **iOS job will fail on tag** until the Apple secrets exist (`IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_TEAM_ID`, `ASC_*`). The Android job is independent and still succeeds; the red iOS job is expected until the Apple Developer account is set up.

## Auth0
- [x] **Switched mobile callback to a custom scheme** (2026-07-06). `auth0Scheme` is now `com.davissylvester.bjjopenmat` (build.gradle.kts) and `AuthService` passes `webAuthentication(scheme: …)` on native login/logout — fixes the post-login "Not found" (https App Links weren't verified under Play App Signing). **Auth0 dashboard step required:** add this to **bjj-open-mat-native → Allowed Callback URLs AND Allowed Logout URLs**:
  `com.davissylvester.bjjopenmat://dev-vhvwupdn45hk7gct.us.auth0.com/android/com.davissylvester.bjjopenmat/callback`
  (iOS variant, same pattern with `/ios/`, if/when iOS ships.)
- [ ] **Own Google OAuth keys** — replace Auth0 dev keys on the google-oauth2 connection. Runbook: `docs/auth0-google-oauth.md`. (Login already verified working; this removes the dev-keys warning + brands the consent screen.)

## iOS (deferred until Apple Developer account)
- [ ] **Enable installable iOS builds.** Requires an Apple Developer account ($99/yr): signing certs + provisioning, then wire release signing into CI (iOS builds a signed IPA to TestFlight via `.github/workflows/mobile-release.yml`; what remains is supplying the Apple secrets).
- [ ] **Wire iOS Google Maps key.** Enable **Maps SDK for iOS**, create a separate key restricted by bundle id `com.davissylvester.bjjopenmat`, and add `GMSServices.provideAPIKey(...)` in `ios/Runner/AppDelegate.swift` with a build-time define (the API's `.env` already holds `MAPS_IOS_API_KEY`).
