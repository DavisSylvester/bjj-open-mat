# Gym Open Mats Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the gym detail screen's inline Open Mats list onto a dedicated screen, reachable from a row on gym detail and a tile on the My Gym hub.

**Architecture:** One new screen consuming the existing `gymSessionsProvider`, then two small navigation changes pointing at it. No backend work — the provider and endpoint already exist.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, lucide_icons.

**Spec:** `docs/superpowers/specs/2026-07-30-gym-open-mats-screen-design.md`

**Branch:** work from `main` (all prior branches merged; `main` is at the merge of `feature/gym-open-mats`)

## Global Constraints

- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`). **Never add Co-Authored-By lines.**
- `flutter analyze` must be clean before every commit.
- `flutter test` must pass before every commit. Baseline is **262 passing**; each task should raise it, never lower it.
- **No backend changes.** `gymSessionsProvider` already exists and is the only data source for this feature.
- Run all commands from `apps/mobile`.
- Existing interfaces you will consume, verbatim:
  - `gymSessionsProvider` — `FutureProvider.family<List<OpenMat>, String>` keyed by gym id (`lib/features/gyms/data/gym_sessions_provider.dart:30`)
  - `sessionRowFromOpenMat(OpenMat m)` → `SessionRowData` (`gym_sessions_provider.dart:17`)
  - `SessionRow({required SessionRowData session, VoidCallback? onTap})` (`lib/shared/widgets/session_row.dart`)
  - `ErrorState({required String message, VoidCallback? onRetry})` (`lib/shared/widgets/error_state.dart`)
  - `friendlyErrorMessage(Object error)` → `String` (`lib/core/api/friendly_error.dart`)
- The My Gym hub's quick actions render in a `GridView.count(crossAxisCount: 2)`. A fifth tile makes the grid 2 + 2 + 1. This is expected; do not restructure the grid.

---

### Task 1: Gym Open Mats screen and route

**Files:**
- Create: `apps/mobile/lib/features/gyms/screens/gym_open_mats_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` — add a nested route under `gym/:id`
- Test: `apps/mobile/test/gyms/gym_open_mats_screen_test.dart` (create)

**Interfaces:**
- Consumes: `gymSessionsProvider`, `sessionRowFromOpenMat`, `SessionRow`, `ErrorState`, `friendlyErrorMessage`
- Produces: `class GymOpenMatsScreen extends ConsumerWidget` with a required `String gymId`; route `/gym/:id/open-mats`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gyms/gym_open_mats_screen_test.dart`:

```dart
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_sessions_provider.dart';
import 'package:bjj_open_mat/features/gyms/screens/gym_open_mats_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kGymId = 'g1';

OpenMat _mat({required String id, required String title}) => OpenMat(
      id: id,
      gymId: _kGymId,
      title: title,
      dayOfWeek: 'sunday',
      startTime: '14:00',
      endTime: '16:00',
      skillLevel: 'all',
      giType: 'nogi',
      status: 'scheduled',
      verified: true,
    );

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<OpenMat>> Function() sessions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gymSessionsProvider(_kGymId).overrideWith((ref) => sessions()),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const GymOpenMatsScreen(gymId: _kGymId),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders a row per open mat', (tester) async {
    await _pump(tester, sessions: () async => [
          _mat(id: 'm1', title: 'Sunday No-Gi'),
          _mat(id: 'm2', title: 'Friday Rolls'),
        ]);
    expect(find.text('Sunday No-Gi'), findsOneWidget);
    expect(find.text('Friday Rolls'), findsOneWidget);
    expect(find.byKey(const Key('gym-open-mats-empty')), findsNothing);
  });

  testWidgets('empty state offers a way to post one', (tester) async {
    await _pump(tester, sessions: () async => []);
    expect(find.byKey(const Key('gym-open-mats-empty')), findsOneWidget);
    expect(find.text('No open mats posted yet.'), findsOneWidget);
    expect(find.byKey(const Key('gym-open-mats-post-button')), findsOneWidget);
  });

  testWidgets('error state offers a retry rather than a blank screen', (tester) async {
    await _pump(tester, sessions: () async => throw StateError('boom'));
    await tester.pump();
    expect(find.byKey(const Key('gym-open-mats-empty')), findsNothing);
    expect(find.textContaining('Something went wrong'), findsWidgets);
  });
}
```

Note on the error test: Riverpod 3 retries a thrown `Exception` but not an `Error`
subtype, so `StateError` is used deliberately — a plain `Exception` would leave the
widget stuck in `loading` and the test would pass for the wrong reason. This exact trap
was hit earlier in this project.

If `OpenMat`'s constructor requires fields beyond those listed, read
`lib/features/open_mats/models/open_mat.dart` and supply them; do not remove fields from
the fixture to make it compile.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/gym_open_mats_screen_test.dart`
Expected: FAIL — `gym_open_mats_screen.dart` does not exist.

- [ ] **Step 3: Implement the screen**

Create `apps/mobile/lib/features/gyms/screens/gym_open_mats_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api/friendly_error.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/session_row.dart';
import '../data/gym_sessions_provider.dart';

/// Every open mat posted by one gym.
///
/// Previously an inline section on the gym detail screen. Open mats are the
/// app's core concept, so they get their own screen rather than sitting at the
/// bottom of a long scroll.
class GymOpenMatsScreen extends ConsumerWidget {
  final String gymId;

  const GymOpenMatsScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final sessionsAsync = ref.watch(gymSessionsProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        // Guarded: this screen is reachable from the gym page and from the My
        // Gym hub, so a bare pop() would dead-end when there is no history.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/gym/$gymId'),
        ),
        title: Text('Open Mats', style: t.h2Style),
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: friendlyErrorMessage(e),
            onRetry: () => ref.invalidate(gymSessionsProvider(gymId)),
          ),
          data: (mats) => mats.isEmpty
              ? _EmptyState(t: t)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mats.length,
                  itemBuilder: (context, i) {
                    final m = mats[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SessionRow(
                        session: sessionRowFromOpenMat(m),
                        onTap: () => context.push('/open-mat/${m.id}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppTokens t;
  const _EmptyState({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('gym-open-mats-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarOff, size: 40, color: t.faint),
            const SizedBox(height: 16),
            Text(
              'No open mats posted yet.',
              textAlign: TextAlign.center,
              style: t.bodyStyle.copyWith(color: t.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('gym-open-mats-post-button'),
              onPressed: () => context.push('/add-session'),
              child: const Text('Post an open mat'),
            ),
          ],
        ),
      ),
    );
  }
}
```

If `LucideIcons.calendarOff` does not resolve, run
`grep -o 'calendarOff\|calendarX\|calendar' ~/.pub-cache/hosted/pub.dev/lucide_icons-*/lib/lucide_icons.dart | sort -u`
and use the closest match, saying which you chose in your report.

- [ ] **Step 4: Add the route**

In `apps/mobile/lib/app/router.dart`, inside the `gym/:id` route's `routes:` list,
immediately **before** the existing `path: 'roster'` route:

```dart
                    GoRoute(
                      path: 'open-mats',
                      builder: (context, state) =>
                          GymOpenMatsScreen(gymId: state.pathParameters['id']!),
                    ),
```

Add the import: `import '../features/gyms/screens/gym_open_mats_screen.dart';`

- [ ] **Step 5: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all pass (265 total).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/gyms/screens/gym_open_mats_screen.dart apps/mobile/lib/app/router.dart apps/mobile/test/gyms/gym_open_mats_screen_test.dart
git commit -m "feat(mobile): add a dedicated gym open mats screen

Open mats are the app's core concept but sat inline at the bottom of the
gym detail scroll. Give them their own screen, with an empty state that
routes into posting one."
```

---

### Task 2: Replace the inline section on gym detail

**Files:**
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` — delete the inline Open Mats section, add a link row
- Test: `apps/mobile/test/gyms/gym_detail_open_mats_row_test.dart` (create)

**Interfaces:**
- Consumes: route `/gym/:id/open-mats` (Task 1)
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Write the failing test**

`GymDetailScreen` needs auth, gym data, roster, and sessions to render, so a full widget
pump is disproportionate for a navigation row. Assert the wiring at the source level —
this catches the actual defect (the section left in place, or a row pointing nowhere).
This mirrors the approach already used in `test/features/profile_favorites_row_test.dart`.

Create `apps/mobile/test/gyms/gym_detail_open_mats_row_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/gyms/screens/gym_detail_screen.dart').readAsStringSync();

  test('gym detail links to the open mats screen', () {
    expect(source, contains("context.push('/gym/\${gym.id}/open-mats')"),
        reason: 'the Open Mats row must route to the dedicated screen');
    expect(source, contains("Text('Open Mats'"));
  });

  test('the inline open mats list is gone', () {
    expect(source, isNot(contains('sessionRowFromOpenMat')),
        reason: 'the list moved to GymOpenMatsScreen; rendering it here too would duplicate it');
    expect(source, isNot(contains('No open mats posted yet.')),
        reason: 'the empty state belongs to the open mats screen now');
  });

  test('the open mats route it points at still exists', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains("path: 'open-mats'"));
    expect(router, contains('GymOpenMatsScreen'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/gym_detail_open_mats_row_test.dart`
Expected: FAIL — the row does not exist and the inline section is still present.

- [ ] **Step 3: Delete the inline section**

In `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`, delete the block that
currently renders the inline list — the `Text('Open Mats', ...)` heading, the
`sessionsAsync.when(...)` that follows it, and the `SizedBox` immediately preceding the
heading. It currently sits between the Instructor feedback link and the `About` section.

Then remove whatever becomes unused: the `sessionsAsync` local, its `ref.watch(...)` of
`gymSessionsProvider`, and any import of `SessionRow` or `sessionRowFromOpenMat` that no
longer has a reference. Let `flutter analyze` tell you which imports are now unused —
do not guess.

- [ ] **Step 4: Add the link row**

In the same file, add this row **directly above** the existing Members row (the one
pushing `/roster`), matching that row's structure exactly:

```dart
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/gym/${gym.id}/open-mats'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_available_outlined, size: 16, color: t.text),
                  const SizedBox(width: 8),
                  Text('Open Mats', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
```

- [ ] **Step 5: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean (including no unused-import warnings); all pass (268 total).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart apps/mobile/test/gyms/gym_detail_open_mats_row_test.dart
git commit -m "refactor(mobile): move gym open mats behind a link row

The inline list sat below five other sections. Promote it to the top of
the link stack and let the dedicated screen own the list, its empty
state, and its error handling."
```

---

### Task 3: Open Mats tile on the My Gym hub

**Files:**
- Modify: `apps/mobile/lib/features/mygym/screens/my_gym_screen.dart` — add a fifth quick action
- Test: `apps/mobile/test/mygym/my_gym_screen_test.dart` — add coverage for the new tile

**Interfaces:**
- Consumes: route `/gym/:id/open-mats` (Task 1)
- Produces: tile keyed `mygym-action-open-mats`

- [ ] **Step 1: Write the failing test**

Append to `apps/mobile/test/mygym/my_gym_screen_test.dart`, inside the existing `main()`.
The file already has a private helper with this signature (`:25`), which these tests
reuse:

```dart
Future<void> _pump(
  WidgetTester tester, {
  required String? homeGymId,
  String? currentUserId,
  List<RosterMember> roster = const [],
}) async
```

A non-member is `currentUserId: 'stranger', roster: const []` — the shape the existing
gating tests already use at `:67`.

```dart
  testWidgets('open mats tile is shown even to a non-member', (tester) async {
    // Open mats have no membership requirement server-side, unlike Forum and
    // Feedback. Gating this tile would repeat the 403 defect those two had.
    await _pump(tester, homeGymId: 'g1', currentUserId: 'stranger', roster: const []);
    expect(find.byKey(const Key('mygym-action-open-mats')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-forum')), findsNothing);
    expect(find.byKey(const Key('mygym-action-instructor-feedback')), findsNothing);
  });

  testWidgets('open mats tile sits alongside the other ungated tiles', (tester) async {
    await _pump(tester, homeGymId: 'g1', currentUserId: 'stranger', roster: const []);
    expect(find.byKey(const Key('mygym-action-open-mats')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-schedule')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-roster')), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/mygym/my_gym_screen_test.dart`
Expected: FAIL — no tile keyed `mygym-action-open-mats`.

- [ ] **Step 3: Add the tile**

In `apps/mobile/lib/features/mygym/screens/my_gym_screen.dart`, in the `actions` list
inside `_QuickActions.build`, add as the **first** entry, before the Schedule action:

```dart
      _QuickAction(
        key: 'mygym-action-open-mats',
        icon: LucideIcons.calendarDays,
        label: 'Open Mats',
        path: '/gym/$gymId/open-mats',
      ),
```

It is **not** wrapped in a gate. Schedule and Roster are likewise ungated; only Forum
(`if (canAccessForum)`) and Feedback (`if (canManage)`) are, because only those two
endpoints enforce membership or management server-side.

If `LucideIcons.calendarDays` does not resolve, run
`grep -o 'calendarDays\|calendarClock\|calendar' ~/.pub-cache/hosted/pub.dev/lucide_icons-*/lib/lucide_icons.dart | sort -u`
and pick the closest, saying which you chose in your report. Do not reuse
`LucideIcons.calendar` — that is already the Schedule tile's icon, and two identical
icons in one grid is confusing.

- [ ] **Step 4: Run tests and analyze**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: analyze clean; all pass (270 total).

- [ ] **Step 5: Verify the grid on the simulator**

```bash
open -a Simulator
cd apps/mobile && flutter run -d "iPhone 17 Pro" --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
```

The quick actions render in `GridView.count(crossAxisCount: 2)`, so five tiles lay out
as 2 + 2 + 1 with the last tile alone on its row. **Report what it actually looks like**
— whether the lone trailing tile reads as intentional or broken. Do not restructure the
grid; if it looks wrong, say so and stop, because that is a design decision for the
human, not an implementation choice.

Also confirm by eye: the Open Mats tile opens the new screen, gym detail's Open Mats row
opens the same screen, and the inline list is gone from gym detail.

If you cannot launch the simulator, say so explicitly rather than skipping silently.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/mygym/screens/my_gym_screen.dart apps/mobile/test/mygym/my_gym_screen_test.dart
git commit -m "feat(mobile): add an Open Mats tile to the My Gym hub

Ungated: the open-mats endpoint has no membership requirement, unlike
Forum and Feedback, so every user can reach it."
```

---

## Notes for the implementer

- Tasks 2 and 3 both route to the screen built in Task 1, so Task 1 must come first.
  Tasks 2 and 3 are independent of each other.
- The spec records one accepted rough edge: the empty state's "Post an open mat" button
  opens `/add-session` **without the gym prefilled**, because `CreateSessionScreen` takes
  no constructor arguments. Do not try to fix that here — it is logged as follow-up.
- Do not gate the hub's Open Mats tile. That is deliberate and explained in the spec.
