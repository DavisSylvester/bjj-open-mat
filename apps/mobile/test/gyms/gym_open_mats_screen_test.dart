import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_sessions_provider.dart';
import 'package:bjj_open_mat/features/gyms/screens/gym_open_mats_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kGymId = 'g1';

// NOTE: the brief's fixture used `dayOfWeek: 'sunday'`, but
// OpenMat.dayOfWeek is `int?` (0=Sun..6=Sat), not a String. Corrected to `0`
// so the fixture actually compiles against the real model.
OpenMat _mat({required String id, required String title}) => OpenMat(
      id: id,
      gymId: _kGymId,
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
