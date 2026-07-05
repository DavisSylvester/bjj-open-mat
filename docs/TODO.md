# Outstanding TODO

Follow-ups deferred after shipping the mobile APK + AWS API deploy + custom domain + Auth0 login (all working end-to-end as of 2026-07-05). None are blocking; ordered roughly by value.

## Infra / security
- [ ] **Harden MongoDB Atlas network access.** Currently the Atlas IP allowlist is `0.0.0.0/0` (protected only by SCRAM auth + TLS). Lambda has no fixed egress IP, so real hardening needs either Atlas **PrivateLink** + Lambda-in-VPC, or a **VPC + NAT Gateway** (static egress IP, ~$32/mo) to allowlist. Its own brainstorm → plan effort.
- [ ] **Bump CI actions off Node 20.** `api-deploy.yml` (and the mobile workflows) use `actions/*@v4` on Node 20, which GitHub deprecated (runner forces Node 24). Bump `setup-node` to `node-version: '24'` and refresh action versions. Cosmetic warning today.

## Mobile release CI (tag-triggered Android build)
- [ ] **Set the remaining GitHub secrets** so `mobile-release.yml` (tag `v*`) produces a signed release build. `MAPS_API_KEY` is set; still need: `ANDROID_KEYSTORE_BASE64` (from `.android-keystore.b64`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`, plus `API_BASE_URL`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` (the Native id `su1v…`), `AUTH0_AUDIENCE`. See `docs/mobile-cicd.md`.

## Auth0
- [ ] **(Optional) Switch mobile callback to a custom scheme.** Today it uses the `https` App Links scheme (`auth0Scheme=https`), which requires the release SHA-256 registered for App Links. Flipping `auth0Scheme` → `com.davissylvester.bjjopenmat` in `apps/mobile/android/app/build.gradle.kts` drops the fingerprint/App-Links requirement (callback becomes `com.davissylvester.bjjopenmat://…`). Simpler; needs an APK rebuild + Auth0 URL update.

## iOS (deferred until Apple Developer account)
- [ ] **Enable installable iOS builds.** Requires an Apple Developer account ($99/yr): signing certs + provisioning, then wire release signing into CI (iOS builds a signed IPA to TestFlight via `.github/workflows/mobile-release.yml`; what remains is supplying the Apple secrets).
- [ ] **Wire iOS Google Maps key.** Enable **Maps SDK for iOS**, create a separate key restricted by bundle id `com.davissylvester.bjjopenmat`, and add `GMSServices.provideAPIKey(...)` in `ios/Runner/AppDelegate.swift` with a build-time define (the API's `.env` already holds `MAPS_IOS_API_KEY`).
