# Play Policy Fix — Real Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every stubbed screen (My Training, Favorites, Notifications, Gym Detail) with real API-backed data and add a working Directions action, so the app matches its Play Store listing.

**Architecture:** Each feature gets a thin repository over the shared `Dio` client (pattern: `lib/features/open_mats/data/rsvp_repository.dart`) plus Riverpod `FutureProvider`s consumed by the existing Glass-themed screens. Pure computation (stats, streaks, relative time, maps URLs) lives in standalone functions with unit tests.

**Tech Stack:** Flutter (Riverpod, go_router, dio, lucide_icons, url_launcher), existing Elysia API (no backend changes needed).

**Spec:** `docs/superpowers/specs/2026-07-14-play-policy-real-features-design.md`

## Global Constraints

- Working dir for app code: `apps/mobile`. Run tests with `flutter test` from `apps/mobile`.
- Follow existing repo conventions: repository class over `Dio`, `unwrapList`/`unwrapData` from `core/data/api_envelope.dart`, `ApiException.fromDio` on `DioException`, `FutureProvider` for reads.
- Do not change screen visual design (Glass theme) — only the data source.
- Never introduce new package dependencies; `url_launcher` is already in `pubspec.yaml`.
- **Verified facts (do not re-derive):** gym detail route is `/gym/:id`; open-mat detail route is `/open-mat/:id`; search route is `/search`. `OpenMat` uses `feeCents` (int, cents) not `fee`, `giType`, `skillLevel` (`beginner|intermediate|advanced|all`), `dayName`/`startLabel` getters, `gymId`, `address`, `distanceKm`. `Gym` has `description`, `city`, `state`, `rating`, `isVerified`. `CheckIn` has `rounds`, `partners`. `ShimmerLoader` is a shimmer BOX requiring `width`/`height` — it is NOT a full-page loader; for provider loading states use `const Center(child: CircularProgressIndicator())` (the pattern in `discover_screen.dart:195`). Do NOT import `ShimmerLoader` for full-screen loading.
- Conventional commits; NO Co-Authored-By lines.
- No `console.*`-style debug prints left in code.
- Branch: `feature/play-policy-real-features` (already created).

---

### Task 1: Training stats (pure function + tests)

**Files:**
- Create: `apps/mobile/lib/features/training/data/training_stats.dart`
- Test: `apps/mobile/test/training_stats_test.dart`

**Interfaces:**
- Consumes: `CheckIn` from `lib/features/checkins/models/checkin.dart` (fields: `gymId: String?`, `rounds: int?`, `sessionDate: String` ISO `yyyy-MM-dd`).
- Produces: `typedef TrainingStats = ({int mats, int gyms, int rounds, int streakWeeks});` and `TrainingStats computeTrainingStats(List<CheckIn> checkins, {required int totalMats, DateTime? now})`.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/training_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/training/data/training_stats.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

CheckIn ci(String date, {String? gym, int? rounds}) => CheckIn.fromJson({
      'id': date + (gym ?? ''),
      'sessionDate': date,
      'checkedInAt': date,
      if (gym != null) 'gymId': gym,
      if (rounds != null) 'rounds': rounds,
    });

void main() {
  // 2026-07-14 is a Tuesday; week starts Monday 2026-07-13.
  final now = DateTime(2026, 7, 14);

  test('empty list yields zeros', () {
    final s = computeTrainingStats(const [], totalMats: 0, now: now);
    expect(s.mats, 0);
    expect(s.gyms, 0);
    expect(s.rounds, 0);
    expect(s.streakWeeks, 0);
  });

  test('mats uses envelope total, gyms distinct, rounds summed with null-safe', () {
    final s = computeTrainingStats([
      ci('2026-07-13', gym: 'g1', rounds: 5),
      ci('2026-07-10', gym: 'g1'),
      ci('2026-07-08', gym: 'g2', rounds: 3),
    ], totalMats: 47, now: now);
    expect(s.mats, 47);
    expect(s.gyms, 2);
    expect(s.rounds, 8);
  });

  test('streak counts consecutive weeks ending at current week', () {
    final s = computeTrainingStats([
      ci('2026-07-13'), // this week
      ci('2026-07-08'), // last week
      ci('2026-06-30'), // two weeks ago
    ], totalMats: 3, now: now);
    expect(s.streakWeeks, 3);
  });

  test('current week without a check-in does not break a streak from last week', () {
    final s = computeTrainingStats([
      ci('2026-07-08'), // last week
      ci('2026-06-30'), // two weeks ago
    ], totalMats: 2, now: now);
    expect(s.streakWeeks, 2);
  });

  test('a gap week breaks the streak', () {
    final s = computeTrainingStats([
      ci('2026-07-13'), // this week
      ci('2026-06-30'), // two weeks ago (last week missing)
    ], totalMats: 2, now: now);
    expect(s.streakWeeks, 1);
  });

  test('unparseable sessionDate is ignored for streak', () {
    final s = computeTrainingStats([ci('garbage', gym: 'g1', rounds: 2)], totalMats: 1, now: now);
    expect(s.streakWeeks, 0);
    expect(s.rounds, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/training_stats_test.dart`
Expected: FAIL — `training_stats.dart` does not exist.

- [ ] **Step 3: Write implementation**

```dart
// apps/mobile/lib/features/training/data/training_stats.dart
import '../../checkins/models/checkin.dart';

typedef TrainingStats = ({int mats, int gyms, int rounds, int streakWeeks});

/// Monday 00:00 of the week containing [d], date-only.
DateTime weekStart(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// Real training stats. [totalMats] comes from the list envelope's `total`
/// (the fetched page may be a subset). Streak = consecutive calendar weeks
/// with >=1 check-in counting back from the current week; a current week
/// with no check-in yet defers to last week rather than breaking the streak.
TrainingStats computeTrainingStats(
  List<CheckIn> checkins, {
  required int totalMats,
  DateTime? now,
}) {
  final gyms = <String>{};
  var rounds = 0;
  final weeks = <DateTime>{};
  for (final c in checkins) {
    if (c.gymId != null && c.gymId!.isNotEmpty) gyms.add(c.gymId!);
    rounds += c.rounds ?? 0;
    final d = DateTime.tryParse(c.sessionDate);
    if (d != null) weeks.add(weekStart(d));
  }

  var streak = 0;
  var cursor = weekStart(now ?? DateTime.now());
  if (!weeks.contains(cursor)) cursor = cursor.subtract(const Duration(days: 7));
  while (weeks.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 7));
  }

  return (mats: totalMats, gyms: gyms.length, rounds: rounds, streakWeeks: streak);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/training_stats_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/training/data/training_stats.dart apps/mobile/test/training_stats_test.dart
git commit -m "feat(mobile): real training stats computation (mats/gyms/rounds/weekly streak)"
```

---

### Task 2: My Training screen wired to real check-ins

**Files:**
- Create: `apps/mobile/lib/features/training/data/training_provider.dart`
- Modify: `apps/mobile/lib/features/training/screens/my_training_screen.dart` (full rewrite of body; keep header + `_TrainingStatCell`)
- Test: `apps/mobile/test/training_history_test.dart`

**Interfaces:**
- Consumes: `computeTrainingStats`/`TrainingStats` (Task 1), `apiClientProvider`, `Endpoints.myCheckins`, `unwrapList`, `CheckIn.fromJson`, `ShimmerLoader`/`ErrorState`/`EmptyState` shared widgets.
- Produces: `myTrainingProvider` — `FutureProvider<TrainingHistory>` where `class TrainingHistory { final List<CheckIn> items; final int total; }`, and `String formatSessionDate(String iso)` → `'Jul 13'` style label (used by the row widget).

- [ ] **Step 1: Write the failing test for the date formatter**

```dart
// apps/mobile/test/training_history_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/training/data/training_provider.dart';

void main() {
  test('formatSessionDate renders month + day', () {
    expect(formatSessionDate('2026-07-13'), 'Jul 13');
    expect(formatSessionDate('2026-01-02'), 'Jan 2');
  });

  test('formatSessionDate falls back to raw string when unparseable', () {
    expect(formatSessionDate('soon'), 'soon');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/training_history_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the provider + formatter**

```dart
// apps/mobile/lib/features/training/data/training_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../checkins/models/checkin.dart';

class TrainingHistory {
  final List<CheckIn> items;
  final int total;
  const TrainingHistory({required this.items, required this.total});
}

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatSessionDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_monthNames[d.month - 1]} ${d.day}';
}

final myTrainingProvider = FutureProvider<TrainingHistory>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.myCheckins, queryParameters: {'page': 1, 'limit': 100});
  final result = unwrapList(res.data as Map<String, dynamic>);
  final items = result.items.map(CheckIn.fromJson).toList()
    ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
  return TrainingHistory(items: items, total: result.total);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/training_history_test.dart`
Expected: PASS

- [ ] **Step 5: Rewrite the screen**

Replace the entire contents of `apps/mobile/lib/features/training/screens/my_training_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../checkins/models/checkin.dart';
import '../data/training_provider.dart';
import '../data/training_stats.dart';

class MyTrainingScreen extends ConsumerWidget {
  const MyTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myTrainingProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR PROGRESS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text('My Training', style: t.h1Style),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load your training log",
                onRetry: () => ref.invalidate(myTrainingProvider),
              ),
              data: (history) => _TrainingBody(t: t, history: history),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TrainingBody extends StatelessWidget {
  final AppTokens t;
  final TrainingHistory history;
  const _TrainingBody({required this.t, required this.history});

  @override
  Widget build(BuildContext context) {
    final stats = computeTrainingStats(history.items, totalMats: history.total);
    if (history.items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.calendarCheck,
        title: 'No sessions yet',
        subtitle: 'Check in at an open mat to start your training log.',
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
            boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            _TrainingStatCell(label: 'Mats', value: '${stats.mats}', t: t, borderRight: true),
            _TrainingStatCell(label: 'Gyms', value: '${stats.gyms}', t: t, borderRight: true),
            _TrainingStatCell(label: 'Rounds', value: '${stats.rounds}', t: t, borderRight: true),
            _TrainingStatCell(label: 'Streak', value: '${stats.streakWeeks}w', t: t, borderRight: false),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Session History', style: t.h2Style),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: history.items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CheckInRow(t: t, c: history.items[i]),
          ),
        ),
      ),
    ]);
  }
}

class _CheckInRow extends StatelessWidget {
  final AppTokens t;
  final CheckIn c;
  const _CheckInRow({required this.t, required this.c});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (c.rounds != null) '${c.rounds} rounds',
      if (c.partners != null) '${c.partners} partners',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.gymName ?? c.openMatTitle ?? 'Open mat', style: t.h2Style.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              details.isEmpty ? formatSessionDate(c.sessionDate) : '${formatSessionDate(c.sessionDate)} · ${details.join(' · ')}',
              style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
            ),
          ]),
        ),
        if (c.rating != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.star, size: 14, color: t.amber),
            const SizedBox(width: 4),
            Text('${c.rating}', style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
          ]),
      ]),
    );
  }
}

class _TrainingStatCell extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;
  final bool borderRight;
  const _TrainingStatCell({required this.label, required this.value, required this.t, required this.borderRight});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: borderRight ? Border(right: BorderSide(color: t.border)) : null,
        ),
        child: Column(children: [
          Text(value, style: t.numStyle.copyWith(fontSize: 20, color: t.text)),
          const SizedBox(height: 3),
          Text(label, style: t.miniStyle.copyWith(fontSize: 9, color: t.muted)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 6: Analyze + full test run**

Run: `cd apps/mobile && flutter analyze lib/features/training && flutter test`
Expected: no analyzer errors; all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/training apps/mobile/test/training_history_test.dart
git commit -m "feat(mobile): My Training screen shows real check-in history and stats"
```

---

### Task 3: Favorites repository + screen

**Files:**
- Create: `apps/mobile/lib/features/favorites/data/favorite_repository.dart`
- Modify: `apps/mobile/lib/features/favorites/screens/favorites_screen.dart` (full rewrite)
- Test: `apps/mobile/test/favorite_repository_test.dart`

**Interfaces:**
- Consumes: `Gym`/`Gym.fromJson` (`lib/features/gyms/models/gym.dart`), `apiClientProvider`, `Endpoints.myFavorites`, `Endpoints.gymFavorite(id)`, `unwrapList`.
- Produces: `class FavoriteRepository { Future<List<Gym>> list(); Future<void> add(String gymId); Future<void> remove(String gymId); }`, `favoriteRepositoryProvider` (`Provider<FavoriteRepository>`), `myFavoritesProvider` (`FutureProvider<List<Gym>>`). Task 4 uses all three for the gym-detail heart.

- [ ] **Step 1: Write the failing parse test**

```dart
// apps/mobile/test/favorite_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/favorites/data/favorite_repository.dart';

void main() {
  test('parseFavorites maps list envelope to gyms', () {
    final gyms = parseFavorites({
      'data': [
        {'id': 'g1', 'name': 'Atos HQ', 'address': '123 Main St', 'city': 'San Diego', 'state': 'CA', 'rating': 4.8},
        {'id': 'g2', 'name': 'Alliance', 'address': '9 Oak Ave'},
      ],
      'meta': {'page': 1, 'limit': 2, 'total': 2},
    });
    expect(gyms.length, 2);
    expect(gyms.first.name, 'Atos HQ');
    expect(gyms.first.rating, 4.8);
    expect(gyms.last.city, isNull);
  });

  test('parseFavorites tolerates empty data', () {
    expect(parseFavorites({'data': []}), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/favorite_repository_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the repository**

```dart
// apps/mobile/lib/features/favorites/data/favorite_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../../gyms/models/gym.dart';

/// Pure parse step, unit-tested without Dio.
List<Gym> parseFavorites(Map<String, dynamic> body) =>
    unwrapList(body).items.map(Gym.fromJson).toList();

class FavoriteRepository {
  final Dio _dio;
  FavoriteRepository(this._dio);

  Future<List<Gym>> list() async {
    try {
      final res = await _dio.get(Endpoints.myFavorites);
      return parseFavorites(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> add(String gymId) async {
    try {
      await _dio.post(Endpoints.gymFavorite(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> remove(String gymId) async {
    try {
      await _dio.delete(Endpoints.gymFavorite(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(ref.read(apiClientProvider).dio);
});

final myFavoritesProvider = FutureProvider<List<Gym>>((ref) {
  return ref.read(favoriteRepositoryProvider).list();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/favorite_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Rewrite the Favorites screen**

Replace the entire contents of `apps/mobile/lib/features/favorites/screens/favorites_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../gyms/models/gym.dart';
import '../data/favorite_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myFavoritesProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(LucideIcons.heart, color: t.red, size: 20),
              const SizedBox(width: 8),
              Text('Favorite Gyms', style: t.h1Style),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load favorites",
                onRetry: () => ref.invalidate(myFavoritesProvider),
              ),
              data: (gyms) => gyms.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.heart,
                      title: 'No favorite gyms yet',
                      subtitle: 'Open a gym and tap the heart to save it here.',
                      actionLabel: 'Find gyms',
                      onAction: () => context.go('/search'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: gyms.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FavoriteRow(t: t, gym: gyms[i]),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  final AppTokens t;
  final Gym gym;
  const _FavoriteRow({required this.t, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = [gym.city, gym.state].where((s) => s != null && s.isNotEmpty).join(', ');
    return GestureDetector(
      onTap: () => context.push('/gym/${gym.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(gym.name, style: t.h2Style.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                location.isEmpty ? gym.address : location,
                style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
              ),
            ]),
          ),
          if (gym.rating != null) ...[
            Icon(LucideIcons.star, size: 14, color: t.amber),
            const SizedBox(width: 4),
            Text(gym.rating!.toStringAsFixed(1), style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
            const SizedBox(width: 12),
          ],
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(favoriteRepositoryProvider).remove(gym.id);
                ref.invalidate(myFavoritesProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Couldn't remove favorite")),
                  );
                }
              }
            },
            child: Icon(LucideIcons.heart, size: 18, color: t.red),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 6: Analyze + test**

Run: `cd apps/mobile && flutter analyze lib/features/favorites && flutter test`
Expected: clean analyze, all PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/favorites apps/mobile/test/favorite_repository_test.dart
git commit -m "feat(mobile): Favorites screen lists real favorited gyms"
```

---

### Task 4: Gym Detail wired to real gym + favorite heart

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/gym_sessions_provider.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` (full rewrite)
- Test: `apps/mobile/test/gym_sessions_provider_test.dart`

**Interfaces:**
- Consumes: existing `gymByIdProvider` (`lib/features/gyms/data/gym_repository.dart:120`), `Endpoints.openMats`, `OpenMat.fromJson` (`lib/features/open_mats/models/open_mat.dart`), `SessionRow`/`SessionRowData`, `favoriteRepositoryProvider` + `myFavoritesProvider` (Task 3).
- Produces: `gymSessionsProvider` — `FutureProvider.family<List<OpenMat>, String>` (sessions for a gym), and `SessionRowData sessionRowFromOpenMat(OpenMat m)` mapper. Task 5's Directions button is added to this screen in Task 5 (not here).

- [ ] **Step 1: Write the failing mapper test**

```dart
// apps/mobile/test/gym_sessions_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_sessions_provider.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

void main() {
  test('sessionRowFromOpenMat maps fields for SessionRow', () {
    final m = OpenMat.fromJson({
      'id': 'om1',
      'gymId': 'g1',
      'title': 'Sunday Open Mat',
      'gymName': 'Atos HQ',
      'giType': 'nogi',
      'skillLevel': 'advanced',
      'dayOfWeek': 0,
      'startTime': '10:00',
      'endTime': '12:00',
      'feeCents': 1000,
      'status': 'scheduled',
      'verified': true,
    });
    final row = sessionRowFromOpenMat(m);
    expect(row.id, 'om1');
    expect(row.gymName, 'Atos HQ');
    expect(row.giType, 'nogi');
    expect(row.expLevel, 'adv');
    expect(row.fee, 10.0);
    expect(row.distance, '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_sessions_provider_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the provider + mapper**

```dart
// apps/mobile/lib/features/gyms/data/gym_sessions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../shared/widgets/session_row.dart';
import '../../open_mats/models/open_mat.dart';

/// Maps the API skill level to the short code SessionRowData expects.
/// (Mirrors `_expLevel` in discover_screen.dart.)
String _expLevel(String skillLevel) => switch (skillLevel) {
      'beginner' => 'beg',
      'intermediate' => 'int',
      'advanced' => 'adv',
      _ => 'all',
    };

SessionRowData sessionRowFromOpenMat(OpenMat m) => SessionRowData(
      id: m.id,
      gymName: m.gymName ?? m.title,
      giType: m.giType,
      expLevel: _expLevel(m.skillLevel),
      time: m.startLabel,
      day: m.dayName,
      distance: m.distanceKm != null ? '${(m.distanceKm! / 1.60934).toStringAsFixed(1)} mi' : '',
      fee: (m.feeCents ?? 0) / 100,
      isLive: m.status == 'live',
      unverified: !m.verified,
    );

final gymSessionsProvider = FutureProvider.family<List<OpenMat>, String>((ref, gymId) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.openMats, queryParameters: {'gymId': gymId, 'limit': 50});
  return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_sessions_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Rewrite the Gym Detail screen**

Replace the entire contents of `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/session_row.dart';
import '../../favorites/data/favorite_repository.dart';
import '../data/gym_repository.dart';
import '../data/gym_sessions_provider.dart';
import '../models/gym.dart';

class GymDetailScreen extends ConsumerWidget {
  final String? gymId;
  const GymDetailScreen({super.key, this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final id = gymId;
    if (id == null || id.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0),
        body: const ErrorState(message: 'Gym not found'),
      );
    }
    final async = ref.watch(gymByIdProvider(id));
    return async.when(
      loading: () => Scaffold(backgroundColor: t.bg, body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0),
        body: ErrorState(message: "Couldn't load gym", onRetry: () => ref.invalidate(gymByIdProvider(id))),
      ),
      data: (gym) => _GlassGymDetail(t: t, gym: gym),
    );
  }
}

class _GlassGymDetail extends ConsumerWidget {
  final AppTokens t;
  final Gym gym;
  const _GlassGymDetail({required this.t, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(gymSessionsProvider(gym.id));
    final favoritesAsync = ref.watch(myFavoritesProvider);
    final isFavorite = favoritesAsync.maybeWhen(
      data: (gyms) => gyms.any((g) => g.id == gym.id),
      orElse: () => false,
    );
    final location = [gym.city, gym.state].where((s) => s != null && s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: t.bg2,
          leading: GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: Icon(LucideIcons.arrowLeft, color: t.text),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () async {
                  final repo = ref.read(favoriteRepositoryProvider);
                  try {
                    if (isFavorite) {
                      await repo.remove(gym.id);
                    } else {
                      await repo.add(gym.id);
                    }
                    ref.invalidate(myFavoritesProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't update favorite")),
                      );
                    }
                  }
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? t.red : Colors.white,
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.primary, t.both],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gym.name.toUpperCase(), style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(location.isEmpty ? gym.address : location, style: t.bodyStyle.copyWith(color: Colors.white70)),
                ],
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              if (gym.rating != null) ...[
                _Pill(label: '${gym.rating!.toStringAsFixed(1)} ★', color: t.amber, t: t),
                const SizedBox(width: 8),
              ],
              if (gym.isVerified) _Pill(label: 'Verified', color: t.green, t: t),
            ]),
            const SizedBox(height: 20),
            Text('Open Mats', style: t.h2Style),
            const SizedBox(height: 8),
            sessionsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Text("Couldn't load sessions", style: t.bodyStyle.copyWith(color: t.muted)),
              data: (mats) => mats.isEmpty
                  ? Text('No open mats posted yet.', style: t.bodyStyle.copyWith(color: t.muted))
                  : Column(children: [
                      for (final m in mats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SessionRow(
                            session: sessionRowFromOpenMat(m),
                            onTap: () => context.push('/open-mat/${m.id}'),
                          ),
                        ),
                    ]),
            ),
            if (gym.description != null && gym.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('About', style: t.h2Style),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Text(gym.description!, style: t.bodyStyle),
              ),
            ],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final AppTokens t;
  const _Pill({required this.label, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.33)),
      ),
      child: Text(label, style: t.miniStyle.copyWith(color: color, fontSize: 11)),
    );
  }
}
```

- [ ] **Step 6: Analyze + test**

Run: `cd apps/mobile && flutter analyze lib/features/gyms && flutter test`
Expected: clean, all PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/gyms apps/mobile/test/gym_sessions_provider_test.dart
git commit -m "feat(mobile): Gym Detail shows real gym, sessions, and favorite toggle"
```

---

### Task 5: Directions action (gym detail + open-mat detail)

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/directions.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` (insert a Directions button under the pills row)
- Modify: `apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart` (insert a Directions button after the info-cards row)
- Test: `apps/mobile/test/directions_test.dart`

**Interfaces:**
- Consumes: `Endpoints.gymDirections(id)`, `unwrapData`, `url_launcher`'s `launchUrl`, `OpenMat.gymId`/`OpenMat.address`.
- Produces: `class DirectionsInfo { final String mapsUrl; }`, `DirectionsInfo parseDirections(Map<String, dynamic> body)`, `String addressMapsUrl(String address)`, and `Future<void> openDirections(WidgetRef ref, BuildContext context, {String? gymId, String? address})`.

- [ ] **Step 1: Write the failing tests**

```dart
// apps/mobile/test/directions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/directions.dart';

void main() {
  test('parseDirections reads mapsUrl from data envelope', () {
    final d = parseDirections({
      'data': {
        'latitude': 32.7,
        'longitude': -117.1,
        'address': '123 Main St',
        'mapsUrl': 'https://www.google.com/maps/dir/?api=1&destination=32.7,-117.1',
      },
    });
    expect(d.mapsUrl, 'https://www.google.com/maps/dir/?api=1&destination=32.7,-117.1');
  });

  test('addressMapsUrl builds an encoded search URL', () {
    expect(
      addressMapsUrl('123 Main St, San Diego, CA'),
      'https://www.google.com/maps/search/?api=1&query=123%20Main%20St%2C%20San%20Diego%2C%20CA',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/directions_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the helper**

```dart
// apps/mobile/lib/features/gyms/data/directions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';

class DirectionsInfo {
  final String mapsUrl;
  const DirectionsInfo({required this.mapsUrl});
}

DirectionsInfo parseDirections(Map<String, dynamic> body) {
  final data = unwrapData(body);
  return DirectionsInfo(mapsUrl: data['mapsUrl'] as String? ?? '');
}

String addressMapsUrl(String address) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';

/// Opens the platform maps app with directions to a gym (preferred) or a
/// raw address fallback. Shows a snackbar on any failure.
Future<void> openDirections(
  WidgetRef ref,
  BuildContext context, {
  String? gymId,
  String? address,
}) async {
  String url = '';
  try {
    if (gymId != null && gymId.isNotEmpty) {
      final dio = ref.read(apiClientProvider).dio;
      final res = await dio.get(Endpoints.gymDirections(gymId));
      url = parseDirections(res.data as Map<String, dynamic>).mapsUrl;
    }
  } catch (_) {
    url = '';
  }
  if (url.isEmpty && address != null && address.isNotEmpty) {
    url = addressMapsUrl(address);
  }
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location available for directions')),
      );
    }
    return;
  }
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open maps")),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/directions_test.dart`
Expected: PASS

- [ ] **Step 5: Add the button to Gym Detail**

In `gym_detail_screen.dart`, add the import `import '../data/directions.dart';` and insert directly after the pills `Row(...)` (inside the `SliverChildListDelegate` list, before `const SizedBox(height: 20)`):

```dart
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => openDirections(ref, context, gymId: gym.id, address: gym.address),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.navigation, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Directions', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
```

- [ ] **Step 6: Add the button to Open-Mat Detail**

In `open_mat_detail_screen.dart`: the body widget `_GlassDetail` is a `StatelessWidget` — convert it to `ConsumerWidget` (`flutter_riverpod` is already imported by the file's siblings; add the import if missing), change `build(BuildContext context)` to `build(BuildContext context, WidgetRef ref)`, add `import '../../gyms/data/directions.dart';`, and insert after the info-cards `Row(...)`:

```dart
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => openDirections(ref, context, gymId: mat.gymId, address: mat.address),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.navigation, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Directions', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
```

- [ ] **Step 7: Analyze + test**

Run: `cd apps/mobile && flutter analyze lib && flutter test`
Expected: clean, all PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/gyms/data/directions.dart apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart apps/mobile/test/directions_test.dart
git commit -m "feat(mobile): Directions action opens platform maps from gym and session detail"
```

---

### Task 6: Notifications wired to real inbox

**Files:**
- Create: `apps/mobile/lib/features/notifications/models/app_notification.dart`
- Create: `apps/mobile/lib/features/notifications/data/notification_repository.dart`
- Modify: `apps/mobile/lib/features/notifications/screens/notifications_screen.dart` (full rewrite)
- Modify: `apps/mobile/lib/core/api/endpoints.dart` (add notification endpoints)
- Test: `apps/mobile/test/app_notification_test.dart`

**Interfaces:**
- Consumes: API `/api/v1/notifications` (list envelope of `{id, userId, type, title, body, read, data?, createdAt}`), `POST /api/v1/notifications/:id/read`, `POST /api/v1/notifications/read-all`.
- Produces: `class AppNotification { String id; String type; String title; String body; bool read; String createdAt; }` with `fromJson`, `String relativeTime(String iso, {DateTime? now})`, `notificationRepositoryProvider`, `myNotificationsProvider` (`FutureProvider<List<AppNotification>>`).

- [ ] **Step 1: Add endpoints**

In `apps/mobile/lib/core/api/endpoints.dart`, after the `// Favorites` block add:

```dart
  // Notifications
  static const String notifications = '/api/v1/notifications';
  static String notificationRead(String id) => '/api/v1/notifications/$id/read';
  static const String notificationsReadAll = '/api/v1/notifications/read-all';
```

- [ ] **Step 2: Write the failing tests**

```dart
// apps/mobile/test/app_notification_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/notifications/models/app_notification.dart';

void main() {
  test('AppNotification.fromJson parses fields', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'type': 'rsvp',
      'title': 'New RSVP',
      'body': 'Alex is going to your Sunday open mat.',
      'read': false,
      'createdAt': '2026-07-14T10:00:00.000Z',
    });
    expect(n.id, 'n1');
    expect(n.type, 'rsvp');
    expect(n.read, false);
  });

  test('AppNotification.fromJson defaults read=false and type=system', () {
    final n = AppNotification.fromJson({'id': 'n2', 'title': 't', 'body': 'b', 'createdAt': ''});
    expect(n.read, false);
    expect(n.type, 'system');
  });

  test('relativeTime buckets minutes/hours/days', () {
    final now = DateTime.utc(2026, 7, 14, 12, 0, 0);
    expect(relativeTime('2026-07-14T11:59:30.000Z', now: now), 'Just now');
    expect(relativeTime('2026-07-14T11:15:00.000Z', now: now), '45m ago');
    expect(relativeTime('2026-07-14T09:00:00.000Z', now: now), '3h ago');
    expect(relativeTime('2026-07-12T12:00:00.000Z', now: now), '2d ago');
    expect(relativeTime('not-a-date', now: now), '');
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd apps/mobile && flutter test test/app_notification_test.dart`
Expected: FAIL — model does not exist.

- [ ] **Step 4: Write the model**

```dart
// apps/mobile/lib/features/notifications/models/app_notification.dart
class AppNotification {
  final String id;
  final String type; // rsvp | review | session_update | system
  final String title;
  final String body;
  final bool read;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'system',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: json['createdAt'] as String? ?? '',
      );
}

String relativeTime(String iso, {DateTime? now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd apps/mobile && flutter test test/app_notification_test.dart`
Expected: PASS

- [ ] **Step 6: Write the repository**

```dart
// apps/mobile/lib/features/notifications/data/notification_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final Dio _dio;
  NotificationRepository(this._dio);

  Future<List<AppNotification>> list({int page = 1, int limit = 50}) async {
    try {
      final res = await _dio.get(Endpoints.notifications, queryParameters: {'page': page, 'limit': limit});
      return unwrapList(res.data as Map<String, dynamic>).items.map(AppNotification.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post(Endpoints.notificationRead(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post(Endpoints.notificationsReadAll);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider).dio);
});

final myNotificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.read(notificationRepositoryProvider).list();
});
```

- [ ] **Step 7: Rewrite the screen**

Replace the entire contents of `apps/mobile/lib/features/notifications/screens/notifications_screen.dart` with (keep the existing `_backButton` helper verbatim from the current file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

Widget _backButton(BuildContext context, AppTokens t) => GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Icon(LucideIcons.arrowLeft, color: t.text, size: 22),
    );

IconData _iconFor(String type) => switch (type) {
      'rsvp' => LucideIcons.users,
      'review' => LucideIcons.star,
      'session_update' => LucideIcons.calendarCheck,
      _ => LucideIcons.bell,
    };

Color _colorFor(String type, AppTokens t) => switch (type) {
      'rsvp' => t.gi,
      'review' => t.amber,
      'session_update' => t.green,
      _ => t.muted,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myNotificationsProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              _backButton(context, t),
              const SizedBox(width: 12),
              Expanded(child: Text('Notifications', style: t.h1Style)),
              GestureDetector(
                onTap: () async {
                  try {
                    await ref.read(notificationRepositoryProvider).markAllRead();
                    ref.invalidate(myNotificationsProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't mark all read")),
                      );
                    }
                  }
                },
                child: Text('Mark all read', style: t.miniStyle.copyWith(color: t.primary, fontSize: 12)),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load notifications",
                onRetry: () => ref.invalidate(myNotificationsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.bell,
                      title: 'No notifications',
                      subtitle: "You're all caught up.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _NotificationRow(t: t, n: items[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AppTokens t;
  final AppNotification n;
  const _NotificationRow({required this.t, required this.n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: n.read
          ? null
          : () async {
              try {
                await ref.read(notificationRepositoryProvider).markRead(n.id);
                ref.invalidate(myNotificationsProvider);
              } catch (_) {/* leave unread */}
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.read ? Colors.white : t.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: n.read ? t.border : t.primary.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_iconFor(n.type), size: 18, color: _colorFor(n.type, t)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: t.h2Style.copyWith(fontSize: 14, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
              const SizedBox(height: 3),
              Text(n.body, style: t.bodyStyle.copyWith(color: t.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(relativeTime(n.createdAt), style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 8: Analyze + test**

Run: `cd apps/mobile && flutter analyze lib/features/notifications lib/core/api && flutter test`
Expected: clean, all PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/mobile/lib/features/notifications apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/app_notification_test.dart
git commit -m "feat(mobile): Notifications screen shows real in-app inbox with read tracking"
```

---

### Task 7: Play Store listing doc + resubmission checklist

**Files:**
- Create: `docs/play-store-listing.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Write the doc**

```markdown
# Google Play Listing — BJJ Open Mat (com.davissylvester.bjjopenmat)

Compliant replacement listing after the 2026-07-14 Misleading Claims rejection.
Every claim below maps to a shipped, reachable feature. Do NOT add claims for
features that are not in the released build.

## Short description (max 80 chars)
```
Find BJJ open mats near you, RSVP, check in, and log your training.
```

## Full description (max 4,000 chars)
```
BJJ Open Mat is the fastest way to find a place to roll — wherever you are.

Open the app and it shows open mats near you using your location. Filter by
gi, no-gi, skill level, day, and distance (up to 100 miles), or search any
city or ZIP.

FIND A MAT
• See open mats near you the moment you open the app
• Search by GPS, city, or ZIP
• Filter by Gi / No-Gi, free sessions, skill level, and when you want to train
• View session details: time, day, fee, gym, and one-tap directions

SEE WHO'S GOING
• Tap "I'm going" to RSVP to a specific session
• See how many people are coming and who they are
• Check in when you arrive and log rounds, partners, and a review

YOUR TRAINING
• Session history built from your real check-ins
• Mats, gyms, rounds, and weekly streak at a glance
• Save favorite gyms for quick access

YOUR PROFILE
• Track your belt and stripes
• Set your IBJJF weight class (by gender and gi/no-gi)
• Save your home city and gym

FOR GYM OWNERS
• Post open mat sessions and keep them up to date
• See expected attendance from RSVPs alongside real check-ins
• Switch between practitioner and gym-owner views any time

Community-driven: anyone can submit an open mat, and gym owners verify their
sessions.

Grab your gi (or don't) and go find a roll.
```

## Resubmission checklist (Play Console)

1. **Ship the fixed build**: merge this branch, run the Mobile Release
   workflow (or push a release) so the new `.aab` lands on the `internal`
   track; promote to production review.
2. **Retake ALL en-US phone screenshots** from the fixed build with a real
   account that has real data — no placeholder art, no fabricated stats.
   Capture: Home/Near You, Search with filters, Open-mat detail with
   "I'm going", My Training (real history), Gym detail with Directions.
3. **Update Store listing**: Play Console → Grow → Store presence → Main
   store listing. Replace the description with the text above and upload the
   new screenshots. Check any custom/translated listings for the same claims.
4. **Resubmit**: Play Console → Publishing overview → send changes for review.
5. Do NOT appeal — the violation was accurate; the fix is the resubmission.

## Claim → feature audit (keep in sync)

| Claim | Feature | Code |
|---|---|---|
| Directions | Maps launch from gym/session detail | `features/gyms/data/directions.dart` |
| Log rounds/partners/review | Check-in form | `features/checkins/` |
| Session history + streak | My Training | `features/training/` |
| Favorite gyms | Favorites + gym-detail heart | `features/favorites/` |
| Who's going | RSVP + attendee grid | `features/open_mats/widgets/going_section.dart` |
| Real notifications inbox | Notifications screen | `features/notifications/` |
```

- [ ] **Step 2: Commit**

```bash
git add docs/play-store-listing.md
git commit -m "docs: compliant Google Play listing + resubmission checklist"
```

---

### Task 8: Full verification

**Files:** none created; verification only.

- [ ] **Step 1: Full analyzer + test suite**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: zero analyzer issues in changed files; all tests PASS.

- [ ] **Step 2: Runtime verification (superpowers:verification-before-completion + verify skill)**

Run the app against the production API and manually walk each fixed surface:

```bash
cd apps/mobile
flutter run --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io
```

Verify with a real logged-in account:
1. My Training shows YOUR check-ins (or the empty state on a fresh account) — never Atos/Renzo stub data.
2. Favorites is empty on a fresh account; heart a gym from Gym Detail → it appears; heart again → it disappears.
3. Gym Detail shows the actual gym you tapped (name, sessions).
4. Directions opens the maps app from both gym detail and session detail.
5. Notifications shows real items or the empty state; Mark all read works.

- [ ] **Step 3: Report results honestly**

If anything fails, fix before claiming completion. Then present the branch for merge/PR (superpowers:finishing-a-development-branch).
```
