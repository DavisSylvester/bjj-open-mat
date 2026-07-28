import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_attendee.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';
import 'package:bjj_open_mat/features/classes/models/gym_class.dart';
import 'package:bjj_open_mat/features/classes/models/instructor_rating_summary.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';
import 'package:bjj_open_mat/features/classes/screens/class_occurrence_screen.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Fake class repository ─────────────────────────────────────────────────────

class _FakeClassRepo implements ClassRepository {
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
  Future<void> overrideOccurrence(
          String classId, String date, Map<String, dynamic> body) async =>
      throw UnimplementedError();
}

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _classId = 'c1';
const _date = '2026-08-03';
const _gymId = 'g1';
const _instructorUserId = 'inst1';

final _scheduledWithInstructor = ScheduledClass(
  classId: _classId,
  gymId: _gymId,
  date: _date,
  title: 'Morning Gi',
  classType: 'gi',
  giType: 'gi',
  skillLevel: 'all_levels',
  startTime: '06:00',
  endTime: '07:30',
  instructorUserId: _instructorUserId,
  instructorName: 'Coach Andrade',
  status: 'active',
  goingCount: 0,
);

final _sharedEntry1 = ClassJournalEntry(
  id: 'j1',
  classId: _classId,
  gymId: _gymId,
  userId: 'u2',
  date: _date,
  whatWasTaught: 'Double leg takedown',
  techniqueTags: ['takedown', 'wrestling'],
  shared: true,
);

final _sharedEntry2 = ClassJournalEntry(
  id: 'j2',
  classId: _classId,
  gymId: _gymId,
  userId: 'u3',
  date: _date,
  whatWasTaught: 'Triangle choke from guard',
  techniqueTags: ['triangle', 'submission'],
  shared: true,
);

const _instructorSummary = InstructorRatingSummary(
  instructorUserId: _instructorUserId,
  avg: 4.5,
  count: 8,
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Class repo (needed for RSVP)
        classRepositoryProvider.overrideWithValue(_FakeClassRepo()),
        // Current user (non-null → RSVP button shows)
        currentUserIdProvider.overrideWith((ref) => 'viewer'),
        // Attendees — empty so the screen builds without real data
        classAttendeesProvider(
          (classId: _classId, date: _date),
        ).overrideWith((_) async => <ClassAttendee>[]),
        // Auth / gym / roster stubs
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        gymByIdProvider(_gymId).overrideWith(
          (_) async => const Gym(id: _gymId, name: 'Test Gym', address: '123 Main St'),
        ),
        rosterProvider(_gymId).overrideWith((_) async => <RosterMember>[]),
        // ── Task-12 providers ────────────────────────────────────────────────
        sharedNotesProvider(
          (classId: _classId, date: _date),
        ).overrideWith((_) async => [_sharedEntry1, _sharedEntry2]),
        instructorSummaryProvider(_instructorUserId)
            .overrideWith((_) async => _instructorSummary),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: ClassOccurrenceScreen(
          classId: _classId,
          date: _date,
          scheduled: _scheduledWithInstructor,
          gymId: _gymId,
        ),
      ),
    ),
  );

  // Pump past futures
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders shared note: "Double leg takedown"', (tester) async {
    await _pump(tester);
    expect(find.text('Double leg takedown'), findsOneWidget);
  });

  testWidgets('renders shared note: "Triangle choke from guard"', (tester) async {
    await _pump(tester);
    expect(find.text('Triangle choke from guard'), findsOneWidget);
  });

  testWidgets('renders instructor avg rating "4.5"', (tester) async {
    await _pump(tester);
    expect(find.textContaining('4.5'), findsOneWidget);
  });

  testWidgets('renders instructor rating count "(8)"', (tester) async {
    await _pump(tester);
    // The badge renders "4.5 (8)" — match on the count in parentheses
    expect(find.textContaining('(8)'), findsOneWidget);
  });
}
