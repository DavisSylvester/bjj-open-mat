# Resume Notes — iOS App Store Screenshots (Misleading-Claims parity)

**App:** BJJ Open Mat (`com.davissylvester.bjjopenmat`)
**Goal:** Replace the iOS App Store screenshots with the same 3 honest,
current-UI captures already live on Google Play, so Apple doesn't flag the same
"phantom Schedule tab / misleading" issue. iOS listing is **live / in review**.

---

## ✅ STATUS (2026-07-14): screenshots CAPTURED — only the upload remains

The 3 iOS screenshots are done, at Apple's 6.9" size **1320 × 2868**, saved on the
capture Mac at `~/Desktop/bjj-ios-screenshots/`:
- `1-find-75495.png` — Find a Mat, ZIP 75495 → RM Elite result (1 Session, Sun 2:00 PM, Free)
- `2-rm-elite-detail.png` — RM Elite detail (Directions / I'm going / About / Check In)
- `3-profile.png` — Profile "BJJ Practitioner" (profile fix verified — no raw Auth0 id)

**Remaining human step:** upload them to App Store Connect (needs Apple ID + 2FA).
See "Finish-up prompt (another machine)" at the bottom.

> Minor note: `1-find-75495.png` has a faint text caret after "75495" in the ZIP
> field — barely visible, not a problem. Re-capture unfocused only if you want it
> pixel-clean (see capture steps below).

> **Why this is parked:** capturing requires a signed-in *practitioner* session.
> The app router redirects every screen to `/login` when unauthenticated
> (`apps/mobile/lib/app/router.dart:50-51`). Login is Auth0 (Google/Apple/email)
> — must be done interactively on the **local** Simulator. Claude cannot enter
> credentials, and the dev bypass logs in as the demo *owner* (wrong screens).
> So this only proceeds from the machine with the keystore/Auth0 env, logged in.

---

## The 3 screenshots to capture (match the Play set)

1. **Find a Mat** — ZIP search field with **75495** entered, showing the
   **RM Elite Brazilian Jiu-Jitsu** result.
2. **RM Elite detail** — the gym/open-mat detail screen (directions, RSVP, check-in).
3. **Profile** — the profile screen (shows "BJJ Practitioner", no raw Auth0 id).

Only real prod data exists now: prod returns exactly **one** gym, RM Elite
(Van Alstyne, TX, ZIP 75495). Verify: `curl https://api.bjj-open-mat.dsylvester.io/api/v1/open-mats`.

## Apple size requirement

- **6.9" display** (iPhone 16/17 Pro Max) = **1320 × 2868** portrait. A single
  6.9" set satisfies App Store Connect. `xcrun simctl io booted screenshot`
  captures the pure device framebuffer at exactly this size — no cropping needed.
- Debug banner is already disabled (`apps/mobile/lib/main.dart:32`
  `debugShowCheckedModeBanner: false`), so debug-mode captures are clean.

---

## Step-by-step (from the local Mac)

### 1. Boot the simulator + run the app
```bash
# iPhone 17 Pro Max (6.9"). UDID on this machine was:
#   0B391221-658F-4D57-B1B8-02CA61E7D293   (re-check with: xcrun simctl list devices available | grep "Pro Max")
xcrun simctl boot "iPhone 17 Pro Max"; open -a Simulator

cd apps/mobile
# NOTE: --release is NOT supported on the iOS simulator; use --debug.
flutter run --debug -d "iPhone 17 Pro Max" \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io
```
`.env` (gitignored) holds AUTH0_DOMAIN / AUTH0_CLIENT_ID / AUTH0_AUDIENCE.

### 2. Log in (human — Claude cannot)
On the Simulator, tap **Continue with Google** (or the provider your account
uses) and finish Auth0 until the practitioner **Discover** screen shows.

### 3. Navigate + capture
Either tap through manually, or let Claude drive with the calibrated helper
`/tmp/simtap.sh` (maps device px → screen px via the Simulator window bounds,
using `cliclick`; recompute bounds if the window moved). Capture each screen:
```bash
xcrun simctl io booted screenshot ~/Desktop/bjj-ios-screenshots/1-find-75495.png
xcrun simctl io booted screenshot ~/Desktop/bjj-ios-screenshots/2-rm-elite-detail.png
xcrun simctl io booted screenshot ~/Desktop/bjj-ios-screenshots/3-profile.png
```
Capture sequence: Find/Search tab → tap ZIP field → type `75495` → submit →
(shot 1) → tap RM Elite → (shot 2) → Profile tab → (shot 3).

### 4. Upload to App Store Connect (human)
App Store Connect → BJJ Open Mat → the in-review/editable version →
**App Store** tab → Media / iPhone 6.9" Display → replace screenshots with the
3 new files → Save. If the version is already "Waiting for Review", screenshots
are still editable without a new binary. Submit/confirm is the human's click.

---

## The tap helper (`/tmp/simtap.sh`)

Scratch script (not committed). Recreate if gone: it reads the Simulator window
position/size via AppleScript, fits the 1320×2868 device rect inside the window
content area (title bar ≈ 28px), and converts device coords → screen coords for
`cliclick`. Commands: `simtap.sh tap <dx> <dy>`, `simtap.sh type <text>`,
`simtap.sh shot <file>`. Requires `cliclick` (`brew install cliclick`; already
present at `/opt/homebrew/bin/cliclick`).

## Gotchas

- `--release` on the iOS simulator fails with "Release mode is not supported by
  iPhone 17 Pro Max." Use `--debug`.
- The dev bypass (`--dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<secret>`)
  authenticates as **Demo Owner** (`gym_owner`) → owner dashboard, NOT the
  practitioner discover/profile flow. Do not use it for these screenshots.
- App Store Connect requires Apple ID + 2FA; the browser session was NOT logged
  in during the parked session. Human must authenticate.

---

## Finish-up prompt (another machine)

Copy the 3 files from `~/Desktop/bjj-ios-screenshots/` to the machine you'll use
(or download them from the chat where they were delivered), then paste this into
a Claude Code session there:

> I need to upload 3 new iPhone screenshots to App Store Connect for **BJJ Open Mat**
> (`com.davissylvester.bjjopenmat`) to fix a Misleading-Claims concern. The 3 files
> are at `~/Desktop/bjj-ios-screenshots/` (1320×2868, iPhone 6.9"): `1-find-75495.png`,
> `2-rm-elite-detail.png`, `3-profile.png` — in that display order.
>
> I'm logged into App Store Connect (Apple ID + 2FA — I'll handle any auth prompts).
> Open appstoreconnect.apple.com → BJJ Open Mat → the editable/in-review version →
> **App Store** tab → **Previews and Screenshots** → **iPhone 6.9" Display**. Walk me
> through replacing the existing screenshots with these three in order and Saving.
> If the version is "Waiting for Review," confirm screenshots are still editable
> without a new binary (they are — it's a metadata change). Do NOT click Submit/
> Confirm for me — leave the final irreversible submit to me. Also verify the same
> set covers any other required display sizes, and tell me if a smaller size (6.5")
> is still required for this app.

**Context if asked:** this mirrors the Google Play set already live (screenshots
show real prod data — RM Elite Brazilian Jiu-Jitsu, Van Alstyne TX 75495 — no
phantom "Schedule" tab). Play side is fully published; API deploy is green.
