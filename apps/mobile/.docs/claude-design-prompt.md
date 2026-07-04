# Claude Design Prompt — BJJ Open Mat App

Design a mobile app called "Open Mat" — a Brazilian Jiu-Jitsu open mat finder
and gym management platform. This is a Flutter app targeting martial artists who
want to find drop-in training sessions, and gym owners who want to post and manage
those sessions.

---

## Brand & Aesthetic

Dark theme, premium combat sports feel. Think Duolingo's polish meets a serious
martial arts brand — bold, high-contrast, clean. No clutter. Every screen should
feel purposeful.

Primary palette:
- Background: Deep navy/charcoal (#1A1A2E or similar deep dark)
- Primary action / brand accent: Vibrant crimson/red (#E94560)
- Success / positive: Teal (#16C79A)
- Gi session badge: Electric blue (#2196F3)
- No-Gi session badge: Warm amber (#FF9800)
- Gi + No-Gi session badge: Purple (#9C27B0)

Typography: Bold, slightly condensed display font for headings (think something
athletic like Barlow Condensed or similar). Clean sans-serif for body text.

UI library: Material Design 3 with heavy customization — rounded cards,
prominent FABs, bottom navigation bar.

---

## User Types

1. **Practitioner** — finds and attends open mat sessions
2. **Gym Owner** — registers their gym and posts open mat schedules

---

## Screens to Design

### 1. Home / Discovery Screen
The main screen practitioners land on. Split view:
- Top half: Google Map showing nearby open mat pins, color-coded by gi type
  (blue = Gi, amber = No-Gi, purple = Both)
- Bottom half: Horizontal-swipeable cards showing today's and upcoming sessions
- Each card shows: gym name, time, gi-type badge, experience level badge,
  distance, mat fee (or "Free")
- Floating search bar at the top of the map
- Bottom nav bar: Home, Search, My Schedule, Profile

### 2. Search & Filter Screen
Full-screen search with:
- Location input (type city/zip OR tap GPS button to use current location)
- Filter chips in a horizontal row: "Gi", "No-Gi", "Both", "Free", "All Levels",
  "Beginner-Friendly"
- Date range picker
- Max distance slider
- Results appear as cards below (same card style as home)
- Map toggle button to switch to map view

### 3. Open Mat Detail Screen
Session detail with:
- Hero area at top: gym name large, session date/time, gi-type colored pill badge
- Experience level indicator (colored badge: All Levels / Beginner / Intermediate /
  Advanced)
- Mat fee row (icon + "Free" or "$10")
- Gym address with "Get Directions" button
- "Check In" primary CTA button (large, full-width, crimson)
- Ratings section: 4 category star rows — Gym Quality, Experience Level Match,
  Cleanliness, Friendliness — with aggregate stars and review count
- Recent reviews list: avatar, star rating chips, comment, date
- Bottom sheet for posting your own review (appears after check-in)

### 4. Write a Review Screen / Bottom Sheet
After attending a session, user rates:
- 4 independent star-rating rows:
  - Gym Quality ⭐⭐⭐⭐⭐
  - Experience Level Match ⭐⭐⭐⭐⭐
  - Cleanliness ⭐⭐⭐⭐⭐
  - Friendliness ⭐⭐⭐⭐⭐
- Multi-line text field: "Share your experience (optional)"
- Submit button

Design this as both a modal bottom sheet AND a full screen variant.

### 5. Gym Detail Screen
Gym profile page:
- Collapsing hero banner (placeholder: gym logo or building icon on colored
  background, shows gym name in FlexibleSpaceBar)
- Favorite heart button in app bar
- Address row with map pin icon + "Directions" / "Waze" buttons side by side
- Amenities chips: parking, showers, wifi, changing rooms, pro shop, water
- "Upcoming Open Mats" section — list of upcoming sessions this week with
  gi-type badges and times
- Aggregate ratings display: 4 category ratings shown as compact star rows with
  number

### 6. Gym Registration Wizard (3 Steps)
Step indicator at top (1 of 3, 2 of 3, 3 of 3).

Step 1 — Basic Info:
- Gym Name (text field)
- Address autocomplete field (Google Places style — shows suggestions as you type,
  selecting one fills in city/state/zip/lat/lng automatically)
- Confirmation chip/card showing the resolved address once selected

Step 2 — Contact & Details:
- Phone number field
- Website URL field
- Description (multiline)

Step 3 — Amenities:
- Grid of toggleable amenity tiles (icon + label, toggles selected/unselected
  state): Parking, Showers, WiFi, Changing Rooms, Pro Shop, Water
- "Register Gym" submit button

Use a progress indicator at the top of each step.

### 7. Create Open Mat Session Form
For gym owners to post a session:
- Gym selector (if owner has multiple gyms)
- Date picker
- Start time / End time pickers
- Gi Type selector — three large segmented buttons or cards:
  - [Gi] (blue, gi icon or similar)
  - [No-Gi] (amber, rash guard icon or similar)
  - [Both] (purple, split icon)
- Experience Level selector:
  - [All Levels] [Beginner] [Intermediate] [Advanced]
  (pill-style radio chips)
- Mat Fee toggle: "Free" switch, or if off: number input "$___"
- Notes/description field
- 2-per-day limit validation: show a warning banner if the selected date already
  has 2 sessions posted
- "Post Session" primary button

### 8. Profile Screen
- Avatar circle + name + belt rank (colored stripe badge — white, blue, purple,
  brown, black belt)
- "My Sessions" — upcoming sessions user has checked into
- "Favorite Gyms" — quick list
- Settings row (theme toggle, notifications, account)

---

## Component / UI Kit Requests

Please also design these reusable components:

1. **Session Card** — horizontal card used in Home and Search: gym name, time,
   gi-type colored pill, distance chip, mat fee chip, experience badge
2. **Gi Type Badge** — small pill with color + label (Gi=blue, No-Gi=amber,
   Both=purple)
3. **Experience Badge** — small pill: All Levels=teal, Beginner=green,
   Intermediate=orange, Advanced=red
4. **Category Star Row** — label on left, 5-star rating on right (for review
   input and display)
5. **Belt Rank Badge** — small pill showing belt color (white/blue/purple/brown/black)
6. **Empty State** — centered icon + title + subtitle (e.g. for no sessions found,
   no notifications)
7. **Loading Shimmer Card** — placeholder card with shimmer animation

---

## Tone

Athletic, focused, welcoming to all skill levels. Not intimidating. The visual
language should say "this is serious about BJJ but respectful to beginners."
Clean and modern, not grungy or aggressive.

---

Please design all 8 screens plus the component kit. Show both light and dark
variants for the component kit. All other screens should be dark theme only.
