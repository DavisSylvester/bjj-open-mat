import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_sessions_provider.dart';
import 'package:bjj_open_mat/features/gyms/screens/gym_open_mats_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _kGymId = 'g1';

// NOTE: the brief's fixture used `dayOfWeek: 'sunday'`, but
// OpenMat.dayOfWeek is `int?` (0=Sun..6=Sat), not a String. Corrected to `0`
// so the fixture actually compiles against the real model.
//
// `gymName` is set explicitly here because the API always populates it
// (open-mat.facade.mts persists `gymName: gym.name` on every open mat).
// sessionRowFromOpenMat falls back to `title` only when `gymName` is null,
// which never happens in production, so the fixture must carry a gymName
// for the test to reflect what actually renders.
OpenMat _mat({required String id, required String title, required String gymName}) => OpenMat(
      id: id,
      gymId: _kGymId,
      gymName: gymName,
      title: title,
      dayOfWeek: 0,
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
  testWidgets('renders a row per open mat, headlined with the gym name', (tester) async {
    // SessionRow renders sessionRowFromOpenMat's `gymName`, not `title` --
    // the fixtures below carry distinct gymNames so each row is
    // independently verifiable, matching what production actually shows.
    await _pump(tester, sessions: () async => [
          _mat(id: 'm1', title: 'Sunday No-Gi', gymName: 'Downtown BJJ'),
          _mat(id: 'm2', title: 'Friday Rolls', gymName: 'Westside Grappling'),
        ]);
    expect(find.text('Downtown BJJ'), findsOneWidget);
    expect(find.text('Westside Grappling'), findsOneWidget);
    expect(find.text('Sunday No-Gi'), findsNothing);
    expect(find.text('Friday Rolls'), findsNothing);
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

  testWidgets('returning from the add-session push re-fetches the gym\'s open mats', (tester) async {
    // Regression test: gymSessionsProvider is a plain (non-autoDispose)
    // FutureProvider, so its result is cached for the app's lifetime unless
    // something invalidates it. Posting a session from the empty state used
    // to leave the screen stuck showing "No open mats posted yet." on
    // return, because nothing invalidated gymSessionsProvider(gymId).
    var fetchCount = 0;

    final router = GoRouter(
      initialLocation: '/gym/$_kGymId/open-mats',
      routes: [
        GoRoute(
          path: '/gym/:id/open-mats',
          builder: (c, s) => GymOpenMatsScreen(gymId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/add-session',
          builder: (c, s) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => c.pop(),
                child: const Text('DONE POSTING'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gymSessionsProvider(_kGymId).overrideWith((ref) async {
            fetchCount++;
            return <OpenMat>[];
          }),
        ],
        child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fetchCount, 1);
    expect(find.byKey(const Key('gym-open-mats-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('gym-open-mats-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('DONE POSTING'), findsOneWidget);

    await tester.tap(find.text('DONE POSTING'));
    await tester.pumpAndSettle();

    expect(fetchCount, 2);
  });
}
