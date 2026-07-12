# BJJ Open Mat — Go-To-Market & AI-Assisted Social Marketing Plan

> Owner: Davis Sylvester · Status: **Beta (TestFlight + Play internal)** · Horizon: **90-day pre-launch → launch**
> Last updated: 2026-07-11

---

## 0. TL;DR

The app is in **closed beta with no public download and no social presence**. Therefore the
90-day goal is **not installs** — it is to **build a brand from zero and convert attention
into a warm list**: beta testers (demand) and gyms who claim/add their open mats (supply).
That list is the fuel that makes launch day move the App Store / Play Store ranking
algorithms, which reward a spike of installs + ratings in the first 24–48 hours.

Everything here respects platform Terms of Service. **"Automation" = a content engine + a
scheduling calendar published from accounts you own** — not bot accounts, not mass
auto-DMing, not scripted group spam. Those get you banned and poison the brand in a
tight-knit community that notices immediately.

---

## 1. The product (what we're selling)

**BJJ Open Mat** — the fastest way to find a place to roll, wherever you are.

- Discover/search open mats by **GPS, city, or ZIP**, within up to 100 miles
- Filter by **Gi / No-Gi, free sessions, skill level, and day/time**
- **"I'm going"** RSVPs + arrival **check-ins** with a training log
- See **who's coming** — attendee cards with belt rank
- **Gym profiles** with logos; owners post/verify sessions and see expected vs. actual attendance
- **Community-driven**: anyone submits a mat; owners/admins verify
- Free, Auth0 login (email + Google/Apple), Glass-themed UI

**The one-sentence positioning:** *"Find a BJJ open mat near you — or in any city you're
traveling to — see who's rolling, and tap 'I'm going.'"*

---

## 2. Positioning & core messages

Two audiences, two promises. Every piece of content serves one of them.

| Audience | Core promise | Emotional hook |
|---|---|---|
| **Practitioners** (demand) | "Never miss a roll. Train anywhere you travel." | FOMO, wanderlust, mat-time addiction |
| **Gym owners/coaches** (supply) | "Free exposure. Fill your open mats. Own your listing." | Growth, more bodies on the mat, zero cost |

**Message pillars (say these over and over, different clothes each time):**
1. *Travel & train anywhere* — the killer use case ("in town for a wedding, found a mat in 20 seconds").
2. *Open mat is sacred* — celebrate the culture; we're built by grapplers, for grapplers.
3. *See who's going* — the social layer nobody else has.
4. *Gyms: claim your mat, free* — supply-side recruiting.

---

## 3. Target market & where they actually are

### Segments
1. **Hobbyist practitioners** (white→purple, the volume) — casual, social, love the culture.
2. **Traveling grapplers & competitors** — the highest-intent users; "train while traveling" is the wedge.
3. **Gym owners / head coaches** — supply side; needed for marketplace density.
4. **BJJ content lurkers** — follow BJJ pages, don't post; convert via entertaining + useful clips.

### Platform priority (effort order)

| Rank | Platform | Role | Automation? |
|---|---|---|---|
| 1 | **Instagram** (Reels + feed + Stories) | Primary brand home; Reels for reach, feed for identity | ✅ Scheduled from our account |
| 2 | **TikTok** | Reach engine; short, funny, trend-driven; health/fitness CPI ~65% lower than other platforms | ✅ Scheduled from our account |
| 3 | **YouTube Shorts** | Repurpose IG/TikTok verticals; long-tail search | ✅ Scheduled |
| 4 | **Reddit** (r/bjj ~140K+, r/jiujitsu) | Community trust, high-intent; strict self-promo rules | ⛔ **Manual, organic only** |
| 5 | **Facebook** (Groups + Page) | Older demo, gym owners live here; Worldwide BJJ Community, BJJ Fanatic Group, regional/city BJJ groups | ⛔ Groups manual; Page scheduled |

> **Why Reddit + FB Groups are manual only:** these communities ban self-promotion and detect
> scripted/bot behavior instantly. The *only* way to win there is a real human being genuinely
> useful (answer "where can I train in \<city\>?" threads, then mention the app when relevant).
> Automating them is both a ToS violation and reputational suicide in a small scene.

### Communities to seed manually (starter list — verify each group's rules before posting)
- **Reddit:** r/bjj, r/jiujitsu, r/martialarts, plus city subs (r/\<yourcity\>) for "train while visiting" posts
- **Facebook:** Worldwide BJJ Community, BJJ Fanatic Group, regional groups ("BJJ \<State/City\>"), "BJJ Globetrotters"-style travel communities, gym-owner/martial-arts-business groups
- **Discord:** BJJ / grappling servers
- **Whop / Skool** BJJ communities where creators gather

---

## 4. The "automation" — how the content engine actually works

This is the system you asked for, built to be safe and repeatable.

```
[Content Bank]  →  [Scheduler]  →  [Your Business Accounts]  →  [Analytics loop]
 captions +         Buffer /        IG / TikTok / YT /            weekly review →
 hashtags +         Metricool /     FB Page (APIs/native)         double down on
 shot briefs        Later          (Reddit/FB Groups = manual)    what worked
```

1. **Content Bank** (`content-bank.md`) — a growing library of ready-to-post pieces: full
   caption, hashtag set, CTA, and a shot brief (since video must be filmed by a human).
2. **Calendar** (`content-calendar.md`) — assigns pieces to dates/platforms, ~4 posts/week to start.
3. **Scheduler** — Buffer / Metricool / Later connect to accounts **you own** and publish on
   schedule. See `tooling.md` for setup + the API path if you later want a repo service.
4. **Analytics loop** — weekly: kill losers, clone winners, feed learnings back into the bank.

**AI's role (mine + any LLM you wire up later):** generate/refresh captions, spin variants for
A/B testing, draft weekly calendars, write reply templates, summarize weekly analytics into
"do more of X." **Human's role:** film clips, hit publish (or approve the queue), engage in
comments/Reddit/FB in real time.

**Hard "do-not" list (ToS + brand safety):**
- ❌ No fake/bot accounts, no engagement pods, no bought followers.
- ❌ No auto-DM blasts, no auto-commenting, no scripted posting into groups/subreddits.
- ❌ No scraping + mass-tagging users. ❌ No reposting others' clips without credit/permission.
- ✅ Post only from accounts you control; disclose paid partnerships (#ad); credit every creator.

---

## 5. 90-day phased roadmap

### Phase 0 — Foundation (Days 1–14)
- Reserve handles everywhere: **@bjjopenmat** (fallbacks: @bjjopenmatapp, @openmatfinder). Same handle all platforms.
- Set up IG (Business), TikTok (Business), YouTube, FB Page. Bios + link (see `tooling.md`).
- Stand up a **waitlist landing page** at `bjj-open-mat.dsylvester.io` — one sentence + one-tap signup, mobile-first, with a "Claim your gym" path for owners.
- Connect scheduler. Load first 2 weeks from the content bank.
- Recruit a **founding cohort**: personally invite 200–500 beta testers across regions/devices (diverse cohort catches 60–70% more launch-blocking bugs than a homogeneous one).

### Phase 1 — Build the audience (Days 15–60)
- Post ~4×/week/platform from the calendar. Founder posts in communities 3–5×/week (manual).
- Run the **"Founding Mats"** campaign: first 100 gyms to claim a listing get a "Founding Gym" badge + featured spotlight.
- Start light paid: **boost the 2–3 best-performing organic Reels** and test geo-targeted "join the waitlist" ads once organic hits **5–15 signups/day** (the readiness signal for paid).
- Weekly analytics review; refine pillars.

### Phase 2 — Launch runway (Days 61–90)
- Submit builds; line up the **coordinated launch window** (see §7).
- Convert waitlist → TestFlight/Play testers; push for ratings.
- Line up 5–10 micro-creators for launch-day posts; prep Product Hunt; draft press/embargo notes.
- Launch **Tuesday or Wednesday morning**; fire email + creators + Product Hunt + paid all inside a ~6-hour window to trigger store-algorithm lift.

---

## 6. Budget — "small paid boost" allocation

Organic is the engine; paid is the amplifier. Suggested first-90-day test budget (scale to comfort):

| Line item | Share | Notes |
|---|---|---|
| Boost proven organic posts (IG/TikTok) | 40% | Only boost posts already outperforming organically |
| Geo-targeted waitlist/install ads (TikTok + Meta) | 35% | TikTok health/fitness CPI ~$2–4.50; Meta cheap CPI but watch D7 retention |
| Apple Search Ads (at public launch) | 15% | Lowest iOS CPI (~$2.96) + best D7 retention — turn on when live |
| Micro-creator seeding | 10% | Product/gear/gift-card swaps with small BJJ creators |

**Benchmarks to hold yourself to (2026):** iOS CPI ~$5.84 avg / Android ~$1.92; health-fitness
$4.30–$5.50; TikTok fitness $2–$4.50. Don't scale paid until a channel beats these *and* retains.

---

## 7. Launch-day "velocity stack" (Day ~90)

All within one morning, Tue/Wed:
1. Email blast to the full waitlist ("we're live — install + rate").
2. Micro-creator posts go live simultaneously.
3. Product Hunt launch.
4. Reddit/FB posts (genuine, from the founder).
5. Paid campaigns switch on (Apple Search Ads + TikTok/Meta).

The simultaneous spike is what the store ranking algorithms reward.

---

## 8. KPIs & the weekly loop

**North-star (pre-launch):** weekly net-new **waitlist signups** + **gyms claimed**.

| Funnel stage | Metric | Phase-1 target (illustrative) |
|---|---|---|
| Reach | Views / impressions per platform | Growing week-over-week |
| Engagement | Saves + shares (weight these over likes) | Saves = intent |
| Capture | Waitlist signups/day | 5–15/day before scaling paid |
| Supply | Gyms claimed/added | 100 "Founding Gyms" by Day 90 |
| Community | Follower growth, sentiment | Steady, positive |
| Launch | Day-1 installs + ratings, D1/D7 retention | Set at build submission |

**Weekly ritual (30 min):** pull numbers → tag top 3 / bottom 3 posts → clone winners, cut
losers → adjust next week's calendar. This loop matters more than any single post.

---

## 9. Risks & guardrails
- **Community backlash to "marketing":** lead with utility and culture, never hype. Grapplers smell inauthenticity.
- **Supply/demand chicken-egg:** front-load gym recruiting; a user who searches an empty map churns. Concentrate content where you have gym density even though messaging is US-wide.
- **ToS bans:** follow §4's do-not list. One scripted-spam incident can nuke an account and the brand's goodwill.
- **Beta over-promise:** don't drive store installs before the app is public — drive the waitlist.

---

## Sources
- [Pre-Launch Waitlist Playbook (SEM Nexus)](https://semnexus.com/the-pre-launch-waitlist-playbook-for-mobile-apps)
- [Waitlist Page Strategy 2026 (Unicorn Platform)](https://unicornplatform.com/blog/waitlist-page-strategy-in-2026/)
- [App Launch Strategy 2026 (Moburst)](https://www.moburst.com/blog/app-launch-strategy/)
- [Mobile App Launch Checklist 2026 (LaunchList)](https://getlaunchlist.com/checklists/app-launch)
- [Social Media Content Ideas for Martial Arts Schools (Gymdesk)](https://gymdesk.com/blog/social-media-content-ideas-martial-arts-school-owners)
- [Best #bjj hashtags 2026 (Display Purposes)](https://displaypurposes.com/hashtags/hashtag/bjj) · [top-hashtags](https://top-hashtags.com/hashtag/bjj/)
- [How to Use Reddit's BJJ Community (BJJ Buddy)](https://bjjbuddy.com/how-to-use-reddits-bjj-community-to-get-better-faster-in-brazilian-jiu-jitsu/)
- [Worldwide BJJ Community (Facebook)](https://www.facebook.com/groups/BJJWorldwide/) · [BJJ Fanatic Group](https://www.facebook.com/groups/980934748765489/)
- [CPI Benchmarks 2026 (Business of Apps)](https://www.businessofapps.com/ads/cpi/research/cost-per-install/) · [TikTok App Install Playbook (vmobify)](https://vmobify.com/blog/tiktok-app-install-campaigns)
- [Mobile App Marketing Statistics 2026 (Digital Applied)](https://www.digitalapplied.com/blog/mobile-app-marketing-statistics-2026-install-data)
