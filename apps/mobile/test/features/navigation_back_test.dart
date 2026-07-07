import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/screens/gym_detail_screen.dart';

// These tests lock in the navigation-back contract fixed in the audit:
// list -> detail is a push, so the detail back arrow returns to the list;
// and a detail reached with no history (deep link) falls back to an explicit
// parent instead of dead-ending.

Widget _app(GoRouter router) => ProviderScope(
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('gym detail back returns to the list it was pushed from', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => c.push('/gym/g1'),
                child: const Text('OPEN GYM'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'gym/:id',
              builder: (c, s) => GymDetailScreen(gymId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.pump();

    // Enter the detail via push (as discover/search now do).
    await tester.tap(find.text('OPEN GYM'));
    await tester.pumpAndSettle();
    expect(find.text('ATOS HQ'), findsOneWidget);

    // Back arrow should pop back to the list.
    await tester.tap(find.byIcon(LucideIcons.arrowLeft).first);
    await tester.pumpAndSettle();
    expect(find.text('OPEN GYM'), findsOneWidget);
    expect(find.text('ATOS HQ'), findsNothing);
  });

  testWidgets('gym detail reached with no history falls back to / instead of dead-ending', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/gym/g1',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Center(child: Text('DISCOVER HOME'))),
          routes: [
            GoRoute(
              path: 'gym/:id',
              builder: (c, s) => GymDetailScreen(gymId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.text('ATOS HQ'), findsOneWidget);

    // canPop() is false here; the guarded handler must go('/') rather than no-op.
    await tester.tap(find.byIcon(LucideIcons.arrowLeft).first);
    await tester.pumpAndSettle();
    expect(find.text('DISCOVER HOME'), findsOneWidget);
  });

  testWidgets('owner attendance pushed from session admin backs to session admin', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Mirrors the real /owner/sessions/:id -> attendance shape: session admin
    // now pushes attendance, so the default AppBar back arrow returns to it.
    final router = GoRouter(
      initialLocation: '/owner/sessions/s1',
      routes: [
        GoRoute(
          path: '/owner/sessions/:id',
          builder: (c, s) => Scaffold(
            appBar: AppBar(title: const Text('SESSION ADMIN')),
            body: Center(
              child: TextButton(
                onPressed: () => c.push('/owner/sessions/${s.pathParameters['id']}/attendance'),
                child: const Text('VIEW ATTENDANCE'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'attendance',
              builder: (c, s) => Scaffold(
                appBar: AppBar(title: const Text('ATTENDANCE')),
                body: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VIEW ATTENDANCE'));
    await tester.pumpAndSettle();
    expect(find.text('ATTENDANCE'), findsOneWidget);

    // Default AppBar back button.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('SESSION ADMIN'), findsOneWidget);
  });
}
