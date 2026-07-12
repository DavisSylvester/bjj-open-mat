# Tooling & Account Setup — the safe "automation" layer

> How the content engine actually publishes. Principle: **schedule from accounts you own,
> stay inside every platform's ToS.** No bots, no fake accounts, no scripted group spam.

## 1. Account setup checklist (Phase 0)

Reserve the **same handle everywhere**. Priority: `@bjjopenmat` → fallbacks `@bjjopenmatapp`, `@openmatfinder`.

| Platform | Account type | Notes |
|---|---|---|
| Instagram | **Business** (not Creator) | Business unlocks the scheduling APIs + insights. Link a FB Page. |
| TikTok | **Business** | Needed for TikTok Content Posting API / most schedulers. |
| YouTube | Brand channel | For Shorts repurposing + search long-tail. |
| Facebook | **Page** (+ personal for Groups) | Page is schedulable; Groups are manual from your personal profile. |
| Reddit | Personal account, aged | Build karma first; posting from a day-old account screams spam. |

**Bio template (IG/TikTok, ≤150 chars):**
```
🥋 Find BJJ open mats anywhere · See who's going · Tap "I'm going"
👇 Join the founding list
```
**Link in bio:** point to `https://bjj-open-mat.dsylvester.io` (waitlist). Use a link-in-bio
tool (Linktree/Beacons) only if you need multiple links (waitlist + "claim your gym" + support).

## 2. The scheduler (recommended path — no code)

Pick **one** to start. All connect to accounts you own and publish on schedule.

| Tool | Why | Cost posture |
|---|---|---|
| **Metricool** | Best analytics + IG/TikTok/YT/FB in one; good free tier | Free → ~$18/mo |
| **Buffer** | Simplest UX, great for a solo operator | Free → ~$6/channel/mo |
| **Later** | Strong visual IG planner | Free → paid |

**Weekly workflow:**
1. Batch-film 1–2 weeks of vertical clips in one session.
2. Drop clips + captions (from `content-bank.md`) into the scheduler, mapped to `content-calendar.md`.
3. Approve the queue. Scheduler auto-publishes.
4. **Manual, live:** Stories, Reddit, FB Groups, and all comment/DM engagement.
5. End of week: export analytics → update the calendar (clone winners, cut losers).

## 3. The API path (only if you later want a repo service)

You chose the **content-engine + calendar** scope, so this is optional/future. If you ever want
autonomous posting built into this monorepo, the *legitimate* route is official APIs from your
own business accounts:

- **Instagram/Facebook** → [Meta Graph API](https://developers.facebook.com/docs/instagram-api) — Content Publishing endpoints; requires a FB App + Business verification + long-lived tokens. Rate-limited (IG: ~25 posts/24h).
- **TikTok** → [TikTok Content Posting API](https://developers.tiktok.com/doc/content-posting-api-get-started) — app review required; supports direct post + inbox draft.
- **YouTube** → YouTube Data API (`videos.insert`) with OAuth.
- **Reddit/FB Groups** → **no compliant auto-post path for promotion.** Keep manual.

If built here, it'd live as a small service (e.g. `apps/social-poster`) reading the content bank +
a cron, calling those APIs. **Still bound by rate limits + ToS** — the win over a scheduler is
marginal for a solo brand, so only build it if volume justifies it. An LLM (Claude) can generate/
refresh captions via the Anthropic API and drop them into the queue; a human still films + approves.

## 4. AI in the loop (what to automate vs. keep human)

| Automate (AI/scheduler) | Keep human |
|---|---|
| Draft + variant captions, hashtag sets | Filming clips, on-camera presence |
| Weekly calendar drafts | Hitting publish / approving the queue |
| Reply-template drafts | Live comments, DMs, Reddit/FB replies |
| Weekly analytics → "do more of X" summary | Community judgment + relationship-building |

## 5. Waitlist plumbing
- Landing page: one sentence + one-tap email capture, mobile-first (see plan §5). Owner path: "Claim your gym."
- Options: a waitlist tool (LaunchList/Waitlister) or a simple form → email list (so you can blast on launch day).
- Track: signups/day, source (UTM per platform), gyms-claimed. This is your north-star dashboard.

## 6. Guardrails (repeat of the do-not list)
- One brand account per platform, owned by you. No fake accounts, engagement pods, or bought followers.
- No auto-DM/auto-comment tools. No scripted posting into groups or subreddits.
- Disclose paid partnerships (`#ad`), credit every creator, get permission before reposting.
