import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';
import 'package:bjj_open_mat/features/open_mats/data/rsvp_repository.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';
import 'package:bjj_open_mat/features/open_mats/screens/open_mat_detail_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders the real session, not the static stub', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const mat = OpenMat(
      id: 'om9',
      gymId: 'g9',
      title: 'Sunday Rolls',
      gymName: 'Gracie Barra Austin',
      startTime: '10:00',
      endTime: '12:00',
      giType: 'nogi',
      skillLevel: 'beginner',
      city: 'Austin',
      state: 'TX',
      feeCents: 2000,
      gymRating: 4.5,
      description: 'Great mats and a friendly crew.',
    );

    final router = GoRouter(
      initialLocation: '/open-mat/om9',
      routes: [
        GoRoute(
          path: '/open-mat/:id',
          builder: (context, state) => OpenMatDetailScreen(sessionId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionByIdProvider('om9').overrideWith((ref) async => mat),
        attendeesProvider.overrideWith((ref, q) async => const AttendeePage(items: [], total: 0)),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300)); // resolve the future

    // Real data — not the hardcoded "ATOS HQ" / "Los Angeles, CA" stub.
    expect(find.textContaining('Gracie Barra Austin', findRichText: true), findsWidgets);
    expect(find.text('Austin, TX'), findsWidgets);
    expect(find.text('\$20'), findsWidgets);
    expect(find.textContaining('Great mats and a friendly crew.'), findsOneWidget);
    expect(find.textContaining('World-class facility'), findsNothing);
  });
}
