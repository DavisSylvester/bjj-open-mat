# App Store Listing — BJJ Open Mat (metadata + screenshots)

Copy-paste values for App Store Connect. Fields marked **`<FILL>`** need your input.

---

## Text fields

### Version
```
1.0
```

### Promotional Text (max 170 — updatable without a new build)
```
Find BJJ open mats near you, see who's rolling, and tap "I'm going." Search by GPS, city, or ZIP within 100 miles.
```

### Description (max 4,000)
```
BJJ Open Mat is the fastest way to find a place to roll — wherever you are.

Open the app and it instantly shows open mats near you using your location. Filter by gi, no-gi, skill level, day, and distance (up to 100 miles), or search any city or ZIP.

FIND A MAT
• See open mats near you the moment you open the app
• Search by GPS, city, or ZIP — your location shows as a tappable "City, ST" chip
• Filter by Gi / No-Gi, free sessions, skill level, and when you want to train
• View session details: time, day, fee, gym, and directions

SEE WHO'S GOING
• Tap "I'm going" to RSVP to a specific session
• See how many people are coming and who they are
• Check in when you arrive and log your training

YOUR PROFILE
• Track your belt and stripes
• Set your IBJJF weight class (by gender and gi/no-gi)
• Save your home city and gym

FOR GYM OWNERS
• Post open mat sessions and keep them up to date
• See expected attendance from RSVPs alongside real check-ins
• Switch between practitioner and gym-owner views any time

Community-driven: anyone can submit an open mat, and gym owners verify their sessions.

Grab your gi (or don't) and go find a roll.
```

### Keywords (max 100 chars total, comma-separated, no spaces after commas)
```
bjj,jiu-jitsu,open mat,grappling,gi,no-gi,rolling,gym,mat finder,submission,training,martial arts
```
> That string is 99 chars. Trim a term if ASC rejects it.

### Support URL
```
https://bjj-open-mat.dsylvester.io/support
```
> **`<FILL>`** — must resolve. If you don't have a support page, point to a contact page or a GitHub issues URL.

### Marketing URL (optional)
```
https://bjj-open-mat.dsylvester.io
```

### Copyright
```
2026 Davis Sylvester
```

---

## App Review Information

### Sign-In required: **Yes** (the app requires Auth0 login)
Create a dedicated review test account in Auth0 and enter it:
```
User name: <FILL — e.g. appreview@bjj-open-mat.test>
Password:  <FILL>
```
> Do NOT use the `DEV_BYPASS` token — the production build uses real Auth0. Make a normal test user the reviewer can log in with. Ensure it has a role/profile so the app isn't stuck on onboarding.

### Contact Information
```
First name: Davis
Last name:  Sylvester
Phone:      <FILL>
Email:      dsylvesteriii@gmail.com
```

### Notes (max 4,000)
```
BJJ Open Mat helps Brazilian Jiu-Jitsu practitioners find nearby "open mat" training sessions.

Getting started:
1. Log in with the provided test account (or Sign in with Apple / Google / email).
2. Allow location when prompted — the home and search screens use it to show open mats near you. You can also search by city or ZIP.
3. Open any session to see details and tap "I'm going" to RSVP; "Check In" logs attendance.

Location is used only to find and sort nearby open mats (When In Use). No location tracking or advertising.

To see the gym-owner experience: Profile/Settings → "Switch to Gym Owner".
```

### Attachment (optional)
`<FILL — optional demo video or screenshots zip>`

---

## Export Compliance
`ITSAppUsesNonExemptEncryption = false` is set in `Info.plist` (standard HTTPS/TLS only), so **no export documentation is required** and no per-upload prompt appears.

## App Store Version Release
Recommended for a first release: **Manually release this version** (so you control the go-live moment after approval).

---

## Screenshots & Previews

Apple uses the largest-size screenshots for all smaller sizes, so you only strictly need the biggest iPhone size. **Only the first 3 screenshots** appear on the install sheet — order them by impact.

### Required / accepted sizes
| Device class | Portrait px | Notes |
|---|---|---|
| iPhone 6.5" (shown in ASC) | **1242 × 2688** | Also accepts 1284 × 2778 (6.5"/6.7") |
| iPhone 6.9" (newest) | 1290 × 2796 | ASC may require this too for new submissions |
| iPad 13" (only if iPad supported) | 2064 × 2752 | The app allows iPad orientations; provide if you ship iPad |
| Apple Watch | — | Not applicable (no watchOS target) |

App previews (video) are optional — skip for v1.

### Recommended screenshot order (capture these screens)
1. **Home / "Near You" feed** — the live list of nearby open mats (Glass theme). *Caption: "Find open mats near you."*
2. **Search** — GPS chip showing City, ST + filters + 100-mi slider. *Caption: "Search by GPS, city, or ZIP within 100 miles."*
3. **Open-mat detail** — the "I'm going" toggle + attendee list. *Caption: "See who's going before you show up."*
4. **Profile** — belt + IBJJF weight class. *Caption: "Track your belt & weight class."*
5. **Owner attendance** — Expected (RSVP) + check-ins. *Caption: "Owners: see expected attendance."*

### Generate REAL screenshots (Mac, exact sizes)
The 6.5" reference device is the **iPhone 11 Pro Max / iPhone 14 Plus** simulator (1242 × 2688).
```bash
cd apps/mobile
# Boot the 6.5" simulator
xcrun simctl boot "iPhone 14 Plus" 2>/dev/null || true
open -a Simulator
flutter run -d "iPhone 14 Plus" \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
# In another terminal, for each screen you've navigated to:
xcrun simctl io booted screenshot apps/mobile/store/screenshots/ios-6.5/01-home.png
xcrun simctl io booted screenshot apps/mobile/store/screenshots/ios-6.5/02-search.png
xcrun simctl io booted screenshot apps/mobile/store/screenshots/ios-6.5/03-detail.png
xcrun simctl io booted screenshot apps/mobile/store/screenshots/ios-6.5/04-profile.png
xcrun simctl io booted screenshot apps/mobile/store/screenshots/ios-6.5/05-owner.png
```
> `simctl ... screenshot` captures at the simulator's native resolution (1242 × 2688 for the 6.5" devices) — exactly what ASC wants. Use the **Glass** theme (the default) for a consistent look.

### Placeholder screenshots (staging only)
`apps/mobile/store/screenshots/ios-6.5/placeholder-*.png` are branded 1242 × 2688 frames generated by `apps/mobile/store/generate_placeholder_screenshots.ps1`. Upload them to lay out the listing now, then replace with the real captures above before submitting for review (App Review can reject obvious placeholder art).
