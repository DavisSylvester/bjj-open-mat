import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_attendee.dart';
import 'package:bjj_open_mat/features/classes/models/gym_class.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';
import 'package:bjj_open_mat/features/classes/screens/class_edit_screen.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/belt_promotion.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeClassRepo implements ClassRepository {
  final List<({String gymId, Map<String, dynamic> body})> createCalls = [];
  final List<({String classId, Map<String, dynamic> body})> updateCalls = [];

  @override
  Future<GymClass> create(String gymId, Map<String, dynamic> body) async {
    createCalls.add((gymId: gymId, body: body));
    return GymClass(
      id: 'new-id',
      gymId: gymId,
      title: body['title'] as String? ?? 'Test',
      classType: body['classType'] as String? ?? 'gi',
      giType: body['giType'] as String? ?? 'gi',
      skillLevel: body['skillLevel'] as String? ?? 'all',
      isRecurring: body['isRecurring'] as bool? ?? false,
      startTime: body['startTime'] as String? ?? '06:00',
      endTime: body['endTime'] as String? ?? '07:00',
      status: 'active',
    );
  }

  @override
  Future<GymClass> update(String classId, Map<String, dynamic> body) async {
    updateCalls.add((classId: classId, body: body));
    return GymClass(
      id: classId,
      gymId: 'g1',
      title: body['title'] as String? ?? 'Test',
      classType: body['classType'] as String? ?? 'gi',
      giType: body['giType'] as String? ?? 'gi',
      skillLevel: body['skillLevel'] as String? ?? 'all',
      isRecurring: body['isRecurring'] as bool? ?? false,
      startTime: body['startTime'] as String? ?? '06:00',
      endTime: body['endTime'] as String? ?? '07:00',
      status: 'active',
    );
  }

  @override
  Future<void> archive(String classId) async {}

  @override
  Future<void> overrideOccurrence(
    String classId,
    String date,
    Map<String, dynamic> body,
  ) async {}

  @override
  Future<void> rsvp(String classId, String date) async {}

  @override
  Future<void> unrsvp(String classId, String date) async {}

  @override
  Future<List<ClassAttendee>> attendees(String classId, String date) async => [];

  @override
  Future<List<ScheduledClass>> schedule(
    String gymId, {
    required String from,
    required String to,
  }) async =>
      [];

  @override
  Future<List<GymClass>> definitions(String gymId) async => [];
}

// ── Fake membership repo ──────────────────────────────────────────────────────

class _FakeMembershipRepo implements MembershipRepository {
  final List<RosterMember> members;
  _FakeMembershipRepo(this.members);

  @override
  Future<List<RosterMember>> roster(String gymId) async => members;

  @override
  Future<GymMembership> join(String gymId) async => throw UnimplementedError();
  @override
  Future<void> leave(String gymId) async => throw UnimplementedError();
  @override
  Future<GymMembership> updateMine(String gymId,
          {bool? visibleInRoster, bool? isHome}) async =>
      throw UnimplementedError();
  @override
  Future<GymMembership> manageMember(String gymId, String userId,
          {bool? verifiedMember, String? gymRole}) async =>
      throw UnimplementedError();
  @override
  Future<BeltPromotion> promote(String gymId, String userId,
          {required String beltRank,
          required int beltStripes,
          String? note}) async =>
      throw UnimplementedError();
  @override
  Future<List<BeltPromotion>> userPromotions(String userId) async => [];
  @override
  Future<List<GymMembership>> myMemberships() async => [];
}

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeClassRepo> _pump(
  WidgetTester tester, {
  List<RosterMember> rosterMembers = const [],
  GymClass? existing,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeClassRepo();
  final membershipRepo = _FakeMembershipRepo(rosterMembers);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classRepositoryProvider.overrideWithValue(repo),
        membershipRepositoryProvider.overrideWithValue(membershipRepo),
        rosterProvider('g1').overrideWith((_) async => rosterMembers),
        scheduleProvider.overrideWith((ref, arg) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(
          body: ClassEditScreen(gymId: 'g1', existing: existing),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders title field and class type dropdown', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('class_edit_title')), findsOneWidget);
    expect(find.byKey(const Key('class_edit_class_type')), findsOneWidget);
  });

  testWidgets('Save button disabled when title is empty', (tester) async {
    await _pump(tester);
    final saveBtn = find.byKey(const Key('class_edit_save'));
    expect(saveBtn, findsOneWidget);
    // Title is empty, so Save should be disabled.
    final btn = tester.widget<ElevatedButton>(saveBtn);
    expect(btn.onPressed, isNull);
  });

  testWidgets('Save button enabled after filling required fields in recurring mode',
      (tester) async {
    final repo = await _pump(tester);

    // Fill title.
    await tester.enterText(
      find.byKey(const Key('class_edit_title')),
      'Morning Gi',
    );
    await tester.pump();

    // Pick class type via dropdown.
    await tester.tap(find.byKey(const Key('class_edit_class_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gi').last);
    await tester.pumpAndSettle();

    // In recurring mode (default), pick a day of week — Mon (index 0).
    await tester.tap(find.byKey(const Key('class_edit_day_0')));
    await tester.pump();

    // Save should now be enabled.
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('class_edit_save')),
    );
    expect(btn.onPressed, isNotNull);

    // Tap Save and assert create was called with correct body.
    await tester.tap(find.byKey(const Key('class_edit_save')));
    await tester.pump();

    expect(repo.createCalls, hasLength(1));
    final call = repo.createCalls.first;
    expect(call.gymId, equals('g1'));
    expect(call.body['title'], equals('Morning Gi'));
    expect(call.body['classType'], equals('gi'));
    expect(call.body['dayOfWeek'], equals(0));
    expect(call.body['isRecurring'], isTrue);
    expect(call.body['startTime'], isNotNull);
    expect(call.body['endTime'], isNotNull);
  });

  testWidgets('one-off mode: Save disabled without date', (tester) async {
    await _pump(tester);

    // Fill title.
    await tester.enterText(
      find.byKey(const Key('class_edit_title')),
      'Special Session',
    );
    await tester.pump();

    // Switch to one-off mode.
    await tester.tap(find.byKey(const Key('class_edit_recurring_toggle')));
    await tester.pump();

    // No date selected yet — Save should still be disabled.
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('class_edit_save')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('"other" class type shows label text field', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('class_edit_class_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('class_edit_class_type_label')), findsOneWidget);
  });

  testWidgets('create called with title, classType, dayOfWeek, startTime, endTime, isRecurring',
      (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(
      find.byKey(const Key('class_edit_title')),
      'Evening NoGi',
    );
    await tester.pump();

    // Pick NoGi class type.
    await tester.tap(find.byKey(const Key('class_edit_class_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No-Gi').last);
    await tester.pumpAndSettle();

    // Pick Wednesday (day 2).
    await tester.tap(find.byKey(const Key('class_edit_day_2')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('class_edit_save')));
    await tester.pump();

    expect(repo.createCalls, hasLength(1));
    final body = repo.createCalls.first.body;
    expect(body['title'], equals('Evening NoGi'));
    expect(body['classType'], equals('nogi'));
    expect(body['dayOfWeek'], equals(2));
    expect(body['isRecurring'], isTrue);
    expect(body['startTime'], isA<String>());
    expect(body['endTime'], isA<String>());
  });
}
