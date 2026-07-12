# Claude Design Prompt — BJJ Open Mat social graphics

> Paste the prompt below into Claude (with the Design / image-generation feature, or Claude.ai
> artifacts) to generate polished, on-brand social graphics. It's pre-loaded with the OpenMat brand
> so output stays consistent with the app and the HTML graphics in this folder. Attach
> `docs/branding/app-icon-1024.png` for the logo when the tool allows image input.

---

## Brand reference (paste as context)

```
BRAND: OpenMat (app name "BJJ Open Mat")
TAGLINE: Find a roll, anywhere
LOGO: "OpenMat" wordmark — "Open" in near-black (#14151A), "Mat" in indigo (#5B53F2).
      Mark = a horizontal belt-progression rosette: 5 rounded segments left→right in
      white/light-grey, blue (#2E7BFF), purple (#8B5CF6), brown (#8B5A2B), black (#1A1B22),
      with a small dark square "knot" centered on top (a stylized BJJ belt/medal).
FONT: Plus Jakarta Sans (weights 600/700/800). Tight negative letter-spacing on big headings.

COLORS:
  Indigo (primary)   #5B53F2   Indigo deep  #4038D6
  Gold (accent)      #FFB020
  Ink (headings)     #14151A   Body text    #3D4150   Muted #6B7280
  Backgrounds        #FFFFFF / #F5F6FA (light, airy "Liquid Glass" feel)
  Belt accents       gi-blue #2E7BFF · no-gi-orange #FF7A33 · purple #8B5CF6
STYLE: Clean, modern, light theme. Soft radial indigo/gold glows, faint map-grid texture,
  rounded cards with soft shadows, teardrop map-pin motifs. Confident but friendly — built by a
  grappler, for grapplers. NOT dark/edgy MMA-poster energy. NO stock photos of fighting.
  Emoji used sparingly (🥋 📍 👥 🏋️).
```

## The prompt

```
You are designing social media graphics for "BJJ Open Mat," a free mobile app that helps
Brazilian Jiu-Jitsu practitioners find open mats near them or in any city they travel to — see
who's going and RSVP with "I'm going." Use the BRAND REFERENCE above exactly (OpenMat wordmark +
belt-rosette mark, Plus Jakarta Sans, indigo #5B53F2 + gold #FFB020, light "liquid glass"
aesthetic with soft glows, faint map grid, rounded cards, map-pin motifs).

Produce a set of social graphics. For each, put the OpenMat wordmark + belt mark top-left, keep
generous whitespace, make the headline the dominant element, and include the URL
"bjj-open-mat.dsylvester.io".

1) PRACTITIONER — Instagram/Facebook square (1080×1080)
   Kicker pill: "For every grappler who travels"
   Headline: "Find a BJJ open mat anywhere." (highlight "anywhere" with a gold marker underline)
   Sub: "See open mats near you or in any city, see who's going, and tap 'I'm going.'"
   3 feature chips: 📍 Near you or any city · 🥋 Gi / No-Gi filters · 👥 See who's going
   CTA band (indigo): "Join the founding list" + gold "FREE · NOW IN BETA" tag + the URL.

2) GYM OWNER — square (1080×1080), gold-forward variant
   Kicker: "Gym owners & coaches"
   Headline: "Put your open mat on the map." (highlight "on the map")
   Sub: "Travelers and locals find your open mat, RSVP, and show up. You verify your own
   sessions — and it's free."
   Chips: 🏅 Founding Gym badge · 👀 Free exposure · 📅 See who's coming
   CTA: "Claim your gym" + "FREE · FIRST 100 GYMS" + the URL.

3) LANDSCAPE banner (1200×630) for link previews / FB Page — same practitioner message, laid out
   horizontally: text left, CTA button bottom-right, "FREE · NOW IN BETA" badge top-right.

Deliver crisp, export-ready art. Keep text minimal and legible on mobile. Offer 2 headline
variations per graphic. Maintain a consistent template across all three so they read as a set.
```

## Follow-up prompts you can chain
- "Now make an Instagram Stories / Reels cover version (1080×1920) of #1."
- "Give me 5 alternate headlines for the practitioner square, each ≤6 words."
- "Design a 'Founding Gym' badge graphic (gold, belt-rosette motif) for gyms to repost."
- "Create a carousel: slide 1 hook, slides 2–4 the three steps (find → see who's going → check in), slide 5 CTA."
- "Produce a matching set in a dark variant for TikTok."

## Notes
- These same specs are already built as editable HTML in this folder (`fb-post.html`,
  `fb-post-gym.html`, `fb-banner.html`) — Claude Design is for quickly exploring richer visual
  directions or when you want art beyond CSS (illustration, texture, photography-style scenes).
- Whatever it generates, keep the wordmark, colors, and font consistent with the app so the brand
  stays coherent across the store listing, the app, and social.
