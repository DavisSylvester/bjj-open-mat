import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';
import 'package:bjj_open_mat/features/checkins/data/check_in_request.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';
import 'package:bjj_open_mat/features/checkins/screens/check_in_form_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

class _FakeLoc implements LocationService {
  @override
  Future<CapturedLocation?> current() async =>
      const CapturedLocation(latitude: 32.9, longitude: -117.2, accuracyM: 7);
}

class _FakeAttendance implements AttendanceRepository {
  CreateCheckInRequest? captured;

  @override
  Future<List<CheckIn>> forSession(String openMatId, {String? date}) async => [];

  @override
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req) async {
    captured = req;
    return CheckIn(
      id: 'c1',
      openMatId: openMatId,
      userId: 'u',
      sessionDate: req.sessionDate,
      checkedInAt: 't',
      locationStatus: 'verified',
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('captures location, builds request, submits', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fakeRepo = _FakeAttendance();
    const mat = OpenMat(
      id: 'om1',
      gymId: 'g1',
      title: 'Fri Night',
      startTime: '19:00',
      endTime: '21:00',
      gymName: 'Atos HQ',
    );

    final router = GoRouter(
      initialLocation: '/open-mat/om1/checkin',
      routes: [
        GoRoute(
          path: '/open-mat/:id/checkin',
          builder: (context, state) =>
              CheckInFormScreen(openMatId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/open-mat/:id/checkin-success',
          builder: (context, state) => const Scaffold(body: Text('success')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLoc()),
        attendanceRepositoryProvider.overrideWithValue(fakeRepo),
        sessionByIdProvider('om1').overrideWith((ref) async => mat),
      ],
      child: MaterialApp.router(
        theme: AppTheme.glass(),
        routerConfig: router,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Atos HQ'), findsWidgets);
    await tester.enterText(
        find.widgetWithText(TextField, 'How did it go?'), 'great rounds');

    // Tap the submit button (GestureDetector wrapping the "Check In" container)
    final submitButton = find.ancestor(
      of: find.text('Check In').first,
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeRepo.captured, isNotNull);
    expect(fakeRepo.captured!.latitude, 32.9);
    expect(fakeRepo.captured!.note, 'great rounds');
  });
}
