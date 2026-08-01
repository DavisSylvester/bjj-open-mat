# Mobile Name Capture — Implementation Report

## Status
COMPLETE

## Commits
- 733ed27 feat(mobile): add firstName/lastName to UserProfile model
- 03de045 feat(mobile): thread firstName/lastName through syncProfile
- 36c4141 feat(mobile): add NameCompletionDialog widget
- b548ec3 test(mobile): widget tests for NameCompletionDialog
- 9bd52d0 feat(mobile): show name completion prompt on discover screen when displayName blank
- da192a6 feat(mobile): show name completion prompt on owner dashboard when displayName blank

## Test Summary
All 386 tests pass (`flutter test`).

## Analyze
Zero new issues. Pre-existing geolocator/flutter_secure_storage/path_provider/image_picker/url_launcher windows and linux plugin warnings present (known noise, not new).

## What was done

### Part 1 — Capture provider name
- Added `firstName`/`lastName` (`String?`) to `UserProfile`: constructor, `fromJson`, `toJson`.
- Extended `AuthService.syncProfile` and `AuthStateNotifier.syncProfile` with `firstName`/`lastName` optional params included in the POST body when non-null.
- Updated the `_socialLogin` call site to pass `pu.givenName`/`pu.familyName` from the auth0_flutter `UserProfile`.

### Part 2 — Profile completion prompt
- Created `NameCompletionDialog` (stateful dialog: First + Last name TextFields, Save/Skip actions). Save calls `updateProfile({'firstName': ..., 'lastName': ...})` with only non-empty values; Skip dismisses. Empty Save also dismisses without calling the API.
- Triggered from `DiscoverScreen` (practitioner home) and `OwnerDashboardScreen` (owner home) via `addPostFrameCallback` with a `_promptShown` bool guard to prevent repeat display.

### Tests added
- `test/user_profile_test.dart`: 3 new cases for `firstName`/`lastName` parsing and serialization.
- `test/features/profile/name_completion_dialog_test.dart`: 5 widget tests covering render, Skip, Save with both fields, Save with one field, and Save with empty fields.

## Concerns
None.

---

## Post-Completion Fix — Report Relocatable (2026-08-01)

**Finding:** Report was written to task working directory. Now copied to `.superpowers/mobile-name-capture-report.md` for session handoff archive.

**Fix applied:**
- Copied report to `.superpowers/mobile-name-capture-report.md` (repo root `.superpowers/`)
- Committed with `-f` (forced past `.gitignore` policy): `cb2b1ce docs: mobile name capture implementation report`
- Verified: `flutter test` (all 386 pass), `flutter analyze` (zero new issues)

**Status:** DONE

---

## Code Review Fix — ConsumerStatefulWidget + Guard Tests (2026-08-01)

**Commit:** `4d480c1 fix(mobile): use ConsumerStatefulWidget for dialog, add guard tests, style tokens`

### Findings addressed

**Finding 1 (Important) — Stale `WidgetRef` captured in `_NameCompletionDialog`**
- Converted `_NameCompletionDialog` from `StatefulWidget` to `ConsumerStatefulWidget` and `_NameCompletionDialogState` to `ConsumerState<_NameCompletionDialog>`.
- Removed `WidgetRef ref` field and constructor parameter from the dialog.
- `ref` now accessed via `this.ref` on `ConsumerState` — the correct Riverpod pattern.
- `showNameCompletionDialog` signature simplified: `(BuildContext context, WidgetRef ref)` → `(BuildContext context)`. Dialog owns its own ref.
- Call sites updated: `discover_screen.dart`, `owner_dashboard_screen.dart`.
- Test `name_completion_dialog_test.dart`: removed `Consumer` wrapper around the trigger button; updated call to `showNameCompletionDialog(context)`. `ProviderScope.overrides` on `authStateProvider` still routes correctly into the dialog's `ConsumerState`.

**Finding 2 (Important) — Missing screen-level guard test**
- Created `test/features/discover_name_prompt_guard_test.dart` with 2 widget tests:
  - Asserts dialog is NOT shown when `displayName` is non-blank (`_AuthWithName`).
  - Asserts dialog IS shown when `displayName` is blank (`_AuthBlankName`).

**Finding 3 (Minor) — Missing comment on second `addPostFrameCallback`**
- Added `// Prompt users who have no display name yet to enter their first/last name.` comment above the name-prompt callback in `discover_screen.dart initState`.

**Finding 4 (Minor) — Hardcoded `borderRadius: BorderRadius.circular(12)`**
- Fixed as part of Finding 1 rewrite: now uses `BorderRadius.circular(t.cardRadius)`.

### Results
- `flutter test`: **388 tests passed** (386 prior + 2 new guard tests)
- `flutter analyze`: **No issues found**

### Concerns
None.
