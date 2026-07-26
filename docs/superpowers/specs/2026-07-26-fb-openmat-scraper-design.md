# Design: Facebook Open-Mat Scraper Skill

**Date:** 2026-07-26
**Status:** Approved (pending spec review)
**Owner:** Davis Sylvester

## Goal

Discover BJJ **Open Mat** sessions posted in Facebook groups, extract each
session's **date/time, gym, location, and post author**, dedupe against the
**production** BJJ Open Mat database, auto-create gyms that don't exist yet, and
insert the genuinely-new sessions as **unverified** community submissions. An
**initial run** scans ~1 year of history; **daily runs** scan only what's new.
**United States only** for now.

Delivered as a **project-local Claude Code skill** committed to this repo, driven
by Claude with a human in the loop, backed by helper scripts.

## Decisions (from brainstorming)

| Decision | Choice |
|---|---|
| Target database (dedupe + insert) | **Production API** (AWS Lambda) |
| Insert path / status | **API `POST /open-mats`**, sessions land **unverified** |
| Post discovery | **Full-feed scroll** back ~1 year (throttled + resumable); daily = since-checkpoint |
| Run cadence | **Scheduled/automated** via a saved FB session; manual login to (re)seed it |
| Prod-insert safety | **Review-first** — nothing POSTed until `--commit` |
| Facebook session | **Save `storageState`** after a headed login; reuse headless; re-login on expiry |
| Prod-insert auth | **Your logged-in user token** (a JWT you provide per insert run) |

### Two reconciliations (original brief vs answers)

1. **"I log in each run" vs "scheduled/automated."** Reconciled: the **first run is
   headed** and you complete the Facebook login; Playwright persists the session
   (`storageState`, gitignored). **Scheduled runs reuse that session headless.**
   When it expires (logout/2FA), the run **aborts and notifies** you to re-login.
   No Facebook password is ever stored.

2. **"All posts, last year."** A literal exhaustive year-scroll of a busy group is
   the single most likely trigger for Facebook rate-limiting/blocking the account.
   Reconciled by **keeping the intent but making it safe**: the initial run scrolls
   back ~1 year **with throttling and a resumable per-group checkpoint**, so a block
   never loses progress; **daily runs only scan posts newer than the checkpoint.**

### Verified-status nuance

The prod API sets `verified = true` when the submitter is an **admin** or the
**owner of the referenced gym** (`open-mat.facade.mts`). Because inserts use *your*
user token, sessions may auto-verify if your account is admin/owner. To honor the
"unverified" decision, the insert step should use a **practitioner-role token**;
if only an admin token is available, sessions will be verified — the skill will
**log which status each insert received** so there are no surprises.

## Context / current state (from code exploration)

- **Create session:** `POST /api/v1/open-mats` (`requireAuth`). Body
  `CreateOpenMatRequest` accepts either `gymId` **or** an inline `newGym` block;
  the server geocodes `newGym.postalCode` via the `zipcodes` package. Required:
  `title`, `startTime`, `endTime`, and a gym reference. Optional: `dayOfWeek`,
  `specificDate`, `isRecurring`, `giType` (default `both`), `skillLevel` (default
  `all`), `feeCents`.
- **Create gym (standalone):** `POST /api/v1/gyms` (`requireOwner`). Not needed if
  we use the `newGym` inline path on the session create.
- **Dedupe reads:** `GET /api/v1/gyms/nearby?lat&lng&radiusKm`,
  `GET /api/v1/open-mats?gymId=&dayOfWeek=&specificDate=`. No DB-level uniqueness —
  the tool **must** dedupe itself.
- **Geo:** coordinates stored as GeoJSON `[lng, lat]`; server geocodes from ZIP.
- **Auth:** `Authorization: Bearer <token>`; Auth0 JWT (or `AUTH_BYPASS_SECRET`
  locally). Prod uses a real user JWT.
- **Skills:** `.claude/skills/<name>/SKILL.md` with YAML frontmatter
  (`name`, `description`, `argument-hint`). None project-local yet — this is the
  first.
- **Existing seed pipeline** (`scripts/gym-research/`) shows the house style:
  dry-run by default, explicit `--commit`, `.env` from `apps/api/.env`.
- **Prod API base:** `https://api.bjj-open-mat.dsylvester.io` (per `package.json`
  build defines). Local: `http://localhost:3100`. API prefix `/api/v1`.

## Architecture — 5-stage pipeline

```
[1 Collect] → [2 Parse] → [3 Dedupe/Resolve] → [4 Review gate] → [5 Insert]
 Playwright     Claude       vs Production API      you approve      POST prod
```

Each stage reads the previous stage's file output and writes its own, so stages
are independently runnable, inspectable, and testable. Files live under
`docs/open-mats/`.

### Files & layout

```
.claude/skills/fb-open-mat-scraper/SKILL.md      # the skill (committed)
scripts/fb-open-mat/
  groups.json                                    # group/post URL collection (committed)
  collect.mts                                    # Stage 1 (Playwright)
  resolve.mts                                    # Stage 3 (dedupe + gym match, prod reads)
  insert.mts                                     # Stage 5 (prod POST, --commit gated)
  lib/                                           # shared: api client, geocode-match, checkpoint
  test/                                          # unit tests (parser + dedupe fixtures)
docs/open-mats/
  raw/<group>-<YYYY-MM-DD>.json                  # Stage 1 raw posts (gitignored)
  xlsx/<group>-<file>.xlsx                       # downloaded schedules (gitignored)
  found-<YYYY-MM-DD>.json                        # Stage 2 all candidates
  new-<YYYY-MM-DD>.json                          # Stage 3 new-only (deduped)
  inserted-<YYYY-MM-DD>.json                     # Stage 5 insert log
  checkpoints.json                               # per-group last-scanned marker (gitignored)
```

### Group collection config (`scripts/fb-open-mat/groups.json`)

```json
[
  { "url": "https://www.facebook.com/groups/674876162581204/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/rollfinder/",       "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/250091745169936/",  "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/2132087287030661/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/674876162581204/posts/7832282886840460/", "type": "post", "region": "US" }
]
```

New groups are added by appending here — no code change.

### Stage 1 — Collect (Playwright)

- Launches Playwright. **Headed + manual login** when no valid saved session;
  otherwise **headless with saved `storageState`**.
- For each entry: navigate; for `group`, scroll the feed (initial: ~1 year;
  daily: until a post older than the checkpoint), **throttled** (randomized delays)
  to reduce block risk; for `post`, read that single post + comments.
- Also opens **pinned posts** and the group's **Files tab**, downloading any
  `.xlsx`/`.csv` schedule into `docs/open-mats/xlsx/`.
- Extracts each post's **text, author name, permalink, post timestamp**.
- On a Facebook block or an expired session: **stop, save progress to the
  checkpoint, and notify** (no partial garbage).
- Output: `docs/open-mats/raw/<group>-<date>.json` (+ downloaded files).

### Stage 2 — Parse (Claude, with an Excel helper)

- Claude reads the raw posts and any Excel rows and extracts, per candidate:
  `sourceUrl`, `author`, `gymName`, `address`/`city`/`state`/`postalCode`,
  `dayOfWeek`+`startTime`+`endTime` **or** `specificDate`, `isRecurring`,
  `giType`, `skillLevel`, `feeCents`, plus a `confidence` and the raw snippet.
- Ambiguous/incomplete posts (no gym, no time) are dropped with a logged reason.
- **US-only filter:** keep only valid US `state`/ZIP; drop others.
- Excel schedules parsed via the `xlsx` npm package into the same candidate shape.
- Output: **`docs/open-mats/found-<date>.json`** — *all* candidates (the "all
  found" file).

### Stage 3 — Dedupe & resolve gym (production reads)

For each candidate (`resolve.mts`):
- **Gym resolve:** geocode the candidate location (ZIP → lat/lng via `zipcodes`);
  query prod `GET /gyms/nearby`; pick a match by **name-overlap ≥ 50% within
  ~3 km** (the existing heuristic). Match → attach `gymId`; no match → flag for
  **inline `newGym`** creation at insert time.
- **Session dedupe:** query prod `GET /open-mats?gymId=&dayOfWeek=` (or
  `specificDate`) and compare `startTime`. Exists → drop (with reason). New → keep.
- Output: **`docs/open-mats/new-<date>.json`** — new sessions only (the "checked
  against DB" file). **No duplicates by construction.**

### Stage 4 — Review gate

Because Stage 5 writes to **production**, the pipeline **stops here by default**.
It prints a summary of `new-<date>.json` (counts, new-gym list, samples). Insert
happens only when you review and pass `--commit`. Unattended scheduled runs may
pass `--auto-commit` to skip the gate explicitly.

### Stage 5 — Insert (production API, unverified)

- For each new session, `POST /api/v1/open-mats` with `newGym` inline when the gym
  is new (server geocodes + creates the gym atomically).
- **Auth:** `Authorization: Bearer <your JWT>`, provided per run via env
  (`FB_SCRAPER_API_TOKEN`) — never committed. Records the returned `verified`
  status per insert (see nuance above).
- **Re-checks dedupe immediately before each POST** (idempotent-safe across
  re-runs and concurrent daily runs).
- Advances the per-group checkpoint on success.
- Output: **`docs/open-mats/inserted-<date>.json`** (id, gym, status, sourceUrl).

## Error handling & safety

- Stages 1–4 are **read-only** w.r.t. production; only Stage 5 writes, and it's
  **`--commit`-gated + idempotent**.
- **Resumable checkpoints** per group; **throttled** scrolling; **abort-and-notify**
  on FB block or expired session.
- Gitignore: `storageState`, `FB_SCRAPER_API_TOKEN`, `docs/open-mats/raw/`,
  `docs/open-mats/xlsx/`, `checkpoints.json`. Committed: `groups.json`,
  `found-*.json`/`new-*.json`/`inserted-*.json` are **kept local** (gitignored too,
  to avoid committing scraped PII) — only the skill + scripts + this spec are
  committed.
- Respect that Facebook scraping is inherently fragile and against FB's ToS for
  automation; this is a personal, low-volume, human-initiated tool.

## Testing

- **Parser unit tests:** sample post texts (recurring "every Sunday 10am", specific
  "this Saturday", non-US, no-time noise, gym-name variants) → expected structured
  candidates; assert US filter and drop-reasons.
- **Dedupe/gym-match unit tests:** fixtures for name-overlap and distance
  thresholds (match, near-miss, no-match) and session existence.
- **Excel-parse unit test:** a small `.xlsx` fixture → candidates.
- Playwright collection is validated **manually against your real login** (FB can't
  be unit-tested); a smoke check confirms selectors still find posts.

## Out of scope

- Non-US regions (deferred; `region` field already carries the filter).
- Fully unattended auth (FB 2FA/expiry makes this unreliable; re-login-on-expiry is
  the accepted compromise).
- Comment-thread mining beyond the top post (initial version reads post bodies +
  the one linked post's comments).
- Editing/verifying sessions in-app (owners/admin do that via existing flows).

## Risks / open items

- **Facebook selectors & blocking:** FB's DOM changes and anti-automation may break
  collection; mitigated by throttling, checkpoints, and manual-login fallback.
- **Prod token role:** an admin/owner token auto-verifies inserts; a practitioner
  token keeps them unverified. Confirm which token you'll supply at insert time.
- **Parse accuracy:** freeform posts vary; `confidence` + the review gate keep bad
  parses out of production until you approve.
