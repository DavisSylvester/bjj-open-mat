import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';
import 'package:bjj_open_mat/features/forum/data/forum_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';
import 'package:bjj_open_mat/features/mygym/data/home_gym_provider.dart';
import 'package:bjj_open_mat/features/mygym/screens/my_gym_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testGym = Gym(id: 'g1', name: 'Test Gym', address: '123 Main St', ownerId: 'owner-1');

RosterMember _member(String userId, String gymRole) => RosterMember(
      userId: userId,
      name: userId,
      gymRole: gymRole,
      verifiedMember: true,
      hasProfile: true,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String? homeGymId,
  String? currentUserId,
  List<RosterMember> roster = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeGymIdProvider.overrideWith((ref) async => homeGymId),
        gymByIdProvider.overrideWith((ref, id) async => _testGym),
        rosterProvider.overrideWith((ref, id) async => roster),
        scheduleProvider.overrideWith((ref, a) async => []),
        forumQuestionsProvider.overrideWith((ref, a) async => []),
        currentUserIdProvider.overrideWithValue(currentUserId),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const MyGymScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the find-your-gym prompt when there is no gym', (tester) async {
    await _pump(tester, homeGymId: null);
    expect(find.text('Find your gym'), findsOneWidget);
    expect(find.textContaining('roster'), findsWidgets);
  });

  testWidgets('the empty state offers a route into gym search', (tester) async {
    await _pump(tester, homeGymId: null);
    expect(find.byKey(const Key('mygym-find-gym-button')), findsOneWidget);
  });

  testWidgets('schedule and roster tiles are always visible', (tester) async {
    await _pump(tester, homeGymId: 'g1', currentUserId: null, roster: const []);
    expect(find.byKey(const Key('mygym-action-schedule')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-roster')), findsOneWidget);
  });

  testWidgets('forum and feedback tiles are hidden for a non-member', (tester) async {
    await _pump(tester, homeGymId: 'g1', currentUserId: 'stranger', roster: const []);
    expect(find.byKey(const Key('mygym-action-forum')), findsNothing);
    expect(find.byKey(const Key('mygym-action-instructor-feedback')), findsNothing);
  });

  testWidgets('forum tile is visible but feedback stays hidden for a plain member', (tester) async {
    await _pump(
      tester,
      homeGymId: 'g1',
      currentUserId: 'member-1',
      roster: [_member('member-1', 'student')],
    );
    expect(find.byKey(const Key('mygym-action-forum')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-instructor-feedback')), findsNothing);
  });

  testWidgets('forum and feedback tiles are visible for a coach who can manage the gym', (tester) async {
    await _pump(
      tester,
      homeGymId: 'g1',
      currentUserId: 'coach-1',
      roster: [_member('coach-1', 'coach')],
    );
    expect(find.byKey(const Key('mygym-action-forum')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-instructor-feedback')), findsOneWidget);
  });

  testWidgets('forum and feedback tiles are visible for the gym owner', (tester) async {
    await _pump(
      tester,
      homeGymId: 'g1',
      currentUserId: 'owner-1',
      roster: const [],
    );
    expect(find.byKey(const Key('mygym-action-forum')), findsOneWidget);
    expect(find.byKey(const Key('mygym-action-instructor-feedback')), findsOneWidget);
  });
}
