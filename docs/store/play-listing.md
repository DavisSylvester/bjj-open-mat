# Google Play — Store Listing & Form Answers

Everything you paste into Play Console. Package: `com.davissylvester.bjjopenmat`.

## Store listing (Main store listing → English (US))

**App name** (≤ 30 chars)
```
BJJ Open Mat
```

**Short description** (≤ 80 chars)
```
Find and check in to Brazilian Jiu-Jitsu open mats near you.
```

**Full description** (≤ 4000 chars)
```
BJJ Open Mat helps you find your next roll. Discover Brazilian Jiu-Jitsu
open-mat sessions near you, see who's going, and check in with a tap.

WHAT YOU CAN DO
• Find open mats nearby — browse sessions on a map or list, sorted by distance.
• See the details — schedule, gym, and who has checked in.
• Check in — let the community know you'll be on the mat.
• Build your profile — belt rank, home gym, and stats. Sign in securely with
  your existing account.

Whether you're traveling, new to the area, or just looking for extra mat time,
BJJ Open Mat makes it easy to find a place to train.

Oss.
```

**App category:** Health & Fitness
**Tags:** fitness, martial arts, community
**Contact email:** (your public support email — see note below)
**Privacy policy URL:** (hosted URL of docs/store/privacy-policy.html — see RELEASE-GUIDE.md)

---

## Graphic assets

| Asset | Requirement | Status |
|-------|-------------|--------|
| App icon | 512×512 PNG, 32-bit | `apps/mobile/tool/branding/app-icon-512.png` (current brand kit) |
| Feature graphic | 1024×500 PNG/JPG | ⬜ Not yet rendered — build from the brand kit in `apps/mobile/tool/branding/` |
| Phone screenshots | 2–8, 16:9 or 9:16, each 320–3840 px | `docs/ios/images/*.png` (real app screens) |

> Screenshots: the existing captures in `docs/ios/images/` are real app screens
> and meet Play's size rules. They show an iPhone status bar; that is allowed but
> you may prefer Android captures later. Use at least: Home, Search, Detail, Profile.

---

## Data Safety form (App content → Data safety)

Answer "Yes, my app collects or shares user data." Then declare:

| Data type | Collected | Shared | Purpose | Optional? |
|-----------|-----------|--------|---------|-----------|
| Name | Yes | No | App functionality, Account management | Required |
| Email address | Yes | No | App functionality, Account management | Required |
| User IDs | Yes | No | App functionality, Account management | Required |
| Date of birth | Yes | No | App functionality (age on profile) | Optional |
| Precise location | Yes | No | App functionality (find nearby mats) | Optional |
| Approximate location | Yes | No | App functionality (find nearby mats) | Optional |
| Photos | Yes | No | App functionality (gym images, admins) | Optional |
| Other info (belt rank, home gym) | Yes | No | App functionality | Optional |

Security practices to check:
- **Data is encrypted in transit:** Yes (HTTPS).
- **Users can request data deletion:** Yes (email + in-app where available).
- **Committed to Play Families Policy:** No (not a kids' app).

> Note: location is processed by Google Maps to render maps. Google's own SDK
> data handling is disclosed by Google; you declare your app's collection above.

---

## Content rating questionnaire (App content → Content rating)

- Category: **Utility, Productivity, Communication, or Other** (Reference/Utility).
- Violence, sexual content, profanity, controlled substances, gambling: **No** to all.
- User-generated content / social features: check-ins and profiles are limited
  social features — answer **Yes** to "users can interact" if asked, and note
  there is no open messaging. Expected rating: **Everyone / PEGI 3**.

## Target audience & content (App content → Target audience)

- Target age group: **18 and over** (or 13+). Not designed for children.
- If you select any under-13 group, extra Families requirements apply — avoid
  unless intended.

## Ads
- **This app contains ads: No.**

## Government apps / Financial / Health
- None apply.
