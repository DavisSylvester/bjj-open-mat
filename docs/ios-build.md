# iOS Build & Run (macOS only)

The repo is developed on Windows, which cannot compile iOS. These steps run on a Mac with Xcode + CocoaPods installed.

## One-time setup

1. `cd apps/mobile`
2. `flutter pub get`
3. `cd ios && pod install && cd ..`
4. Open `ios/Runner.xcworkspace` in Xcode → select the **Runner** target → **Signing & Capabilities** → set your Apple **Team** (bundle id `com.davissylvester.bjjopenmat`).

## Auth0 (already configured — verify)

The Native Auth0 app must include these iOS URLs (Allowed Callback + Logout):

```
com.davissylvester.bjjopenmat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjopenmat/callback
```

## Run on simulator

```bash
open -a Simulator
cd apps/mobile
flutter run -d "iPhone 15" --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
```

## Release build

```bash
bun run mobile:ios
```

## Verify

- App launches past the splash screen.
- Login opens the Auth0 sheet and returns to the app (no "callback URL not in allowlist" error).
- The Discover/Search screens prompt for location and load nearby open mats.

---

## Ship to TestFlight (CI — no Mac required)

The `ios` job in `.github/workflows/mobile-release.yml` builds a signed IPA on a
`macos` runner and uploads it to TestFlight. Trigger a build with:

```bash
# manual
gh workflow run mobile-release.yml -f build_name=1.0.0
# or push a tag
git tag v1.0.0 && git push origin v1.0.0
```

Requires these repo secrets (all producible from Windows — see the ASC signing
notes): `IOS_TEAM_ID`, `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`,
`IOS_PROVISIONING_PROFILE_BASE64`, `ASC_API_KEY_P8_BASE64`, `ASC_KEY_ID`,
`ASC_ISSUER_ID`.

`altool` reporting `UPLOAD SUCCEEDED` only means *delivered*. Apple then
processes the build for a few–~30 min. Confirm it is really live by checking the
build reaches `processingState = VALID` (App Store Connect → TestFlight → Builds,
or the ASC API `/v1/builds?filter[app]=<appId>&sort=-uploadedDate`).

## Distribute the build to testers

App Store Connect → **TestFlight** tab → **Builds → iOS**. A freshly processed
build shows **Waiting for Review** (that's Beta App Review — it gates *external*
testing only) and has no testers until you add a group.

### Internal testing — fastest, no Apple review
1. Click **➕** next to **INTERNAL TESTING** and create a group.
2. Add testers (must be members of your App Store Connect team — add them under
   **Users and Access** first if needed).
3. Assign the build to the group.
4. Tester installs the **TestFlight** app on their iPhone, signs in with the same
   Apple ID, and the build appears. Updates are instant; up to 100 testers.

### External testing — for people outside your team
Create an **External** group, add tester emails, and submit the build for **Beta
App Review** (the "Waiting for Review" step; usually < 1 day). Not needed for
internal testers.

### Export compliance
If a build shows **Missing Compliance**, click **Manage** and answer the
encryption question (this app uses only standard/exempt encryption). A build
cannot be installed until compliance is resolved.
