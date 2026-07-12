# Marketing — Executive Summary

> A 2-minute overview of the complete BJJ Open Mat go-to-market kit in `docs/marketing/`.
> Full index: [`README.md`](./README.md). Last updated: 2026-07-11.

---

## The situation
**BJJ Open Mat** is a free, community-driven app to find open mats anywhere, see who's going, and
tap "I'm going." It's in **closed beta** (iOS TestFlight / Android Play internal) with **no public
download and no social presence yet**. Marketing focus: **US-wide**, **small paid boost**,
content published from **accounts we own** (a content engine, not bots).

## The strategy in one paragraph
Because the app isn't downloadable yet, the 90-day goal is **not installs — it's a warm audience**.
Build the brand from zero, earn trust in BJJ communities, and convert attention into a **"Founding
Mats" list**: beta testers (demand) + gyms who claim their listing (supply). That list becomes
launch-day fuel — a coordinated install/rating spike is what moves the App Store / Play rankings.
We recruit supply *and* demand in parallel, because a marketplace app dies on an empty map.

## The funnel
```
Content (IG/TikTok/YT) + community (Reddit/FB, manual)
        ↓  attention
Waitlist landing page  →  "Founding Mats" list (testers) + "Founding Gyms" (supply)
        ↓  nurture (email sequence)
Beta testers → feedback → launch-day velocity stack (email + Product Hunt + press + creators + paid)
        ↓
Public launch: Day-1 installs + ratings → store-ranking lift
```

## What was produced (13 docs + graphics)

**Strategy & ops**
- `marketing-plan.md` — 90-day phased GTM: segments, platform priority, safe-automation architecture, budget split, launch velocity stack, KPIs, ToS guardrails (research-cited).
- `tooling.md` — accounts, scheduler (Metricool/Buffer), optional Meta/TikTok API path, waitlist plumbing.
- `README.md` — kit index + operating principle + weekly loop.

**Execution**
- `initial-launch-kit.md` — Phase-0 checklist + exact Week 1–2 posts, ready to ship.
- `content-calendar.md` — 12-week, ~4-posts/week calendar.
- `content-bank.md` — ~35 ready-to-post pieces (captions + hashtags + shot briefs) + reply templates.
- `founder-script-pack.md` — 5 talking-head scripts, hook bank, b-roll shot list.

**Conversion**
- `landing-page-copy.md` — full waitlist page copy + meta/OG.
- `email-sequence.md` — welcome → beta → launch flow (E1–E7 + owner G1).
- `elevator-pitch.md` — 5 pitch lengths (one-liner → investor).

**Launch amplification**
- `product-hunt-launch.md` — tagline, description, maker comments, gallery, PT launch-day timeline.
- `press-kit.md` — media/podcast one-pager, boilerplate, pitch email templates.
- `creator-outreach.md` — creator tiers, deal structures, DM/email templates, brief, tracking.

**Brand graphics** (`assets/`, rendered + editable HTML, brand font embedded)
- `fb-post-openmat.png` (1080×1080 practitioner) · `fb-post-gym.png` (1080×1080 gym owner) · `fb-banner.png` (1200×630 landscape)
- `claude-design-prompt.md` — brand-loaded prompt to generate richer art in Claude Design.

## The operating principle
**"Automation" = content engine + scheduler publishing from accounts you own.** Instagram / TikTok
/ YouTube / FB-Page = scheduled. **Reddit + FB Groups = manual, human, rules-checked.** No bots, no
fake accounts, no scripted group spam — those get banned and burn trust in a tight community.

## Budget (first 90 days, "small paid boost")
Organic is the engine; paid is the amplifier. ~40% boost proven organic posts · 35% geo-targeted
waitlist/install ads (TikTok + Meta) · 15% Apple Search Ads at launch · 10% micro-creator seeding.
Don't scale paid until a channel beats 2026 CPI benchmarks **and** retains.

## KPIs
North-star (pre-launch): weekly **waitlist signups** + **gyms claimed**. Watch **saves/shares**
over likes (intent). Signal to start paid: **5–15 organic signups/day**. Weekly loop: clone
winners, cut losers, adjust the calendar.

## What only a human can do
Reserve handles (`@bjjopenmat`, verify availability) · build the waitlist page · **film the clips** ·
hit publish / approve the queue · all community, creator, and press conversations. Treat cited 2026
CPI/reach figures as benchmarks, not guarantees.

## Immediate next steps
1. Merge **PR #16**.
2. Reserve handles + stand up the waitlist page (`landing-page-copy.md`).
3. Batch-film Week 1 clips (`founder-script-pack.md`), queue per `initial-launch-kit.md`.
4. Post the branded graphic to a few FB groups (manual, per-group rules) using the paired captions.
5. Load the email sequence into an ESP; recruit 200–500 diverse beta testers.

## Status
All assets committed on branch `feature/marketing-plan` → **PR #16** (docs-only, no app code changed).
