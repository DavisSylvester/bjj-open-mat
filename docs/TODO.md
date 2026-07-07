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
- [ ] **GPS chip `getLastKnownPosition` fallback.** The search GPS chip can hang when `getCurrentPosition(high, 8s)` times out waiting for a fresh fix (emulator returns null). Add a `getLastKnownPosition()` fallback so the chip resolves to the last known coords. (Reported earlier; not yet implemented.)
- [ ] **Emulator smoke-test the new UI** on a fresh build: Home/Find/Profile/Report nav, My Training under Profile, Report form submit, belt-icon paged attendee grid, "Save as default" search prefs.

## Infra / security
- [ ] **Harden MongoDB Atlas network access.** Currently the Atlas IP allowlist is `0.0.0.0/0` (protected only by SCRAM auth + TLS). Lambda has no fixed egress IP, so real hardening needs either Atlas **PrivateLink** + Lambda-in-VPC, or a **VPC + NAT Gateway** (static egress IP, ~$32/mo) to allowlist. Its own brainstorm → plan effort.
- [ ] **Bump CI actions off Node 20.** `api-deploy.yml` (and the mobile workflows) use `actions/*@v4` on Node 20, which GitHub deprecated (runner forces Node 24). Bump `setup-node` to `node-version: '24'` and refresh action versions. Cosmetic warning today.

## Mobile release CI (tag-triggered Android build)
- [ ] **Set the remaining GitHub secrets** so `mobile-release.yml` (tag `v*`) produces a signed release build. `MAPS_API_KEY` is set; still need: `ANDROID_KEYSTORE_BASE64` (from `.android-keystore.b64`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`, plus `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` (the Native id `su1v…`), `AUTH0_AUDIENCE`. See `docs/mobile-cicd.md`.

## Auth0
- [x] **Switched mobile callback to a custom scheme** (2026-07-06). `auth0Scheme` is now `com.davissylvester.bjjopenmat` (build.gradle.kts) and `AuthService` passes `webAuthentication(scheme: …)` on native login/logout — fixes the post-login "Not found" (https App Links weren't verified under Play App Signing). **Auth0 dashboard step required:** add this to **bjj-open-mat-native → Allowed Callback URLs AND Allowed Logout URLs**:
  `com.davissylvester.bjjopenmat://dev-vhvwupdn45hk7gct.us.auth0.com/android/com.davissylvester.bjjopenmat/callback`
  (iOS variant, same pattern with `/ios/`, if/when iOS ships.)
- [ ] **Own Google OAuth keys** — replace Auth0 dev keys on the google-oauth2 connection. Runbook: `docs/auth0-google-oauth.md`. (Login already verified working; this removes the dev-keys warning + brands the consent screen.)

## iOS (deferred until Apple Developer account)
- [ ] **Enable installable iOS builds.** Requires an Apple Developer account ($99/yr): signing certs + provisioning, then wire release signing into CI (iOS builds a signed IPA to TestFlight via `.github/workflows/mobile-release.yml`; what remains is supplying the Apple secrets).
- [ ] **Wire iOS Google Maps key.** Enable **Maps SDK for iOS**, create a separate key restricted by bundle id `com.davissylvester.bjjopenmat`, and add `GMSServices.provideAPIKey(...)` in `ios/Runner/AppDelegate.swift` with a build-time define (the API's `.env` already holds `MAPS_IOS_API_KEY`).
