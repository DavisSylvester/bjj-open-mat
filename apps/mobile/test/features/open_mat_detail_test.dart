import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';
import 'package:bjj_open_mat/features/checkins/data/review_repository.dart';
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
        // Avoid the unmocked reviews HTTP call leaving a pending timer after teardown.
        openMatReviewsProvider.overrideWith((ref, id) async => const []),
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

  testWidgets('shows the gym street address above the Directions button', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const mat = OpenMat(
      id: 'om10',
      gymId: 'g10',
      title: 'Open Mat',
      gymName: 'RM BJJ',
      startTime: '18:00',
      endTime: '20:00',
      city: 'Van Alstyne',
      state: 'TX',
      address: '123 Main St, Van Alstyne, TX 75495',
    );

    final router = GoRouter(
      initialLocation: '/open-mat/om10',
      routes: [
        GoRoute(
          path: '/open-mat/:id',
          builder: (context, state) => OpenMatDetailScreen(sessionId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionByIdProvider('om10').overrideWith((ref) async => mat),
        attendeesProvider.overrideWith((ref, q) async => const AttendeePage(items: [], total: 0)),
        openMatReviewsProvider.overrideWith((ref, id) async => const []),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // The full street address renders on the page, and the tappable location
    // row (used by directions) is present.
    expect(find.text('123 Main St, Van Alstyne, TX 75495'), findsOneWidget);
    expect(find.byKey(const Key('open-mat-location')), findsOneWidget);
  });

  testWidgets('falls back to City, State when no street address', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const mat = OpenMat(
      id: 'om11',
      gymId: 'g11',
      title: 'Open Mat',
      gymName: 'RM BJJ',
      startTime: '18:00',
      endTime: '20:00',
      city: 'Van Alstyne',
      state: 'TX',
    );

    final router = GoRouter(
      initialLocation: '/open-mat/om11',
      routes: [
        GoRoute(
          path: '/open-mat/:id',
          builder: (context, state) => OpenMatDetailScreen(sessionId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionByIdProvider('om11').overrideWith((ref) async => mat),
        attendeesProvider.overrideWith((ref, q) async => const AttendeePage(items: [], total: 0)),
        openMatReviewsProvider.overrideWith((ref, id) async => const []),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // No street address -> the location row still renders, using City, State.
    expect(find.byKey(const Key('open-mat-location')), findsOneWidget);
    expect(find.text('Van Alstyne, TX'), findsWidgets);
  });
}
