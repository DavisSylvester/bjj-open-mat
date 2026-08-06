# App Store Listing — BJJ Open Mat (metadata + screenshots)

Copy-paste values for App Store Connect. Fields marked **`<FILL>`** need your input.

> **This file mirrors what is actually live in App Store Connect.** Metadata is
> managed by hand in ASC (`deliver` runs with `skip_metadata: true`), so this doc
> is a record, not a source that gets pushed. When you edit the listing in ASC,
> edit this file in the same pass or it drifts — as it did between the 1.0
> release and 1.2.0, when the live description diverged from the text here.
>
> Live description last verified against the store on 2026-08-06 via
> `https://itunes.apple.com/lookup?bundleId=com.davissylvester.bjjopenmat`.

---

## Text fields

### Version
```
1.2.0
```

### What's New in This Version (max 4,000)
```
Gym owners and coaches can now manage who appears on their gym's member list.

• Hide a member from the public roster while keeping their access to the gym forum, messages, and classes
• Mark a member inactive when they've stopped training at the gym
• Hidden and inactive members stay visible to owners and coaches, clearly labeled, so no one gets lost track of

Also fixed: members who had hidden themselves from their gym's roster could lose access to that gym's forum. That's resolved.
```

> **Paste this into "What's New in This Version", not "Description".** On the ASC
> version page the field immediately above Keywords is *Description*; What's New
> and Promotional Text sit above it, so it is easy to fill the wrong box. Quick
> check: Description is ~766 chars and starts "BJJ Open Mat helps you find…";
> this What's New copy is 489 chars and starts "Gym owners and coaches can now…".
> The remaining-character counter tells them apart at a glance (3,234 vs 3,511).

### Promotional Text (max 170 — updatable without a new build)
```
Find BJJ open mats near you, see who's rolling, and tap "I'm going." Search by GPS, city, or ZIP within 100 miles.
```

### Description (max 4,000)

This is the text **currently live on the App Store**, with one bullet added for
the 1.2.0 roster feature (marked below). The longer draft that used to live here
was never published — it has been removed to stop the two diverging again.

```
BJJ Open Mat helps you find Brazilian Jiu-Jitsu open mats near you — anytime you want to roll.

Search by location, day, and gi or no-gi, see who's going, and check in when you arrive. Gym owners and members can post their open mats so the whole community can find them.

FEATURES
• Discover open mats near you with live GPS search
• Filter by day, distance, and gi / no-gi
• RSVP "I'm going" and see other attendees and their belt ranks
• Check in at the mat and keep a training log
• Submit and manage your gym's open-mat sessions
• Gym owners: manage your roster and control who appears publicly
• Leave and read reviews
• Sign in with Apple, Google, or email

Whether you're traveling or just looking for an extra session this week, BJJ Open Mat connects you with the mats and the community. See you on the mats!
```

> The new bullet is `Gym owners: manage your roster and control who appears publicly`.
> Everything else is verbatim from the live listing.

#### On the `precheck` "found: google" warning

`fastlane precheck` flags `description: (en-US) found: google` on every submit.
**It is a false positive — do not "fix" it reflexively.** The match is the
sign-in bullet:

```
• Sign in with Apple, Google, or email
```

Naming third-party sign-in providers is permitted; Apple's concern is listings
that steer users to other platforms or stores. Sign in with Apple is offered and
named first. Decisively: Apple approved this exact description for the 1.0
release on 2026-07-28. `precheck` is a keyword scanner with no notion of context,
and it reports the finding as non-blocking ("this won't prevent fastlane from
completing").

If you ever do want the warning silenced, this is the swap — at the cost of
telling users less:

```
• Sign in with Apple, email, or your existing social account
```

### Keywords (max 100 chars total, comma-separated, no spaces after commas)
```
bjj,jiu jitsu,open mat,grappling,no gi,gi,gym finder,rolling,brazilian,mma,bjj gym
```
> Live value, 82 chars — 18 to spare. An earlier draft here listed a different
> set (`jiu-jitsu`, `submission`, `training`, `martial arts`) that was never used.

### Support URL
```
https://davissylvester.github.io/bjj-open-mat-legal/support.html
```

### Marketing URL (optional)
```
https://davissylvester.github.io/bjj-open-mat-legal/
```
> Both URLs are served from the `bjj-open-mat-legal` GitHub Pages site, not from
> `bjj-open-mat.dsylvester.io` as this doc previously claimed. `dsylvester.io` is
> the API/app host; the legal + support pages live on Pages.

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

For 1.2.0 the submit workflow was run with `auto_release:true`, which publishes
as soon as Apple approves rather than waiting on a manual release.

## Submitting a new version — the step that is easy to miss

`deliver` runs with `skip_metadata: true`, so it **will not create the App Store
version record for you**. If no version is in *Prepare for Submission*, the
submit fails with:

```
[!] Cannot submit for review - could not find an editable version for 'IOS'
```

That is what happened on the first 1.2.0 attempt (run 31076192153). Before
running `ios-appstore-submit.yml`:

1. App Store Connect → the app → **+ Version or Platform** → enter the version.
2. Paste **What's New** (required for a new version).
3. Save, leaving it in *Prepare for Submission*.
4. Then dispatch the workflow and approve the `appstore-production` gate.

Also note the build's version string must match the version record — a build
made with `--build-name=1.2.0` can only be attached to a 1.2.0 record, and Apple
never allows reusing or going below an already-released version string.

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
