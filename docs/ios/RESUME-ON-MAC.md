# Resume Prompt — capture real iOS screenshots on a Mac

Paste the block below into a fresh Claude Code session on the Mac (Xcode + iOS Simulator installed).

---

```
You're resuming work on the BJJ Open Mat Flutter app on a Mac that has Xcode + the iOS Simulator. The repo was built on Windows, which can't compile iOS, so the iOS build and screenshots were deferred to this machine.

REPO: the `bjj-open-mat` Bun monorepo; the Flutter app is in `apps/mobile`. Work on branch `feature/monorepo-restructure` (PR #5 is open against `main`). Bundle id: com.davissylvester.bjjOpenMat, min iOS 13.

GOAL: Run the app in an iOS Simulator and capture REAL App Store screenshots, saving them to `docs/ios/images/` (this folder exists). Then commit them.

SETUP
1. `git checkout main && git pull` (PR #5 is merged)
2. At repo root: `bun install`
3. One-shot toolchain setup (idempotent): `bash scripts/mac-bootstrap.sh` — accepts the Xcode license, runs first-launch, ensures Flutter has Dart >= 3.7 (upgrades if not), (re)installs CocoaPods via Homebrew, and runs `flutter pub get` + `pod install`. (Or do those manually: `cd apps/mobile && flutter pub get && (cd ios && pod install)`.)
4. Open `ios/Runner.xcworkspace` in Xcode → Runner target → Signing & Capabilities → set your Team; also enable "Sign in with Apple" (the app offers Apple login). See `docs/apple-app-registration.md`.

AUTH — pick ONE way to reach seeded, logged-in screens:
  (A) FAST — dev bypass against a LOCAL API (no real login):
      - In one terminal: `bun run api:dev` (serves http://localhost:3100). If it needs MongoDB, use a local/Atlas URI (non-SRV, percent-encoded password).
      - Launch flags: `--dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret --dart-define=API_BASE_URL=http://127.0.0.1:3100`
      - On the iOS Simulator use 127.0.0.1 / localhost (NOT 10.0.2.2). DEV_BYPASS logs you in as a demo GYM OWNER.
  (B) REAL — production API + real Auth0 login:
      - `--dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io`, then log in with a real account.
      - Requires the Auth0 Native app to include the iOS callback/logout URL:
        com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
  Auth0 env (in apps/mobile/.env): AUTH0_DOMAIN=dev-vhvwupdn45hk7gct.us.auth0.com, AUTH0_AUDIENCE=https://www.bjj-open-mat, AUTH0_CLIENT_ID=su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf

RUN (6.5" device = 1242×2688: iPhone 11 Pro Max or iPhone 14 Plus)
  xcrun simctl boot "iPhone 11 Pro Max" 2>/dev/null; open -a Simulator
  cd apps/mobile
  flutter run -d "iPhone 11 Pro Max" \
    --dart-define-from-file=.env \
    -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com \
    <the AUTH flags from A or B above>
  Use the default GLASS theme (it's the default — don't switch to the Sport/ticker theme).

CAPTURE (native res == exactly what App Store Connect wants; run mkdir first)
  mkdir -p ../../docs/ios/images
  Navigate to each screen, then:
  1. Discover "Near You" home feed        -> xcrun simctl io booted screenshot ../../docs/ios/images/01-home.png
  2. Search (GPS chip "City, ST" + filters + 100-mi slider) -> ...02-search.png
  3. Open-mat detail — tap "I'm going", show the attendee list -> ...03-detail.png
  4. Profile — belt + IBJJF weight class   -> ...04-profile.png
  5. Owner: Profile/Settings → "Switch to Gym Owner" → a session's Attendance (Expected RSVPs + check-ins) -> ...05-owner.png

VERIFY & COMMIT
  sips -g pixelWidth -g pixelHeight ../../docs/ios/images/*.png   # expect 1242 x 2688
  cd ../.. && git add docs/ios/images && git commit -m "docs(ios): real App Store screenshots (6.5in)"
  (Optional) also capture 6.9" on "iPhone 16 Pro Max" (1290×2796) and iPad 13" if you'll submit those slots.

REFERENCE DOCS ALREADY IN THE REPO
  - docs/ios-build.md — Mac build/run runbook
  - docs/app-store-listing.md — all App Store metadata + the 5 screens & captions
  - docs/apple-app-registration.md — Apple Developer / App Store Connect / Auth0 registration checklist

CAVEATS
  - The app requires login; DEV_BYPASS (option A) is the quickest route to populated screens.
  - "6.5-inch" ≠ "6.7/6.9-inch": iPhone 11 Pro Max / 14 Plus = 1242×2688; iPhone 15/16 Plus & Pro Max are larger. Pick the device that matches the slot you're filling.
  - Screens should use the Glass theme for a consistent store look.
```

---

*Generated on the Windows machine after the iOS-enablement + features work (PR #5). The Windows host has an Android emulator and a running local API on :3100, but cannot run the iOS Simulator — hence this Mac handoff.*
