import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_attendee.dart';
import 'package:bjj_open_mat/features/classes/models/gym_class.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';
import 'package:bjj_open_mat/features/classes/screens/class_occurrence_screen.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';
import 'package:bjj_open_mat/features/classes/models/instructor_rating_summary.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeClassRepo implements ClassRepository {
  final List<Map<String, String>> rsvpCalls = [];
  final List<Map<String, String>> unrsvpCalls = [];

  @override
  Future<void> rsvp(String classId, String date) async {
    rsvpCalls.add({'classId': classId, 'date': date});
  }

  @override
  Future<void> unrsvp(String classId, String date) async {
    unrsvpCalls.add({'classId': classId, 'date': date});
  }

  @override
  Future<List<ClassAttendee>> attendees(String classId, String date) async => [];

  @override
  Future<List<ScheduledClass>> schedule(
    String gymId, {
    required String from,
    required String to,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<GymClass>> definitions(String gymId) async => throw UnimplementedError();

  @override
  Future<GymClass> create(String gymId, Map<String, dynamic> body) async =>
      throw UnimplementedError();

  @override
  Future<GymClass> update(String classId, Map<String, dynamic> body) async =>
      throw UnimplementedError();

  @override
  Future<void> archive(String classId) async => throw UnimplementedError();

  @override
  Future<void> overrideOccurrence(String classId, String date, Map<String, dynamic> body) async =>
      throw UnimplementedError();
}

// ── Fake auth notifier (no-op; returns unauthenticated state) ─────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _member = ClassAttendee(
  userId: 'u1',
  name: 'Alice Black',
  isMember: true,
  beltRank: 'black',
  hasProfile: true,
);

final _visitor = ClassAttendee(
  userId: 'u2',
  name: 'Bob White',
  isMember: false,
  beltRank: 'white',
  hasProfile: false,
);

final _scheduled = ScheduledClass(
  classId: 'c1',
  gymId: 'g1',
  date: '2026-08-03',
  title: 'Morning Gi',
  classType: 'gi',
  giType: 'gi',
  skillLevel: 'all_levels',
  startTime: '06:00',
  endTime: '07:30',
  instructorName: 'Coach Andrade',
  status: 'active',
  goingCount: 2,
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeClassRepo> _pump(
  WidgetTester tester, {
  String currentUserId = 'viewer',
  ScheduledClass? scheduled,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeClassRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
        classAttendeesProvider(
          (classId: 'c1', date: '2026-08-03'),
        ).overrideWith((_) async => [_member, _visitor]),
        // Stub out providers used by the manage-gate so no network calls are made.
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        gymByIdProvider('g1').overrideWith(
          (_) async => const Gym(id: 'g1', name: 'Test Gym', address: '123 Main St'),
        ),
        rosterProvider('g1').overrideWith((_) async => <RosterMember>[]),
        // Stub journal providers so no network calls are made (Task 12).
        sharedNotesProvider(
          (classId: 'c1', date: '2026-08-03'),
        ).overrideWith((_) async => <ClassJournalEntry>[]),
        instructorSummaryProvider('inst1').overrideWith(
          (_) async => const InstructorRatingSummary(
            instructorUserId: 'inst1',
            avg: 0,
            count: 0,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: ClassOccurrenceScreen(
          classId: 'c1',
          date: '2026-08-03',
          scheduled: scheduled ?? _scheduled,
          gymId: 'g1',
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

  testWidgets('renders Member badge for gym member attendee', (tester) async {
    await _pump(tester);
    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('renders Visitor badge for non-member attendee', (tester) async {
    await _pump(tester);
    expect(find.text('Visitor'), findsOneWidget);
  });

  testWidgets('shows both attendee names', (tester) async {
    await _pump(tester);
    expect(find.text('Alice Black'), findsOneWidget);
    expect(find.text('Bob White'), findsOneWidget);
  });

  testWidgets('shows "I\'m going" when current user is not attending',
      (tester) async {
    await _pump(tester, currentUserId: 'viewer');
    expect(find.text("I'm going"), findsOneWidget);
  });

  testWidgets('shows "Not going" when current user is attending', (tester) async {
    // u1 is already in the attendee list.
    await _pump(tester, currentUserId: 'u1');
    expect(find.text('Not going'), findsOneWidget);
  });

  testWidgets('tapping "I\'m going" calls rsvp(c1, 2026-08-03)', (tester) async {
    final repo = await _pump(tester, currentUserId: 'viewer');
    await tester.tap(find.text("I'm going"));
    await tester.pump();
    expect(repo.rsvpCalls, hasLength(1));
    expect(repo.rsvpCalls.first['classId'], equals('c1'));
    expect(repo.rsvpCalls.first['date'], equals('2026-08-03'));
  });

  testWidgets('tapping "Not going" calls unrsvp(c1, 2026-08-03)', (tester) async {
    final repo = await _pump(tester, currentUserId: 'u1');
    await tester.tap(find.text('Not going'));
    await tester.pump();
    expect(repo.unrsvpCalls, hasLength(1));
    expect(repo.unrsvpCalls.first['classId'], equals('c1'));
    expect(repo.unrsvpCalls.first['date'], equals('2026-08-03'));
  });

  testWidgets('shows class title and instructor from ScheduledClass', (tester) async {
    await _pump(tester);
    // Title appears in both AppBar and header card — at least once.
    expect(find.text('Morning Gi'), findsWidgets);
    expect(find.text('Coach Andrade'), findsOneWidget);
  });

  testWidgets('shows time range from ScheduledClass', (tester) async {
    await _pump(tester);
    expect(find.textContaining('06:00'), findsOneWidget);
    expect(find.textContaining('07:30'), findsOneWidget);
  });

  testWidgets('shows Cancelled banner and hides RSVP button when cancelled',
      (tester) async {
    final cancelled = ScheduledClass(
      classId: 'c1',
      gymId: 'g1',
      date: '2026-08-03',
      title: 'Morning Gi',
      classType: 'gi',
      giType: 'gi',
      skillLevel: 'all_levels',
      startTime: '06:00',
      endTime: '07:30',
      status: 'cancelled',
      goingCount: 0,
    );
    await _pump(tester, scheduled: cancelled);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text("I'm going"), findsNothing);
    expect(find.text('Not going'), findsNothing);
  });
}
