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
