---
name: fb-open-mat-scraper
description: Scrape Facebook groups for BJJ open-mat sessions and add new ones to the production database. Use when the user says "scrape facebook for open mats", "find open mats on facebook", "run the fb open mat scraper", or asks to import open-mat sessions from Facebook groups. US only. Writes to PRODUCTION behind a --commit review gate.
argument-hint: [--initial]
---

# Facebook Open-Mat Scraper

Five-stage pipeline. Run stages in order; never skip the review gate before insert.
Design: `docs/superpowers/specs/2026-07-26-fb-openmat-scraper-design.md`.

## Preconditions
- `FB_SCRAPER_API_TOKEN` = a JWT from a logged-in app session (practitioner role to
  keep inserts unverified; admin/owner will auto-verify — the insert step logs which).
- Group URLs live in `scripts/fb-open-mat/groups.json`. Add new groups there.

## Stage 1 — Collect (Playwright)
Run `bun run scripts/fb-open-mat/collect.mts` (add `--initial` for the first ~1-year
backfill; omit for daily since-checkpoint runs). First run is headed: tell the user to
complete the Facebook login in the window; the session is saved for later headless runs.
Output: `docs/open-mats/raw/<group>-<date>.json` + any `.xlsx` in `docs/open-mats/xlsx/`.

## Stage 2 — Parse (you, Codex)
Read every `docs/open-mats/raw/*-<date>.json` and any Excel via
`scripts/fb-open-mat/lib/xlsx-parse.mts`. For each post that describes an open mat,
build a Candidate (see `scripts/fb-open-mat/lib/types.mts`): use
`parseSchedule`/`parseGiType`/`parseSkillLevel`/`parseFeeCents` from `lib/parse.mts`
for time/day/gi/fee; read the gym name + address/city/state/zip from the post text
yourself. Drop posts with no gym or no parseable time (log why). Keep US only.
Write ALL candidates to `docs/open-mats/found-<date>.json`.

## Stage 3 — Dedupe & resolve
Run `bun run scripts/fb-open-mat/resolve.mts <date>`. Produces
`docs/open-mats/new-<date>.json` (new-only, gyms resolved or flagged for creation).

## Stage 4 — Review gate
Show the user `new-<date>.json`: count, which gyms are new, a few samples. Get
explicit approval before Stage 5.

## Stage 5 — Insert (production)
Dry run first: `bun run scripts/fb-open-mat/insert.mts <date>`. On approval:
`bun run scripts/fb-open-mat/insert.mts <date> --commit`. Writes
`docs/open-mats/inserted-<date>.json`. Report inserted/error counts and any that
landed verified.

## Daily runs
Repeat Stages 1–5 without `--initial`. Collection only scans posts newer than the
per-group checkpoint. If Facebook shows a login form, the saved session expired —
re-run headed to refresh it.
