# Apple App Registration — BJJ Open Mat (iOS)

What to do after creating the app in the Apple Developer portal / App Store Connect, with every value that can be pre-filled from this repo. Items marked **`<FILL>`** can only come from your Apple account.

> Related: `docs/ios-build.md` (Mac build/run), memory `mobile-auth0-native-login`, `ios-enablement-followups`.

---

## 1. Known app values (from this repo — use these verbatim)

| Field | Value |
|---|---|
| App name (display) | `Bjj Open Mat` (store-facing suggestion: **BJJ Open Mat**) |
| Bundle ID / App ID | `com.davissylvester.bjjOpenMat` |
| Tests target bundle ID | `com.davissylvester.bjjOpenMat.RunnerTests` |
| Xcode project | `apps/mobile/ios/Runner.xcworkspace` (target **Runner**) |
| Minimum iOS | `13.0` |
| Marketing version | `0.1.0` (from `pubspec.yaml`) |
| Build number (first upload) | `1` |
| Code signing | `Automatic` (Xcode-managed) |
| Primary language | English (U.S.) |
| Auth0 domain | `dev-vhvwupdn45hk7gct.us.auth0.com` |
| API base URL | `https://api.bjj-open-mat.dsylvester.io` |
| Owned web domain (for Universal Links, optional) | `bjj-open-mat.dsylvester.io` |

## 2. Values only your Apple account can provide (`<FILL>`)

| Field | Where to find it | Placeholder |
|---|---|---|
| **Team ID** (10-char) | developer.apple.com → Membership | `<TEAM_ID>` |
| App Store Connect **Apple ID** (numeric app id) | auto-assigned when the app record is created | `<APP_APPLE_ID>` |
| **SKU** (your internal id, never shown to users) | you choose — suggestion: `bjj-open-mat` | `bjj-open-mat` |
| Sign in with Apple **Services ID** | Certificates → Identifiers → Services IDs | `<SIWA_SERVICES_ID>` |
| Sign in with Apple **Key ID** + `.p8` file | Certificates → Keys | `<SIWA_KEY_ID>` / `AuthKey_<SIWA_KEY_ID>.p8` |

---

## 3. Post-creation checklist

### 3.1 App ID capabilities (Certificates, IDs & Profiles → Identifiers)
Open the App ID `com.davissylvester.bjjOpenMat` and enable:

- [ ] **Sign in with Apple** — required. The app offers Google + Apple + email login (`auth_service.dart: loginWithApple → 'apple'`). App Review requires Sign in with Apple whenever other third-party logins are offered.
- [ ] **Associated Domains** — *optional*, only if you switch the Auth0 iOS callback from the custom URL scheme to Universal Links (see §5). Not needed for the current custom-scheme callback.
- [ ] **Push Notifications** — *skip*. No APNs/remote-push dependency in `pubspec.yaml` today; the notifications feature is in-app. Add later only if remote push is introduced.

### 3.2 Signing certificates & profiles
With `CODE_SIGN_STYLE = Automatic`, the easiest path is to let Xcode manage these:

- [ ] In Xcode → Runner target → **Signing & Capabilities** → check **Automatically manage signing** and select your Team (`<TEAM_ID>`).
- [ ] Xcode creates the **Apple Development** cert + a Development provisioning profile on first run to a device.
- [ ] For TestFlight/App Store: Xcode creates the **Apple Distribution** cert + App Store provisioning profile at archive time.
- [ ] (Manual/CI alternative) Create these yourself under Certificates & Profiles if not using automatic signing.

### 3.3 Set the Team in the project
`DEVELOPMENT_TEAM` is currently **empty** in `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`. Set it once via Xcode (preferred) or add to both Release/Debug build configs:

```
DEVELOPMENT_TEAM = <TEAM_ID>;
```

### 3.4 App Store Connect app record
When creating (or editing) the app record, use:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | BJJ Open Mat |
| Primary language | English (U.S.) |
| Bundle ID | `com.davissylvester.bjjOpenMat` |
| SKU | `bjj-open-mat` |
| User access | Full Access |

- [ ] App Privacy → declare **Location** data use (see §6).
- [ ] Provide app category, subtitle, description, keywords, screenshots, and a support/privacy-policy URL (`https://bjj-open-mat.dsylvester.io/...`).

### 3.5 Auth0 — Native app callback URLs (already documented in `docs/ios-build.md`)
In the Auth0 **Native** application, add to **Allowed Callback URLs** and **Allowed Logout URLs**:

```
com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
```

This matches the `CFBundleURLSchemes` entry (`$(PRODUCT_BUNDLE_IDENTIFIER)`) already in `Info.plist`.

### 3.6 Auth0 — Apple social connection (needed for `loginWithApple`)
Configure Auth0 → Authentication → Social → **Apple** with the Apple artifacts from §2:

| Auth0 field | Value |
|---|---|
| Client ID | `<SIWA_SERVICES_ID>` (or the app bundle id for native-only) |
| Apple Team ID | `<TEAM_ID>` |
| Client Secret Signing Key | contents of `AuthKey_<SIWA_KEY_ID>.p8` |
| Key ID | `<SIWA_KEY_ID>` |

Then authorize this connection for the app and (if using the API/audience) enable it — see memory `mobile-auth0-native-login`.

---

## 4. Generated starter values

### 4.1 Info.plist — App Store submission additions
Add to `apps/mobile/ios/Runner/Info.plist` (before submitting). The location usage string is already present from the iOS-enablement work.

```xml
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
```
> `false` is correct if the app only uses standard HTTPS/TLS (no custom/proprietary crypto). This avoids the export-compliance prompt on every upload.

Already present (do not duplicate):
```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>BJJ Open Mat uses your location to find open mats near you.</string>
```

### 4.2 Build & upload commands (Mac)
```bash
cd apps/mobile
flutter pub get
cd ios && pod install && cd ..
# Archive for the App Store:
flutter build ipa --release \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
# then upload build/ios/ipa/*.ipa via Xcode Organizer or:
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios --apiKey <ASC_API_KEY_ID> --apiIssuer <ASC_ISSUER_ID>
```

### 4.3 (Optional) Universal Links — `apple-app-site-association`
Only if you enable **Associated Domains** (§3.1) and add `applinks:bjj-open-mat.dsylvester.io` to the Runner entitlements. Host this at
`https://bjj-open-mat.dsylvester.io/.well-known/apple-app-site-association` (served as `application/json`, no redirect):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.com.davissylvester.bjjOpenMat",
        "paths": ["/ios/com.davissylvester.bjjOpenMat/callback", "*"]
      }
    ]
  }
}
```
> Current setup uses the custom URL scheme, so this file is **not required** yet. It's the more secure production option for the Auth0 callback.

---

## 5. App Privacy (App Store Connect → App Privacy)

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| **Precise Location** | Yes | No | No | App Functionality (find nearby open mats) |
| **Email address** | Yes | Yes | No | App Functionality / Account (Auth0 login) |
| **Name** | Yes | Yes | No | App Functionality (profile/display name) |
| Identifiers (user ID) | Yes | Yes | No | App Functionality |

Adjust to match actual data flows before publishing; a privacy-policy URL is required.

---

## 6. Quick "am I done?" checklist
- [ ] App ID has **Sign in with Apple** enabled
- [ ] Team ID set in Xcode signing (`<TEAM_ID>`)
- [ ] Auth0 Native app: iOS callback + logout URLs added
- [ ] Auth0 Apple connection configured (Services ID / Key / Team ID)
- [ ] App Store Connect record: name, SKU `bjj-open-mat`, bundle id, privacy
- [ ] `ITSAppUsesNonExemptEncryption` added to Info.plist
- [ ] Archive built on a Mac and uploaded (build number ≥ 1)
