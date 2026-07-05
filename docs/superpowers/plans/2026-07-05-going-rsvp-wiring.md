# "Going" / RSVP Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the already-built RSVP backend end-to-end: an "I'm Going" toggle per session date on the open-mat detail, a public count + attendee names (tap → public profile), and an owner "Expected" list on the attendance screen.

**Architecture:** The API is already complete — `POST /:id/rsvp` (`{sessionDate}`), `DELETE /:id/rsvp?sessionDate=`, and `GET /:id/attendees?sessionDate=` (returns name/belt/avatar). This plan is Flutter-only: a `Attendee` model, a `RsvpRepository` + Riverpod providers, an `OpenMat.nextSessionDate()` helper (one-off → `specificDate`; recurring → next weekday occurrence), a reusable `GoingSection` widget on the detail screen, and an "Expected" section on the owner attendance screen.

**Tech Stack:** Flutter/Dart, Riverpod, `dio`.

---

### Task 1: Add RSVP/attendee endpoint constants

**Files:**
- Modify: `apps/mobile/lib/core/api/endpoints.dart:24-25`

- [ ] **Step 1: Add the constants**

In `apps/mobile/lib/core/api/endpoints.dart`, add after `openMatCheckins`:

```dart
  static String openMatRsvp(String id) => '/api/v1/open-mats/$id/rsvp';
  static String openMatAttendees(String id) => '/api/v1/open-mats/$id/attendees';
```

- [ ] **Step 2: Verify**

Run: `grep -c "openMatRsvp\|openMatAttendees" apps/mobile/lib/core/api/endpoints.dart`
Expected: `2`

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/core/api/endpoints.dart
git commit -m "feat(mobile): add rsvp/attendees endpoint constants"
```

---

### Task 2: Add the `Attendee` model

**Files:**
- Create: `apps/mobile/lib/features/open_mats/models/attendee.dart`
- Test: `apps/mobile/test/attendee_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/attendee_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/attendee.dart';

void main() {
  test('Attendee.fromJson parses fields', () {
    final a = Attendee.fromJson({
      'userId': 'u1',
      'name': 'Alex',
      'beltRank': 'blue',
      'avatarUrl': 'https://x/y.png',
    });
    expect(a.userId, 'u1');
    expect(a.name, 'Alex');
    expect(a.beltRank, 'blue');
    expect(a.avatarUrl, 'https://x/y.png');
  });

  test('Attendee.fromJson tolerates missing optional fields', () {
    final a = Attendee.fromJson({'userId': 'u2', 'name': 'Sam'});
    expect(a.beltRank, 'white');
    expect(a.avatarUrl, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/attendee_model_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Create the model**

Create `apps/mobile/lib/features/open_mats/models/attendee.dart`:

```dart
class Attendee {
  final String userId;
  final String name;
  final String beltRank;
  final String? avatarUrl;

  const Attendee({
    required this.userId,
    required this.name,
    this.beltRank = 'white',
    this.avatarUrl,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        beltRank: json['beltRank'] as String? ?? 'white',
        avatarUrl: json['avatarUrl'] as String?,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/attendee_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/open_mats/models/attendee.dart apps/mobile/test/attendee_model_test.dart
git commit -m "feat(mobile): add Attendee model"
```

---

### Task 3: Add `OpenMat.nextSessionDate()`

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/models/open_mat.dart` (add methods before the closing `}`)
- Test: `apps/mobile/test/open_mat_session_date_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/open_mat_session_date_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

OpenMat _mat({String? specificDate, int? dayOfWeek}) => OpenMat(
      id: 'm1', gymId: 'g1', title: 't',
      startTime: '18:00', endTime: '20:00',
      specificDate: specificDate, dayOfWeek: dayOfWeek,
    );

void main() {
  test('one-off session returns the specific date (date part only)', () {
    final m = _mat(specificDate: '2026-08-01T00:00:00.000Z');
    expect(m.nextSessionDate(from: DateTime(2026, 7, 1)), '2026-08-01');
  });

  test('recurring session returns the next matching weekday', () {
    // dayOfWeek 3 == Wednesday (0=Sun..6=Sat)
    final m = _mat(dayOfWeek: 3);
    final result = m.nextSessionDate(from: DateTime(2026, 7, 6)); // a Monday
    final parsed = DateTime.parse(result);
    expect(parsed.weekday, DateTime.wednesday);
    expect(parsed.isBefore(DateTime(2026, 7, 6)), false);
  });

  test('returns YYYY-MM-DD format', () {
    final m = _mat(dayOfWeek: 0);
    expect(m.nextSessionDate(from: DateTime(2026, 7, 6)).length, 10);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/open_mat_session_date_test.dart`
Expected: FAIL — `nextSessionDate` undefined.

- [ ] **Step 3: Implement the methods**

In `apps/mobile/lib/features/open_mats/models/open_mat.dart`, add before the final closing `}` of the `OpenMat` class:

```dart
  /// The concrete date this session's "going" list is keyed by:
  /// one-off sessions use [specificDate]; recurring sessions use the next
  /// occurrence of [dayOfWeek] (0=Sun..6=Sat) on/after [from] (defaults now).
  String nextSessionDate({DateTime? from}) {
    if (specificDate != null && specificDate!.isNotEmpty) {
      return specificDate!.split('T').first;
    }
    final base = from ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    if (dayOfWeek == null) return _fmtDate(today);
    final targetDart = dayOfWeek == 0 ? 7 : dayOfWeek!; // Dart: Mon=1..Sun=7
    var d = today;
    for (var i = 0; i < 7; i++) {
      if (d.weekday == targetDart) return _fmtDate(d);
      d = d.add(const Duration(days: 1));
    }
    return _fmtDate(today);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/open_mat_session_date_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/open_mats/models/open_mat.dart apps/mobile/test/open_mat_session_date_test.dart
git commit -m "feat(mobile): add OpenMat.nextSessionDate helper"
```

---

### Task 4: Add the RSVP repository + providers

**Files:**
- Create: `apps/mobile/lib/features/open_mats/data/rsvp_repository.dart`
- Test: `apps/mobile/test/going_query_test.dart`

- [ ] **Step 1: Write the failing test** (covers the family key equality, which caching relies on)

Create `apps/mobile/test/going_query_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/data/rsvp_repository.dart';

void main() {
  test('GoingQuery value equality + hashCode', () {
    const a = GoingQuery('m1', '2026-08-01');
    const b = GoingQuery('m1', '2026-08-01');
    const c = GoingQuery('m1', '2026-08-02');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/going_query_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Create the repository + providers**

Create `apps/mobile/lib/features/open_mats/data/rsvp_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/attendee.dart';

class GoingQuery {
  final String openMatId;
  final String sessionDate;
  const GoingQuery(this.openMatId, this.sessionDate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoingQuery && openMatId == other.openMatId && sessionDate == other.sessionDate;

  @override
  int get hashCode => Object.hash(openMatId, sessionDate);
}

class RsvpRepository {
  final Dio _dio;
  RsvpRepository(this._dio);

  Future<int> rsvp(String id, String sessionDate) async {
    try {
      final res = await _dio.post(Endpoints.openMatRsvp(id), data: {'sessionDate': sessionDate});
      return (unwrapData(res.data as Map<String, dynamic>)['attendeeCount'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<int> cancel(String id, String sessionDate) async {
    try {
      final res = await _dio.delete(Endpoints.openMatRsvp(id), queryParameters: {'sessionDate': sessionDate});
      return (unwrapData(res.data as Map<String, dynamic>)['attendeeCount'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Attendee>> attendees(String id, String sessionDate) async {
    try {
      final res = await _dio.get(Endpoints.openMatAttendees(id), queryParameters: {'sessionDate': sessionDate});
      return unwrapList(res.data as Map<String, dynamic>).items.map(Attendee.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final rsvpRepositoryProvider = Provider<RsvpRepository>((ref) {
  return RsvpRepository(ref.read(apiClientProvider).dio);
});

final attendeesProvider = FutureProvider.family<List<Attendee>, GoingQuery>((ref, q) {
  return ref.read(rsvpRepositoryProvider).attendees(q.openMatId, q.sessionDate);
});
```

> This mirrors `session_repository.dart`: `unwrapData` / `unwrapList` from `core/data/api_envelope.dart`, `ApiException.fromDio`, and `apiClientProvider.dio`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/going_query_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/open_mats/data/rsvp_repository.dart apps/mobile/test/going_query_test.dart
git commit -m "feat(mobile): rsvp repository and attendees providers"
```

---

### Task 5: Build the reusable `GoingSection` widget

**Files:**
- Create: `apps/mobile/lib/features/open_mats/widgets/going_section.dart`

- [ ] **Step 1: Create the widget**

Create `apps/mobile/lib/features/open_mats/widgets/going_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/rsvp_repository.dart';
import '../models/open_mat.dart';

/// "Going" (RSVP) control + public attendee list for one session date.
class GoingSection extends ConsumerStatefulWidget {
  final OpenMat mat;
  final AppTokens t;
  const GoingSection({super.key, required this.mat, required this.t});

  @override
  ConsumerState<GoingSection> createState() => _GoingSectionState();
}

class _GoingSectionState extends ConsumerState<GoingSection> {
  late final String _sessionDate = widget.mat.nextSessionDate();
  bool _busy = false;

  GoingQuery get _query => GoingQuery(widget.mat.id, _sessionDate);

  Future<void> _toggle(bool currentlyGoing) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(rsvpRepositoryProvider);
    try {
      if (currentlyGoing) {
        await repo.cancel(widget.mat.id, _sessionDate);
      } else {
        HapticFeedback.mediumImpact();
        await repo.rsvp(widget.mat.id, _sessionDate);
      }
      ref.invalidate(attendeesProvider(_query));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update RSVP")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final myId = ref.watch(authStateProvider).user?.id;
    final async = ref.watch(attendeesProvider(_query));
    final attendees = async.asData?.value ?? const [];
    final amGoing = myId != null && attendees.any((a) => a.userId == myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(LucideIcons.users, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Text('Going', style: t.h2Style.copyWith(fontSize: 14)),
          const Spacer(),
          Text('${attendees.length}', style: t.numStyle.copyWith(fontSize: 16, color: t.primary)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _toggle(amGoing),
            icon: Icon(amGoing ? LucideIcons.check : LucideIcons.plus, size: 18),
            label: Text(amGoing ? "You're going" : "I'm going"),
            style: OutlinedButton.styleFrom(
              foregroundColor: amGoing ? Colors.white : t.primary,
              backgroundColor: amGoing ? t.primary : Colors.transparent,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: t.primary),
            ),
          ),
        ),
        if (attendees.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attendees
                .map((a) => GestureDetector(
                      onTap: () => context.go('/user/${a.userId}'),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundColor: t.beltBg[a.beltRank] ?? t.muted,
                          child: Text(
                            a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        label: Text(a.name, style: t.miniStyle),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
```

> `t.beltBg` is the belt-color map used in `profile_screen.dart`; `authStateProvider` exposes `.user?.id`.

- [ ] **Step 2: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/open_mats/widgets/going_section.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/features/open_mats/widgets/going_section.dart
git commit -m "feat(mobile): reusable GoingSection RSVP widget"
```

---

### Task 6: Add `GoingSection` to the open-mat detail screen

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart`

- [ ] **Step 1: Add the import**

At the top of `open_mat_detail_screen.dart` add:

```dart
import '../widgets/going_section.dart';
```

- [ ] **Step 2: Insert into `_SportDetail`**

In `_SportDetail.build`, inside the `SingleChildScrollView`'s `Column` (`children: [ ... ]`), insert as the FIRST child (before the `if (mat.gymRating != null)` block):

```dart
                GoingSection(t: t, mat: mat),
                const SizedBox(height: 16),
```

- [ ] **Step 3: Insert into `_GlassDetail`**

In `_GlassDetail.build`, inside `SliverChildListDelegate([ ... ])`, insert immediately after the info-cards `Row(...)` (before the `if (mat.description != null ...)` block):

```dart
            const SizedBox(height: 20),
            GoingSection(t: t, mat: mat),
```

- [ ] **Step 4: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/open_mats/screens/open_mat_detail_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart
git commit -m "feat(mobile): show Going section on open-mat detail"
```

---

### Task 7: Add an "Expected" (RSVP) section to the owner attendance screen

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/attendance_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `attendance_screen.dart` add:

```dart
import '../../open_mats/data/rsvp_repository.dart';
```

- [ ] **Step 2: Insert an Expected section above the check-in list**

In `_AttendanceScreenState.build`, immediately after the date `Padding(...)` widget (the one showing `_selectedDate`) and before the `Expanded(...)`, insert:

```dart
          Consumer(builder: (context, watchRef, _) {
            final expected = watchRef.watch(attendeesProvider(GoingQuery(widget.sessionId, _selectedDate)));
            final list = expected.asData?.value ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(StitchTokens.md),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expected · ${list.length} going', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list
                      .map((a) => Chip(
                            avatar: CircleAvatar(
                              backgroundColor: BeltColors.fromRank(a.beltRank),
                              child: Text(
                                a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            label: Text(a.name),
                          ))
                      .toList(),
                ),
              ]),
            );
          }),
```

> `BeltColors.fromRank` and `StitchTokens` are already imported in this file (via `app/theme.dart`).

- [ ] **Step 3: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/admin/screens/attendance_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/lib/features/admin/screens/attendance_screen.dart
git commit -m "feat(mobile): show expected RSVP list on owner attendance"
```

---

### Task 8: Full verification

- [ ] **Step 1: Run the mobile test suite**

Run: `cd apps/mobile && flutter test`
Expected: all tests pass (including the new attendee/session-date/going-query tests).

- [ ] **Step 2: Analyze the whole app**

Run: `cd apps/mobile && flutter analyze`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 3: (Optional) E2E** — follow the `open-mat-search-filters` memory pattern (`flutter drive` + adb screenrecord) to exercise: open a session detail → tap "I'm going" → count increments and your name appears → cancel → count decrements.

---

## Self-Review notes
- Spec section F covered: endpoints (T1), Attendee model (T2), sessionDate helper (T3), repository+providers (T4), GoingSection (T5), detail wiring both themes (T6), owner expected (T7), verification (T8).
- Consistent API names: `GoingQuery(openMatId, sessionDate)`, `attendeesProvider`, `rsvpRepositoryProvider`, `RsvpRepository.rsvp/cancel/attendees`, `OpenMat.nextSessionDate({from})`.
- Backend needed no changes — `GET /:id/attendees` already returns name/belt/avatar; `amIGoing` is derived client-side by matching the authed user id against the attendee list.
- `attendeeCount` on the session is kept in sync server-side by the existing facade (`setAttendeeCount`).
