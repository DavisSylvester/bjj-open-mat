import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';
import 'package:bjj_open_mat/features/classes/screens/class_schedule_screen.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _morningGi = ScheduledClass(
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
  goingCount: 5,
);

final _eveningNoGi = ScheduledClass(
  classId: 'c2',
  gymId: 'g1',
  date: '2026-08-04',
  title: 'Evening NoGi',
  classType: 'nogi',
  giType: 'nogi',
  skillLevel: 'advanced',
  startTime: '19:00',
  endTime: '20:30',
  instructorName: 'Coach Silva',
  status: 'cancelled',
  goingCount: 0,
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scheduleProvider.overrideWith(
          (ref, arg) async => [_morningGi, _eveningNoGi],
        ),
        // Stub manage-gate providers so no network calls are made.
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        gymByIdProvider('g1').overrideWith(
          (_) async => const Gym(id: 'g1', name: 'Test Gym', address: '123 Main St'),
        ),
        rosterProvider('g1').overrideWith((_) async => <RosterMember>[]),
        currentUserIdProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: ClassScheduleScreen(
          gymId: 'g1',
          initialWeek: DateTime.utc(2026, 8, 3),
        ),
      ),
    ),
  );
  // Allow FutureProvider to resolve.
  await tester.pump();
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders both class titles', (tester) async {
    await _pump(tester);
    expect(find.text('Morning Gi'), findsOneWidget);
    expect(find.text('Evening NoGi'), findsOneWidget);
  });

  testWidgets('shows Cancelled indicator for cancelled occurrence',
      (tester) async {
    await _pump(tester);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('does not show Cancelled for active occurrence', (tester) async {
    await _pump(tester);
    // Only one Cancelled label — the active class has none.
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
