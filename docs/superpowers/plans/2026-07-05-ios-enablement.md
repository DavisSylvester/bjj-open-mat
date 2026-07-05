# iOS Enablement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure the existing iOS Runner project so the Flutter app builds, authenticates (Auth0), and reads GPS on iOS.

**Architecture:** Pure platform configuration — no Dart logic changes. Edit `Info.plist` (location + Auth0 URL scheme), add a `Podfile` pinned to iOS 13, add a `mobile:ios` build script, register iOS callback URLs in Auth0, and document the Mac build steps. The developer runs the actual compile on a Mac (this repo lives on Windows, which cannot compile iOS).

**Tech Stack:** Flutter iOS (CocoaPods), `auth0_flutter`, `geolocator`, Auth0 Native application.

> **Verification note:** Steps 1–4 are editable/verifiable on Windows (file content checks + `flutter analyze`). The compile-and-run verification (Task 5) MUST be run on a Mac; commands are provided but cannot be executed from this repo's Windows host.

---

### Task 1: Add location permission + Auth0 URL scheme to Info.plist

**Files:**
- Modify: `apps/mobile/ios/Runner/Info.plist` (insert before the final `</dict>`)

- [ ] **Step 1: Add the two keys**

Insert the following block immediately before the closing `</dict>` at the end of `apps/mobile/ios/Runner/Info.plist`:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>BJJ Open Mat uses your location to find open mats near you.</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>None</string>
			<key>CFBundleURLName</key>
			<string>auth0</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 2: Verify the keys are present**

Run: `grep -c "NSLocationWhenInUseUsageDescription\|CFBundleURLSchemes" apps/mobile/ios/Runner/Info.plist`
Expected: `2`

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/ios/Runner/Info.plist
git commit -m "feat(ios): add location usage string and Auth0 URL scheme"
```

---

### Task 2: Add a Podfile pinned to iOS 13

**Files:**
- Create: `apps/mobile/ios/Podfile`

- [ ] **Step 1: Create the Podfile**

Create `apps/mobile/ios/Podfile` with the standard Flutter template pinned to iOS 13 (auth0_flutter + geolocator floor):

```ruby
platform :ios, '13.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

- [ ] **Step 2: Verify the platform pin**

Run: `grep -n "platform :ios, '13.0'" apps/mobile/ios/Podfile`
Expected: one match on line 1.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/ios/Podfile
git commit -m "feat(ios): add Podfile pinned to iOS 13"
```

---

### Task 3: Add a `mobile:ios` build script

**Files:**
- Modify: `package.json:26` (scripts block — add after the `mobile:apk` line)

- [ ] **Step 1: Add the script**

In `package.json`, add this entry to `scripts` immediately after the `"mobile:apk"` line (add a comma to the `mobile:apk` line):

```json
    "mobile:ios": "cd apps/mobile && flutter build ios --release --dart-define-from-file=.env --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com"
```

- [ ] **Step 2: Verify JSON is valid**

Run: `node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add package.json
git commit -m "chore(ios): add mobile:ios build script"
```

---

### Task 4: Register iOS callback URLs in Auth0 (manual, documented)

**Files:**
- None (Auth0 dashboard change) — captured in the runbook in Task 5.

- [ ] **Step 1: In the Auth0 dashboard, open the existing Native application** (the one used by the mobile app — see the `mobile-auth0-native-login` memory).

- [ ] **Step 2: Add to "Allowed Callback URLs"** (comma-separated with existing values):

```
com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
```

- [ ] **Step 3: Add the same URL to "Allowed Logout URLs".** Save changes.

- [ ] **Step 4:** No commit (dashboard-only). Proceed to Task 5 where this is recorded in the runbook.

---

### Task 5: Write the Mac build runbook

**Files:**
- Create: `docs/ios-build.md`

- [ ] **Step 1: Write the runbook**

Create `docs/ios-build.md`:

```markdown
# iOS Build & Run (macOS only)

The repo is developed on Windows, which cannot compile iOS. These steps run on a Mac with Xcode + CocoaPods installed.

## One-time setup

1. `cd apps/mobile`
2. `flutter pub get`
3. `cd ios && pod install && cd ..`
4. Open `ios/Runner.xcworkspace` in Xcode → select the **Runner** target → **Signing & Capabilities** → set your Apple **Team** (bundle id `com.davissylvester.bjjOpenMat`).

## Auth0 (already configured — verify)

The Native Auth0 app must include these iOS URLs (Allowed Callback + Logout):

```
com.davissylvester.bjjOpenMat://dev-vhvwupdn45hk7gct.us.auth0.com/ios/com.davissylvester.bjjOpenMat/callback
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
```

- [ ] **Step 2: Verify the file exists**

Run: `test -f docs/ios-build.md && echo ok`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add docs/ios-build.md
git commit -m "docs(ios): add macOS build and run runbook"
```

---

## Self-Review notes
- Spec section A fully covered: Info.plist (T1), Podfile (T2), build script (T3), Auth0 callbacks (T4), docs (T5).
- No Dart changes, so `flutter analyze` is unaffected; the real gate is the Mac build in the runbook, run by the developer.
