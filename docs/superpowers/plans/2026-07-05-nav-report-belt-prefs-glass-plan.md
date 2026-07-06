# Nav / Report / Belt Icons / Preferences / Glass-only — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure mobile bottom nav (drop Schedule→Profile, add Report), add a full-stack Report→GitHub-issue flow, replace attendee belt text with branded belt-color icons in a paged grid, persist search preferences server-side, and remove the Sport theme (Glass-only). Enforce `<app>-<resource_type>` CDK naming.

**Architecture:** Flutter (Riverpod, go_router) mobile; Elysia/Bun API with TypeBox + DI container + facade→repository→Mongo; AWS CDK infra. Spec: `docs/superpowers/specs/2026-07-05-nav-report-belt-prefs-glass-design.md`.

**Tech Stack:** Bun, Elysia, TypeBox, MongoDB, Flutter, go_router, Riverpod, AWS CDK, GitHub REST API.

**Execution order:** A → B (both touch the nav); C, D, E, F are largely independent and may run after B in any order. Run `bun run verify` (api) and `flutter analyze` after each phase.

---

## Phase A — Glass-only theme

**Files:**
- Delete: `apps/mobile/lib/core/design/theme_provider.dart`
- Modify: `apps/mobile/lib/main.dart`, `apps/mobile/lib/core/design/app_theme.dart`, `apps/mobile/lib/core/design/tokens.dart`
- Modify (collapse `isSport`): `apps/mobile/lib/shared/widgets/{exp_badge,gi_badge,stat_bar,session_row,app_bottom_nav}.dart`, `apps/mobile/lib/features/discover/screens/discover_screen.dart`, `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`, `apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart`, `apps/mobile/lib/features/training/screens/my_training_screen.dart`, `apps/mobile/lib/features/notifications/screens/notifications_screen.dart`, `apps/mobile/lib/features/checkins/screens/review_screen.dart`, `apps/mobile/lib/features/settings/screens/settings_screen.dart`, `apps/mobile/lib/features/admin/screens/{add_gym_screen,owner_dashboard_screen,create_session_screen}.dart`, `apps/mobile/lib/features/profile/screens/profile_screen.dart`, `apps/mobile/lib/features/favorites/screens/favorites_screen.dart`, `apps/mobile/lib/features/search/screens/search_screen.dart`

- [ ] **A1. Simplify `main.dart` to the single Glass theme**

Remove the `themeProvider` watch and Sport branch:
```dart
// remove: import 'core/design/theme_provider.dart';
@override
Widget build(BuildContext context) {
  final router = ref.watch(routerProvider);
  return MaterialApp.router(
    title: 'BJJ Open Mat Finder',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.glass(),
    themeMode: ThemeMode.light,
    routerConfig: router,
  );
}
```

- [ ] **A2. Delete the Sport `ThemeData` and `theme_provider.dart`**

In `app_theme.dart` delete the `static ThemeData sport() {...}` method (keep `glass()`). Delete the file `core/design/theme_provider.dart`.

- [ ] **A3. Remove Sport from tokens**

In `tokens.dart`: delete `factory AppTokens.sport() {...}`; remove the `isSport` field, its constructor param, and its `copyWith` handling. Keep `AppTokens.glass()`.

- [ ] **A4. Collapse every `t.isSport` usage to its Glass (false) branch**

Rule per usage:
- Ternary `t.isSport ? X : Y` → `Y`.
- `if (t.isSport) {...}` blocks / `if (t.isSport) ...[` spreads → delete the block.
- Widgets that switch whole trees (e.g. `return t.isSport ? _SportGymDetail(...) : _GlassGymDetail(...)`) → return the Glass widget directly and **delete the `_Sport*` class**.
- `app_bottom_nav.dart`: delete the two `if (t.isSport) { return ...Sport... }` early returns and the Sport labels; keep the Glass tile builder and non-Sport labels (this file is rewritten in Phase B anyway — do the minimal collapse here).

Apply across all files in the list. Example (`exp_badge.dart`):
```dart
// before: 'beg' || 'beginner' => t.isSport ? 'Begin' : 'Beginner',
'beg' || 'beginner' => 'Beginner',
'int' || 'intermediate' => 'Intermediate',
'adv' || 'advanced' => 'Advanced',
_ => 'All Levels',
// and delete the `if (t.isSport) {...}` layout block, keeping the glass layout
```

- [ ] **A5. Remove the "Sports Ticker Theme" setting**

In `settings_screen.dart`: delete the `_SportSettings` class entirely and make `build` return the Glass settings directly (`return _GlassSettings(t: t, ref: ref);`). In `_GlassSettings`, delete the theme-toggle `ListTile` (the "Sports Ticker Theme" row + its `Consumer`/`Switch`). Remove `import '../../../core/design/theme_provider.dart';`.

- [ ] **A6. Verify no Sport remains and app compiles**

Run: `cd apps/mobile && flutter analyze`
Expected: no issues. Then verify the token/provider are gone:
Run (from repo root): `rg "isSport|ThemeVariant|themeProvider|AppTokens.sport|_Sport" apps/mobile/lib`
Expected: no matches.

- [ ] **A7. Commit**

```bash
git add apps/mobile/lib
git commit -m "refactor(mobile): remove Sport theme, use Glass only"
```

---

## Phase B — Bottom nav restructure (drop Schedule→Profile, add Report tab)

**Files:**
- Modify: `apps/mobile/lib/shared/widgets/app_bottom_nav.dart`, `apps/mobile/lib/shared/widgets/om_widgets.dart` (OMBottomNav), `apps/mobile/lib/app/router.dart`, `apps/mobile/lib/features/profile/screens/profile_screen.dart`
- Create: `apps/mobile/lib/features/report/screens/report_screen.dart` (stub here; filled in Phase F)
- Test: `apps/mobile/test/nav_tabs_test.dart`

- [ ] **B1. Rewrite `AppBottomNav` tabs to Home/Find/Profile/Report**

Tabs list becomes:
```dart
final tabs = [
  (id: 'home',    icon: LucideIcons.home,       label: 'Home'),
  (id: 'search',  icon: LucideIcons.search,     label: 'Find'),
  (id: 'profile', icon: LucideIcons.user,       label: 'Profile'),
  (id: 'report',  icon: LucideIcons.messageSquareWarning, label: 'Report'),
];
```
Keep the center "+" FAB between the left two and right two tabs (`tabs.sublist(0,2)` / `tabs.sublist(2)`). Update the doc comment on `active`.

- [ ] **B2. Add a Report tab to the owner nav (`OMBottomNav`)**

In `om_widgets.dart`, append a trailing `report` item to the owner tab set (label `Report`, icon `LucideIcons.messageSquareWarning`) and ensure its index maps to the new owner `report` branch (Phase B4).

- [ ] **B3. Create a `ReportScreen` stub**

`apps/mobile/lib/features/report/screens/report_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Report')),
      body: Center(child: Text('Report a bug or request a feature', style: t.bodyStyle)),
    );
  }
}
```

- [ ] **B4. Update the router shells**

In `router.dart`:
- Practitioner shell: **remove** the `training` `StatefulShellBranch` (the `/training` route). Add a new trailing branch for `/report` → `ReportScreen`. Update `_pracTabs` to `['home', 'search', 'profile', 'report']`.
- Move My Training under Profile: add a child route to the `/profile` route: `GoRoute(path: 'training', builder: (c, s) => const MyTrainingScreen())` (route `/profile/training`).
- Owner shell: add a trailing branch `/owner/report` → `ReportScreen`.
- Keep `_ScaffoldWithNavBar` mapping `_pracTabs[shell.currentIndex]`; ensure owner `OMBottomNav` index count matches its branches.

- [ ] **B5. Add a "My Training" entry on the Profile screen**

In `profile_screen.dart`, add a list row/button "My Training" that calls `context.push('/profile/training')` (place near existing profile actions).

- [ ] **B6. Test: tab id/index mapping**

`apps/mobile/test/nav_tabs_test.dart` — assert the practitioner tab order and that `schedule` is absent:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pracTabs = ['home', 'search', 'profile', 'report'];
  test('practitioner tabs drop schedule and end with report', () {
    expect(pracTabs.contains('schedule'), isFalse);
    expect(pracTabs.last, 'report');
    expect(pracTabs.indexOf('profile'), 2);
  });
}
```
(If `_pracTabs` is private, expose the tab-id list via a small public `const kPracTabs` in `app_bottom_nav.dart` and import it in both the router and the test.)

- [ ] **B7. Verify + commit**

Run: `cd apps/mobile && flutter analyze && flutter test test/nav_tabs_test.dart`
```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): drop Schedule tab (move under Profile), add Report tab"
```

---

## Phase C — Belt icons + paged attendee grid

**Files:**
- Create: `apps/mobile/lib/shared/widgets/belt_icon.dart`
- Modify: `apps/mobile/lib/features/open_mats/widgets/going_section.dart`, `apps/mobile/lib/features/open_mats/data/rsvp_repository.dart`, `apps/mobile/lib/features/open_mats/models/attendee.dart` (add `beltStripes` if absent)
- Modify (API): `apps/api/src/routes/open-mat.routes.mts`, `apps/api/src/facades/open-mat.facade.mts`, `apps/api/src/repositories/rsvp.repository.mts`
- Test: `apps/mobile/test/belt_icon_test.dart`, `apps/api/test/attendees-pagination.test.mts`

- [ ] **C1. API test (red): attendees pagination**

`apps/api/test/attendees-pagination.test.mts` — using the existing fakes pattern, RSVP 25 users to one session/date and assert `attendeeUserIds(id, date, {skip, limit})` returns the page slice and a `total` count.
```typescript
import { describe, expect, it } from "bun:test";
// build an OpenMatFacade with a fake rsvp repo holding 25 user ids;
// expect page 1 (limit 12) -> 12 ids, and total -> 25.
```
Run: `cd apps/api && bun test attendees-pagination` → FAIL.

- [ ] **C2. API: paginate attendees**

- `rsvp.repository.mts`: add `countAttendees(openMatId, sessionDate)` and make the attendee-id query accept `skip`/`limit`.
- `open-mat.facade.mts`: `attendeeUserIds(id, date, { skip, limit })` returns `{ ids, total }`.
- `open-mat.routes.mts` `GET /:id/attendees`: read `page`/`limit` from query (default page 1, limit 12), call the paginated facade, hydrate the page, and return `list(attendees, { page, limit, total })`. Extend `SessionDateQuery` (or add a query schema) with optional `page`/`limit`.

Run: `cd apps/api && bun test attendees-pagination` → PASS. Then `bun run verify`.

- [ ] **C3. Mobile: `BeltIcon` widget (CustomPainter)**

`apps/mobile/lib/shared/widgets/belt_icon.dart` — draws a rounded belt bar in `BeltColors.beltData[rank]['bg']`, a contrasting knot, and a stripe patch near the tip using `['stripe']`, with up to `stripes` white pips. Signature:
```dart
class BeltIcon extends StatelessWidget {
  final String rank;      // white|blue|purple|brown|black
  final int stripes;      // 0..4
  final double size;      // width; height ~= size * 0.42
  const BeltIcon({super.key, required this.rank, this.stripes = 0, this.size = 40});
  // build(): CustomPaint(size: Size(size, size*0.42), painter: _BeltPainter(rank, stripes))
}
```
Use `BeltColors.beltData` from `app/theme.dart`. Unknown rank → white.

- [ ] **C4. Mobile test (red→green): `BeltIcon`**

`apps/mobile/test/belt_icon_test.dart` — pump `BeltIcon(rank: 'purple', stripes: 2)` and assert it builds a `CustomPaint`; assert each known rank renders without throwing and an unknown rank falls back to white (verify via the painter's resolved color exposed through a `@visibleForTesting` getter).
Run: `cd apps/mobile && flutter test test/belt_icon_test.dart`.

- [ ] **C5. Mobile: attendee model carries stripes**

In `attendee.dart` add `final int beltStripes;` (default 0) and parse `json['beltStripes'] as int? ?? 0`. Ensure the API attendee hydration already includes `beltStripes` (it does — from the user profile fallback).

- [ ] **C6. Mobile: paged attendee grid in `GoingSection`**

Replace `_AttendeeCard` (the list of rows with belt pills) with a **grid**:
- Add `page` state (default 1) and fetch via a paginated `attendeesProvider` keyed by `(openMatId, sessionDate, page)`; update `RsvpRepository.attendees` to accept `page`/`limit` (default 12) and return items + total (wrap in a small `AttendeePage { items, total }`).
- Render a `GridView` (3 columns, `shrinkWrap`, `NeverScrollableScrollablePhysics`) of cells: `BeltIcon(rank: a.beltRank, stripes: a.beltStripes)` above the name (ellipsized), tappable to `/user/:id`.
- Below the grid, a pager: "Page X of ceil(total/12)" with prev/next chevrons (disabled at ends). The "Going" count uses `total`.

- [ ] **C7. Verify + commit**

Run: `cd apps/api && bun run verify` and `cd apps/mobile && flutter analyze && flutter test`.
```bash
git add apps/api apps/mobile
git commit -m "feat(open-mats): branded belt icons + paged attendee grid"
```

---

## Phase D — Search preferences (server-synced)

**Files:**
- Modify: `packages/contract/src/schemas/user.mts`, `packages/contract/src/schemas/requests/user-requests.mts`
- Modify (API): `apps/api/src/facades/user.facade.mts` (ensure preferences pass through update/read; repo spreads already persist)
- Modify (mobile): `apps/mobile/lib/core/auth/auth_service.dart` (UserProfile.preferences), `apps/mobile/lib/features/search/screens/search_screen.dart`
- Test: `apps/api/test/user-preferences.test.mts`, extend `apps/mobile` search prefs (widget/unit)

- [ ] **D1. Contract: add `UserPreferences`**

In `user.mts` add:
```typescript
export const UserPreferences = t.Object({
  defaultWhen: t.Optional(t.String()),
  defaultWithinMi: t.Optional(t.Number({ minimum: 1, maximum: 100 })),
  defaultGiType: t.Optional(t.String()),
}, { $id: "UserPreferences" });
```
Add `preferences: t.Optional(UserPreferences)` to `User`. In `user-requests.mts` add `preferences: t.Optional(UserPreferences)` to `UpdateUserRequest`. Export types.

- [ ] **D2. API test (red→green): preferences round-trip**

`apps/api/test/user-preferences.test.mts` — via `UserFacade`, update a user with `preferences: { defaultWhen: 'this_week', defaultWithinMi: 25 }` and assert `getById` returns them. (Repo spread persists `preferences`; add explicit mapping only if the facade whitelists fields.)
Run: `cd apps/api && bun test user-preferences` then `bun run verify`.

- [ ] **D3. Mobile: `UserProfile.preferences`**

In `auth_service.dart` add a `UserPreferences` value type (`defaultWhen`, `defaultWithinMi`, `defaultGiType`) to `UserProfile` with `fromJson`/`toJson`; include it in `toJson()` so `updateProfile` can send it.

- [ ] **D4. Mobile: apply + save prefs on the search screen**

In `search_screen.dart`:
- On init, read `ref.read(authStateProvider).user?.preferences` and seed the When / Within (and giType) controls when present.
- Add a "Save as default" affordance (e.g., a bookmark icon in the filters area) that calls `ref.read(authStateProvider.notifier).updateProfile({'preferences': {...current filters...}})` and shows a confirmation snackbar.

- [ ] **D5. Verify + commit**

Run: `cd apps/api && bun run verify` and `cd apps/mobile && flutter analyze`.
```bash
git add packages/contract apps/api apps/mobile
git commit -m "feat(search): server-synced default When/Within preferences"
```

---

## Phase E — Report feature (Mongo + GitHub issue)

**Files:**
- Create (contract): `packages/contract/src/enums/report-type.mts`, `packages/contract/src/schemas/report.mts`, `packages/contract/src/schemas/requests/report-requests.mts` (+ barrel exports in the respective `index.mts`)
- Create (API): `apps/api/src/repositories/report.repository.mts`, `apps/api/src/services/github-issue.service.mts`, `apps/api/src/facades/report.facade.mts`, `apps/api/src/routes/report.routes.mts`
- Modify (API): `apps/api/src/config/env.mts`, `apps/api/src/container.mts`, `apps/api/src/db/collections.mts` (add `reports`), `apps/api/src/index.mts` or wherever routes are registered
- Create (mobile): `apps/mobile/lib/features/report/data/report_repository.dart`, `apps/mobile/lib/features/report/models/report.dart`; fill `apps/mobile/lib/features/report/screens/report_screen.dart`
- Modify (mobile): `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/api/test/{report-facade,github-issue-service,report-routes}.test.mts`, `apps/mobile/test/report_screen_test.dart`

- [ ] **E1. Contract: Report schema**

`report-type.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";
export const ReportType = t.Union([t.Literal("bug"), t.Literal("feature")], { $id: "ReportType" });
export type ReportType = Static<typeof ReportType>;
```
`report.mts` (`Report` object per spec: id, userId, type, title, description, status, createdAt, optional githubIssueNumber/githubIssueUrl). `report-requests.mts`:
```typescript
export const CreateReportRequest = t.Object({
  type: ReportType,
  title: t.String({ minLength: 3, maxLength: 120 }),
  description: t.String({ minLength: 10, maxLength: 4000 }),
}, { $id: "CreateReportRequest" });
```
Add barrel exports.

- [ ] **E2. API env: optional GitHub config**

In `env.mts` add `GITHUB_TOKEN: t.Optional(t.String())` and `GITHUB_REPO: t.Optional(t.String())`; map to `githubToken` and `githubRepo` (default `"DavisSylvester/bjj-open-mat"`) on `AppEnv`.

- [ ] **E3. API test (red): GitHubIssueService**

`apps/api/test/github-issue-service.test.mts` — inject a fake `fetch` and assert `createIssue({title, body, labels})` POSTs to `https://api.github.com/repos/<repo>/issues` with the `Authorization: Bearer` header and returns `{ number, url }` from the mocked response; assert it throws/returns error shape on non-2xx.

- [ ] **E4. API: GitHubIssueService + Unconfigured fallback**

`github-issue.service.mts`:
```typescript
export interface GitHubIssue { number: number; url: string; }
export interface GitHubIssueService {
  createIssue(input: { title: string; body: string; labels: string[] }): Promise<GitHubIssue>;
}
```
- `HttpGitHubIssueService(token, repo, fetchFn = fetch)` — POSTs the issue, returns `{ number, url }`.
- `UnconfiguredGitHubIssueService` — `createIssue` returns a rejected/sentinel the facade treats as "skip" (or the container wires `null` and the facade checks). Make `bun test github-issue-service` PASS.

- [ ] **E5. API test (red): ReportFacade**

`apps/api/test/report-facade.test.mts` — with a fake report repo + fake issue service:
- `create(userId, {type:'bug', title, description})` inserts a Mongo report, calls `createIssue` with labels `['bug']` (or `['enhancement']` for `feature`), and patches `githubIssueNumber`/`githubIssueUrl` back.
- when the issue service throws, the report is still saved (no issue fields) and no error propagates.
- `listMine(userId)` returns the user's reports.

- [ ] **E6. API: ReportRepository + ReportFacade + route + DI**

- `report.repository.mts`: `insert`, `update`, `findById`, `listByUser`, `ensureIndexes` (index `userId`). Add `reports` to `collections.mts`.
- `report.facade.mts`: `create` (label = `type === 'feature' ? 'enhancement' : 'bug'`; title `[Bug]`/`[Feature] <title>`, body includes description + `Reported by <userId>`), `listMine`.
- `report.routes.mts`: `POST /api/v1/reports` (`requireAuth`, body `CreateReportRequest`) and `GET /api/v1/reports?mine` (`requireAuth`).
- `container.mts`: build `reportRepo`, `githubIssueService` (`env.githubToken ? new HttpGitHubIssueService(...) : unconfigured`), `reportFacade`; add to `Container` interface + `ensureIndexes`.
- Register `reportRoutes(container)` where the other route groups are mounted.

Run: `cd apps/api && bun test report-facade github-issue-service` → PASS, then `bun run verify`.

- [ ] **E7. API test (red→green): reports route contract**

`apps/api/test/report-routes.test.mts` — boot the app with the bypass token; `POST /api/v1/reports` with a too-short title → 400; a valid body → 200 with `data.id`; `GET /api/v1/reports?mine` → 200 list. (Use `UnconfiguredGitHubIssueService` so no network is hit.)

- [ ] **E8. Mobile: Report model + repository**

`report.dart` (mirror contract) and `report_repository.dart`:
```dart
Future<Report> create({required String type, required String title, required String description});
Future<List<Report>> listMine();
```
POST/GET `/api/v1/reports` via the auth'd Dio. Add endpoints to `endpoints.dart`.

- [ ] **E9. Mobile: fill `ReportScreen`**

Replace the stub with a form: a Bug/Feature segmented toggle, title `TextField` (min 3), description multiline (min 10), submit button (disabled until valid / while saving). On submit call `reportRepository.create(...)`, then show a success state ("Thanks — we filed this"). Surface API errors inline.

- [ ] **E10. Mobile test: ReportScreen validation**

`apps/mobile/test/report_screen_test.dart` — pump the screen, assert submit is disabled with empty/short inputs and enabled once title ≥3 and description ≥10; (mock the repository provider to assert `create` is called with the toggled type).
Run: `cd apps/mobile && flutter test test/report_screen_test.dart`.

- [ ] **E11. Verify + commit**

Run: `cd apps/api && bun run verify` and `cd apps/mobile && flutter analyze && flutter test`.
```bash
git add packages/contract apps/api apps/mobile
git commit -m "feat(report): in-app bug/feature reports saved to Mongo and filed as GitHub issues"
```

---

## Phase F — CDK naming pass

**Files:** `apps/api/src/config/env.mts` (already done in E2 — no change), `infra/lib/api-stack.ts`
**Test:** `infra` type-check + a naming assertion.

- [ ] **F1. Name the assets bucket explicitly**

In `api-stack.ts` set `bucketName: "bjj-open-mat-assets"` on the `AssetsBucket` (safe — never deployed). Confirm every other resource has an explicit `bjj-open-mat-<type>` physical name where one applies:
- Lambda `functionName: "bjj-open-mat-api"` ✓
- `HttpApi` `apiName: "bjj-open-mat-api"` ✓
- Secret `secretName: "bjj-open-mat/app"` ✓ (kept; it is the app secret)
- ACM cert / DomainName / ARecord derive names from the DNS name — leave as-is (no arbitrary physical name to set).

- [ ] **F2. Add `GITHUB_TOKEN` to the Lambda's secret overlay documentation**

`GITHUB_TOKEN` (and optional `GITHUB_REPO`) are read from the `bjj-open-mat/app` secret JSON at cold start — no new CDK resource. Add a comment on the `AppSecret` description noting the added keys (`MONGODB_URI, AUTH_BYPASS_SECRET, GITHUB_TOKEN`).

- [ ] **F3. Verify + commit**

Run: `cd infra && npx tsc --noEmit -p tsconfig.json` → clean.
```bash
git add infra
git commit -m "chore(infra): explicit bjj-open-mat-* resource names; document GITHUB_TOKEN secret key"
```

---

## Cross-cutting verification (after all phases)
- `cd apps/api && bun run verify` (type-check + lint + test) — all green.
- `cd apps/mobile && flutter analyze` clean; `flutter test` green.
- `cd infra && npx tsc --noEmit` clean.
- Manual emulator smoke: nav shows Home/Find/Profile/Report; My Training reachable under Profile; attendee grid pages; Report submits (Mongo saved; GitHub issue created once `GITHUB_TOKEN` is set + deployed); search prefs persist across app restarts.

## Deployment notes
- Report→GitHub needs `GITHUB_TOKEN` (a PAT with `repo` scope) added to the `bjj-open-mat/app` secret, then `cd infra && bun run deploy`. Without it, reports save to Mongo only (graceful).
- The assets bucket rename + any infra change requires `cd infra && bun run deploy`.
