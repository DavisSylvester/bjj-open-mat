# Nav / Report / Belt Icons / Preferences / Glass-only — Design

**Date:** 2026-07-05
**Status:** Approved (design)

## Goal

Restructure the mobile bottom navigation, add an in-app Report (issue/feature) flow that
files GitHub issues, replace the attendee belt text with branded belt-color icons in a
paged grid, persist search preferences server-side, and remove the Sport theme so the app
uses only the Glass theme. Enforce explicit `<app>-<resource_type>` naming for all CDK
resources.

## Decisions (locked)

- **Search preferences:** stored **server-side** on the user profile (Mongo), synced across
  devices, applied on the search screen at load.
- **Report submission:** save a **Mongo** report record **and** create a **GitHub issue** in
  `DavisSylvester/bjj-open-mat` labeled `bug` (issue) or `enhancement` (feature). API
  authenticates with a GitHub PAT stored in the existing `bjj-open-mat/app` secret. Graceful
  Mongo-only fallback when the token is unset (mirrors the S3 `UnconfiguredAssetStorage`).
- **Belt icons:** drawn **in-code** (Flutter `CustomPainter`) from the existing `BeltColors`
  palette — no external assets.
- **Report tab:** appears in **both** practitioner and owner shells (last item).
- **Delivery:** one spec (this doc) + one phased implementation plan (phases A–F).

## Workstreams

### A. Glass-only theme
Remove `AppTokens.sport()`, the `isSport` field, `ThemeVariant`/`ThemeNotifier`/
`themeProvider`, and the Sport `ThemeData`. Collapse all `t.isSport` branches (41 across 19
files) to their Glass form; delete `_Sport*` sibling widget trees. Remove the "Sports Ticker
Theme" toggle from Settings. `main.dart` builds the single Glass `ThemeData`.

### B. Bottom nav restructure
Practitioner tabs become `Home · Find · Profile · Report` (center "+" FAB unchanged); the
`training` branch is removed and My Training is reached via a pushed route `/profile/training`
plus a Profile-screen entry. Owner tabs gain a trailing `Report`. A new `report` shell branch
renders `ReportScreen` in each shell.

### C. Belt icons on the attendee list
New `BeltIcon` widget: rounded belt bar + knot + stripe patch, tinted per rank
(white/blue/purple/brown/black) using `BeltColors.beltData` (bg/stripe/fg), optional stripe
count. Replaces the belt-label pill in the attendee card.

### D. Attendee list → paged grid
Server: `GET /open-mats/:id/attendees` gains `page`/`limit` and returns `total` (today it
returns all). Mobile: attendee display becomes a grid (belt icon + name, ~3 columns) with a
pager, page size 12.

### E. Search preferences (server-synced)
Contract: `User.preferences { defaultWhen?, defaultWithinMi?, defaultGiType? }` and the same
optional block on `UpdateUserRequest`. API persists via the existing `PUT /users/me` and
returns on `/auth/me`. Mobile applies saved prefs on the search screen at load and offers
"Save as default" (persists via `PUT /users/me`).

### F. Report feature (full-stack)
Contract: `Report { id, userId, type:'bug'|'feature', title, description, status,
createdAt, githubIssueNumber?, githubIssueUrl? }`, `CreateReportRequest`, `ReportType`.
API: `ReportRepository` (Mongo `reports` collection), `GitHubIssueService` (REST create-issue
via PAT), `ReportFacade` (insert Mongo → create labeled issue → patch back number/url).
Routes: `POST /api/v1/reports` (auth), `GET /api/v1/reports?mine` (auth). Env: optional
`GITHUB_TOKEN`, `GITHUB_REPO` (default `DavisSylvester/bjj-open-mat`). Mobile: `ReportScreen`
with a Bug/Feature toggle, title, description, submit → success.

### G. CDK naming
Rename the auto-named assets bucket to `bjj-open-mat-assets`; audit all resources for explicit
`bjj-open-mat-<type>` names (Lambda/API/secret already conform). `GITHUB_TOKEN` lives in the
existing secret — no new resource.

## Data contracts

```
ReportType = 'bug' | 'feature'

Report {
  id: string
  userId: string
  type: ReportType
  title: string           // minLength 3
  description: string     // minLength 10
  status: 'open'          // reserved for future triage
  createdAt: string
  githubIssueNumber?: number
  githubIssueUrl?: string
}

CreateReportRequest { type: ReportType, title: string, description: string }

UserPreferences {
  defaultWhen?: string     // matches the search "When" option keys
  defaultWithinMi?: number // 1..100
  defaultGiType?: string   // gi | nogi | both
}
```

## Error handling
- GitHub failures never fail the request: the Mongo report is saved first; issue creation is
  best-effort and its number/url are patched on success, logged on failure.
- `UnconfiguredGitHubService` throws nothing — it returns `null` so the facade persists
  Mongo-only.
- Report validation (title/description length) via TypeBox on the route.

## Testing
- **API:** `ReportFacade` (Mongo save + mocked issue service, incl. GitHub-failure path),
  `GitHubIssueService` (mocked `fetch`), `UnconfiguredGitHubService`, attendees pagination,
  preferences round-trip on the user facade, reports route contract validation.
- **Mobile:** `BeltIcon` golden/widget test, `ReportScreen` validation + submit, attendee grid
  paging, prefs apply-on-load; `flutter analyze` clean.
- **Infra:** `tsc` + assert the assets bucket physical name.

## Out of scope
- Report triage/admin UI (status stays `open`).
- Editing/deleting reports.
- Migrating existing gyms/users (preferences and reports are additive/optional).
