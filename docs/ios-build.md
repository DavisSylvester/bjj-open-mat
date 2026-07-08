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
