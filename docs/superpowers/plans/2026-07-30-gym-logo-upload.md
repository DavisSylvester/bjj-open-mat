# Gym Logo Upload for Existing Gyms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let owners add a logo to an existing gym, and prompt them to when the gym has none.

**Architecture:** Extract the working logo picker out of the create-gym screen into a shared widget that owns its own upload state, embed it in the gym admin screen, then add a gated, dismissible banner on gym detail that points there. No backend work — `uploadLogo` and `update` already exist.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, image_picker, flutter_secure_storage.

**Spec:** `docs/superpowers/specs/2026-07-30-gym-logo-upload-design.md`

**Branch:** create `feature/gym-logo-upload` from `main`.

## Global Constraints

- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`). **Never add Co-Authored-By lines.**
- `flutter analyze` must be clean before every commit.
- `flutter test` must pass before every commit. Baseline is **272 passing**; each task should raise it, never lower it.
- **No backend changes.** Both endpoints already exist and are the only ones used.
- Run all commands from `apps/mobile`.
- **Gym-owner accounts only — NOT `deriveCanManageGym`.** Two independent guards both check the *account* role, not gym-level management:
  - Server: `requireOwner` throws unless `identity.role === "gym_owner"` (`apps/api/src/auth/auth.middleware.mts:50`).
  - Router: `if (!isOwner && loc.startsWith('/owner')) return '/';` where `isOwner` is `user.role == 'gym_owner'` (`lib/app/router.dart:73`, `auth_service.dart:174`).

  `deriveCanManageGym` is broader — it also returns true for admins and for roster `coach`/`owner` roles. Gating on it would show the banner to a coach who is then **silently bounced to Discover** by the router and 403'd by the API. The banner must therefore require `user.isGymOwner` as well.
- **Image constraints must not change** during extraction: `maxWidth: 512`, `maxHeight: 512`, `imageQuality: 85`, uploaded as `'image/jpeg'`.
- Existing interfaces you will consume, verbatim:
  - `gymRepositoryProvider` → `uploadLogo(Uint8List bytes, String contentType) → Future<String>` (`lib/features/gyms/data/gym_repository.dart:26`)
  - `gymRepositoryProvider` → `update(String id, UpdateGymRequest req) → Future<Gym>` (`:22`)
  - `deriveCanManageGym(...)` and `deriveCanAccessForumGym(...)` (`lib/features/gyms/data/gym_permissions.dart`) — read the file for the exact parameter list before calling
  - `Gym.logoUrl` — `String?`

---

### Task 1: Extract a shared GymLogoPicker

Today the picker lives inside `add_gym_screen.dart` as a private `_pickLogo` method plus a
private `_PhotoDropzone` widget. The admin screen needs the same thing, so it moves to a
self-contained widget that owns its own state.

**Files:**
- Create: `apps/mobile/lib/features/gyms/widgets/gym_logo_picker.dart`
- Modify: `apps/mobile/lib/features/admin/screens/add_gym_screen.dart` — delete `_pickLogo`, `_logoBytes`, and `_PhotoDropzone`; embed the new widget. **Keep `_logoUrl` and `_uploadingLogo`** — `_submit` and the submit-enabled getter at `:68` still read them; they are now set from the widget's callbacks.
- Test: `apps/mobile/test/gyms/gym_logo_picker_test.dart` (create)

**Interfaces:**
- Consumes: `gymRepositoryProvider.uploadLogo`, `AppTokens`, `ApiException`
- Produces:
  - `class GymLogoPicker extends ConsumerStatefulWidget` with
    `({Key? key, required void Function(String url) onUploaded, void Function(bool uploading)? onUploadingChanged, void Function(String message)? onError, String? existingLogoUrl})`
  - Keys: `gym-logo-picker` on the tappable dropzone, `gym-logo-picker-uploading` on the in-progress indicator

- [ ] **Step 1: Write the failing test**

`ImagePicker` opens a native gallery, which a widget test cannot drive. The test therefore
covers what is testable without it: the widget renders its dropzone, surfaces an existing
logo, and reports upload state through its callbacks. The upload path itself is exercised
through a directly-invoked internal method rather than a simulated tap.

Create `apps/mobile/test/gyms/gym_logo_picker_test.dart`:

```dart
import 'dart:typed_data';

import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/widgets/gym_logo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGymRepository implements GymRepository {
  _FakeGymRepository({this.uploadResult, this.uploadError});

  final String? uploadResult;
  final Object? uploadError;
  int uploadCalls = 0;
  String? lastContentType;

  @override
  Future<String> uploadLogo(Uint8List bytes, String contentType) async {
    uploadCalls += 1;
    lastContentType = contentType;
    if (uploadError != null) throw uploadError!;
    return uploadResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required GymRepository repo,
  required void Function(String) onUploaded,
  String? existingLogoUrl,
  void Function(bool)? onUploadingChanged,
  void Function(String)? onError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gymRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(
          body: GymLogoPicker(
            onUploaded: onUploaded,
            onUploadingChanged: onUploadingChanged,
            onError: onError,
            existingLogoUrl: existingLogoUrl,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders a tappable dropzone', (tester) async {
    await _pump(tester, repo: _FakeGymRepository(uploadResult: 'x'), onUploaded: (_) {});
    expect(find.byKey(const Key('gym-logo-picker')), findsOneWidget);
  });

  testWidgets('a successful upload reports the url and clears uploading', (tester) async {
    final repo = _FakeGymRepository(uploadResult: 'https://cdn/logo.jpg');
    String? uploaded;
    final uploadingStates = <bool>[];
    await _pump(
      tester,
      repo: repo,
      onUploaded: (u) => uploaded = u,
      onUploadingChanged: uploadingStates.add,
    );

    final state = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await state.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pump();

    expect(uploaded, 'https://cdn/logo.jpg');
    expect(repo.uploadCalls, 1);
    expect(repo.lastContentType, 'image/jpeg');
    expect(uploadingStates, [true, false]);
  });

  testWidgets('a failed upload reports an error and stops uploading', (tester) async {
    final repo = _FakeGymRepository(uploadError: StateError('nope'));
    String? uploaded;
    String? error;
    final uploadingStates = <bool>[];
    await _pump(
      tester,
      repo: repo,
      onUploaded: (u) => uploaded = u,
      onUploadingChanged: uploadingStates.add,
      onError: (m) => error = m,
    );

    final state = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await state.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pump();

    expect(uploaded, isNull, reason: 'a failed upload must not report a url');
    expect(error, isNotNull);
    expect(uploadingStates, [true, false],
        reason: 'uploading must be cleared on failure or the parent stays disabled forever');
  });
}
```

If `GymRepository` is an abstract class with many members, `noSuchMethod` as written may
need `@override dynamic noSuchMethod(Invocation i) => throw UnimplementedError();` instead.
Read `gym_repository.dart` and make the fake satisfy the real interface — do not change the
interface to suit the fake.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/gym_logo_picker_test.dart`
Expected: FAIL — `gym_logo_picker.dart` does not exist.

- [ ] **Step 3: Create the shared widget**

Create `apps/mobile/lib/features/gyms/widgets/gym_logo_picker.dart`.

Move `_PhotoDropzone` from `add_gym_screen.dart` into this file verbatim (renaming it to a
private `_Dropzone` here), and move the `_pickLogo` body into the widget's state. The state
class must be **public** (`GymLogoPickerState`, no leading underscore) so tests can reach
`uploadBytes`.

Required shape:

```dart
class GymLogoPicker extends ConsumerStatefulWidget {
  final void Function(String url) onUploaded;
  final void Function(bool uploading)? onUploadingChanged;
  final void Function(String message)? onError;
  final String? existingLogoUrl;

  const GymLogoPicker({
    super.key,
    required this.onUploaded,
    this.onUploadingChanged,
    this.onError,
    this.existingLogoUrl,
  });

  @override
  GymLogoPickerState createState() => GymLogoPickerState();
}

class GymLogoPickerState extends ConsumerState<GymLogoPicker> {
  Uint8List? _bytes;
  bool _uploading = false;

  /// Opens the gallery, downscales, then uploads. Separated from [uploadBytes]
  /// so tests can exercise the upload path without a native picker.
  Future<void> pickAndUpload() async {
    if (_uploading) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    await uploadBytes(await file.readAsBytes());
  }

  /// Uploads already-picked bytes. Public so widget tests can drive it.
  Future<void> uploadBytes(Uint8List bytes) async {
    setState(() {
      _bytes = bytes;
      _uploading = true;
    });
    widget.onUploadingChanged?.call(true);
    try {
      final url = await ref.read(gymRepositoryProvider).uploadLogo(bytes, 'image/jpeg');
      if (!mounted) return;
      setState(() => _uploading = false);
      widget.onUploadingChanged?.call(false);
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _bytes = null;
      });
      widget.onUploadingChanged?.call(false);
      widget.onError?.call(friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _Dropzone(
      key: const Key('gym-logo-picker'),
      t: t,
      previewBytes: _bytes,
      uploading: _uploading,
      uploaded: _bytes != null && !_uploading,
      existingLogoUrl: widget.existingLogoUrl,
      onTap: pickAndUpload,
    );
  }
}
```

`_Dropzone` gains one parameter beyond what `_PhotoDropzone` had: `existingLogoUrl`. When
`previewBytes` is null and `existingLogoUrl` is non-empty, render that image (use
`CachedNetworkImage`, as `my_gyms_screen.dart:76` already does) so an existing logo is
visible rather than an empty dropzone. Otherwise keep its current rendering exactly.

Note the catch is `catch (e)` with `friendlyErrorMessage`, not `on ApiException`. The
original caught only `ApiException`, so a network failure escaped and left `_uploadingLogo`
stuck true — a permanently disabled save button. Widening it is a deliberate fix, not an
accidental change; say so in your report.

- [ ] **Step 4: Rewire add_gym_screen to use it**

In `apps/mobile/lib/features/admin/screens/add_gym_screen.dart`:

- Delete `_pickLogo`, the `_logoBytes` and `_uploadingLogo` fields, and the `_PhotoDropzone`
  class.
- Keep `_logoUrl` — `_submit` still sends it.
- Replace the `_PhotoDropzone(...)` call in `build` with:

```dart
                    GymLogoPicker(
                      onUploaded: (url) => setState(() => _logoUrl = url),
                      onUploadingChanged: (up) => setState(() => _uploadingLogo = up),
                      onError: (m) => setState(() => _error = m),
                    ),
```

`_uploadingLogo` is still referenced by the submit-enabled getter at `:68`, so keep that
field and set it from the callback. Remove any import that `flutter analyze` now reports as
unused — do not guess.

- [ ] **Step 5: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all pass (275 total).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/gyms/widgets/gym_logo_picker.dart apps/mobile/lib/features/admin/screens/add_gym_screen.dart apps/mobile/test/gyms/gym_logo_picker_test.dart
git commit -m "refactor(mobile): extract a shared gym logo picker

The gym admin screen needs the same picker the create screen has. Two
copies would drift on the image constraints, so extract one widget that
owns its own upload state. Also widens the catch so a network failure no
longer leaves the picker stuck uploading."
```

---

### Task 2: Logo upload on the gym admin screen

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/gym_admin_screen.dart`
- Test: `apps/mobile/test/gyms/gym_admin_logo_test.dart` (create)

**Interfaces:**
- Consumes: `GymLogoPicker` (Task 1), `gymRepositoryProvider.update`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gyms/gym_admin_logo_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/admin/screens/gym_admin_screen.dart').readAsStringSync();

  test('gym admin screen embeds the shared logo picker', () {
    expect(source, contains('GymLogoPicker'),
        reason: 'an existing gym has no other way to get a logo');
  });

  test('an uploaded logo is persisted through the update request', () {
    expect(source, contains("'logoUrl'"),
        reason: 'uploading without patching the gym would silently discard the logo');
  });

  test('save is blocked while a logo upload is in flight', () {
    expect(source, contains('_uploadingLogo'),
        reason: 'saving mid-upload persists a stale or empty logoUrl');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/gym_admin_logo_test.dart`
Expected: FAIL — none of those strings are present.

- [ ] **Step 3: Add logo state and the picker**

In `apps/mobile/lib/features/admin/screens/gym_admin_screen.dart`, add to
`_GymAdminScreenState` alongside `_saving` and `_error`:

```dart
  String? _logoUrl;
  bool _uploadingLogo = false;
```

Embed the picker in `build`, above the name field, passing the gym's current logo so it is
visible rather than showing an empty dropzone:

```dart
            GymLogoPicker(
              existingLogoUrl: gym.logoUrl,
              onUploaded: (url) => setState(() => _logoUrl = url),
              onUploadingChanged: (up) => setState(() => _uploadingLogo = up),
              onError: (m) => setState(() => _error = m),
            ),
```

Add the import: `import '../../gyms/widgets/gym_logo_picker.dart';`

- [ ] **Step 4: Persist it and guard the save**

In `_save`, add the guard as the second line and include the logo in the patch:

```dart
  Future<void> _save(Gym gym) async {
    if (_saving || _uploadingLogo) return;
    final changed = <String, dynamic>{};
    final name = _nameCtrl.text.trim();
    final address = _addrCtrl.text.trim();
    if (name.isNotEmpty && name != gym.name) changed['name'] = name;
    if (address.isNotEmpty && address != gym.address) changed['address'] = address;
    if (_logoUrl != null && _logoUrl != gym.logoUrl) changed['logoUrl'] = _logoUrl;
    if (changed.isEmpty) return;
```

The `_logoUrl != null` check matters: leaving the logo untouched must not clear an existing
one. Leave the rest of `_save` — the `update` call and both `invalidate`s — unchanged.

- [ ] **Step 5: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all pass (278 total).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/admin/screens/gym_admin_screen.dart apps/mobile/test/gyms/gym_admin_logo_test.dart
git commit -m "feat(mobile): let owners add a logo to an existing gym

Logo upload existed only at creation, so the 800+ gyms already in the
database had no path to one."
```

---

### Task 3: Encouragement banner on gym detail

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/logo_banner_dismissal.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`
- Test: `apps/mobile/test/gyms/logo_banner_test.dart` (create)

**Interfaces:**
- Consumes: `authStateProvider` → `user?.isGymOwner` (`lib/core/auth/auth_service.dart:174`), `Gym.logoUrl`
- Produces:
  - `bool shouldShowLogoBanner({required String? logoUrl, required bool isGymOwner, required bool dismissed})`
  - `logoBannerDismissedProvider` — `FutureProvider.family<bool, String>` keyed by gym id
  - `Future<void> dismissLogoBanner(String gymId)`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gyms/logo_banner_test.dart`:

```dart
import 'package:bjj_open_mat/features/gyms/data/logo_banner_dismissal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowLogoBanner', () {
    test('shows when a gym-owner account views a gym with no logo', () {
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: true, dismissed: false), isTrue);
      expect(shouldShowLogoBanner(logoUrl: '', isGymOwner: true, dismissed: false), isTrue);
    });

    test('hidden once the gym has a logo', () {
      expect(
        shouldShowLogoBanner(logoUrl: 'https://cdn/logo.jpg', isGymOwner: true, dismissed: false),
        isFalse,
      );
    });

    test('hidden for a non gym-owner account', () {
      // Both the router guard and the server's requireOwner check the ACCOUNT
      // role. A coach passes deriveCanManageGym but would be bounced to
      // Discover and 403'd, so the banner must not appear for them.
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: false, dismissed: false), isFalse);
    });

    test('hidden once dismissed', () {
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: true, dismissed: true), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/logo_banner_test.dart`
Expected: FAIL — `logo_banner_dismissal.dart` does not exist.

- [ ] **Step 3: Implement the predicate and dismissal storage**

Create `apps/mobile/lib/features/gyms/data/logo_banner_dismissal.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String _key(String gymId) => 'gym_logo_banner_dismissed_$gymId';

/// Whether to prompt for a gym logo.
///
/// Gated on [isGymOwner] — the ACCOUNT role — not on `deriveCanManageGym`.
/// Both guards this prompt has to satisfy check the account role: the server's
/// `requireOwner` rejects anything but `gym_owner`, and the router redirects
/// non-owners away from `/owner/**`. A coach passes `deriveCanManageGym` but
/// would be bounced to Discover and then 403'd, so a broader gate would offer
/// an action that cannot complete.
bool shouldShowLogoBanner({
  required String? logoUrl,
  required bool isGymOwner,
  required bool dismissed,
}) {
  if (!isGymOwner) return false;
  if (dismissed) return false;
  return logoUrl == null || logoUrl.isEmpty;
}

/// Whether this gym's banner has been dismissed. Per gym, so dismissing one
/// does not silence the prompt for another. A storage failure resolves to
/// false — showing the banner is a better failure than silently suppressing it.
final logoBannerDismissedProvider = FutureProvider.family<bool, String>((ref, gymId) async {
  try {
    return await const FlutterSecureStorage().read(key: _key(gymId)) != null;
  } catch (_) {
    return false;
  }
});

Future<void> dismissLogoBanner(String gymId) async {
  try {
    await const FlutterSecureStorage().write(key: _key(gymId), value: 'true');
  } catch (_) {
    // A failed dismissal just means the banner returns; never surface it.
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/mobile && flutter test test/gyms/logo_banner_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Render the banner on gym detail**

In `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`, inside the same build
that already computes `canManage`, watch the dismissal and render the banner directly above
the Open Mats row:

```dart
            if (shouldShowLogoBanner(
              logoUrl: gym.logoUrl,
              isGymOwner: ref.watch(authStateProvider).user?.isGymOwner ?? false,
              dismissed: ref.watch(logoBannerDismissedProvider(gym.id)).value ?? false,
            )) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('gym-logo-banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Add your gym's logo",
                              style: t.labelStyle.copyWith(fontWeight: FontWeight.w700, color: t.text)),
                          const SizedBox(height: 4),
                          Text('Gyms with a logo stand out in search and on open mats.',
                              style: t.miniStyle.copyWith(color: t.muted)),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('gym-logo-banner-add'),
                      onPressed: () => context.push('/owner/gyms/${gym.id}'),
                      child: const Text('Add'),
                    ),
                    IconButton(
                      key: const Key('gym-logo-banner-dismiss'),
                      icon: Icon(Icons.close, size: 18, color: t.muted),
                      onPressed: () async {
                        await dismissLogoBanner(gym.id);
                        ref.invalidate(logoBannerDismissedProvider(gym.id));
                      },
                    ),
                  ],
                ),
              ),
            ],
```

Add the import: `import '../data/logo_banner_dismissal.dart';`

The admin route is `/owner/gyms/:id` (`lib/app/router.dart:254-256`), nested under
`/owner/gyms` inside the **owner shell** — not a `/gym/:id` sub-route. It is verified; do
not substitute a different path.

- [ ] **Step 6: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all pass (282 total).

- [ ] **Step 7: Verify on the simulator**

```bash
open -a Simulator
cd apps/mobile && flutter run -d "iPhone 17 Pro" --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
```

Report exactly what you saw. The signed-in test account may not manage any gym, in which
case the banner correctly never appears — **say that plainly rather than claiming a check
you could not perform.** If you can reach a gym you manage, confirm: the banner appears
only when the gym has no logo, "Add" opens the admin screen, the picker uploads, and the
banner is gone after saving.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/gyms/data/logo_banner_dismissal.dart apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart apps/mobile/test/gyms/logo_banner_test.dart
git commit -m "feat(mobile): prompt gym managers to add a missing logo

Shown only to users who can manage the gym, since the logo endpoint is
owner-only server side. Dismissible per gym."
```

---

## Notes for the implementer

- Tasks are sequential: Task 2 needs Task 1's widget, Task 3 needs Task 2's destination to
  exist. A banner pointing at a screen that cannot upload is worse than no banner.
- **Do not open logo upload to members.** The endpoint is `requireOwner: true`, and
  relaxing it is a product and abuse decision recorded as spec follow-up, not part of this
  work.
- **Do not change the image constraints** (512×512, quality 85, `image/jpeg`). The
  extraction preserves them exactly; changing them silently alters what every gym uploads.
