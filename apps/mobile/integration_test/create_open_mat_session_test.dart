// End-to-end test: log in (dev-bypass) -> create a new open-mat session via the
// owner UI -> verify the new session shows up in the Sessions list.
//
// Requires the API + MongoDB running, reachable at API_BASE_URL, and the
// AUTH_BYPASS_TOKEN matching the API's AUTH_BYPASS_SECRET (the create POST and
// the list GET both hit the real backend).
//
// Run on a connected device/emulator:
//   flutter test integration_test/create_open_mat_session_test.dart \
//     -d emulator-5554 \
//     --dart-define=DEV_BYPASS=true \
//     --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3100
//
// (Or: bun run mobile:e2e:create from the repo root.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;

/// Pumps frames (letting real timers/animations/network advance) until [finder]
/// matches, or [timeout] elapses. We avoid pumpAndSettle because the app has
/// continuous animations that never let the frame scheduler go idle.
Future<bool> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The create form derives the title from the (default) Gi type "both".
  const String createdTitle = 'Gi & No-Gi Open Mat';

  testWidgets(
    'create open mat session -> it shows up in the Sessions list',
    (WidgetTester tester) async {
      app.main();

      // 1) LOGIN (dev-bypass) -> home.
      expect(
        await pumpUntilFound(tester, find.text('Find your roll')),
        isTrue,
        reason: 'Did not reach home after login. Run with DEV_BYPASS=true and a '
            'matching AUTH_BYPASS_TOKEN.',
      );

      // 2) Go to the owner Sessions list (demo user is a gym_owner). The list is
      //    only reachable by route from the practitioner shell, so navigate via
      //    go_router from a live context.
      final BuildContext ctx = tester.element(find.text('Find your roll'));
      // Fresh context from the live tree, used immediately (not stale) — the
      // lint guards against contexts held across awaits, which this isn't.
      // ignore: use_build_context_synchronously
      ctx.go('/owner/sessions');
      expect(
        await pumpUntilFound(tester, find.text('Sessions')),
        isTrue,
        reason: 'Owner Sessions screen did not load.',
      );
      // Wait for the list to finish loading (at least one session exists).
      await pumpUntilFound(tester, find.byType(ListTile));
      final int beforeCount = find.byType(ListTile).evaluate().length;

      // 3) Open the create form via the "+" FAB.
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      expect(
        await pumpUntilFound(tester, find.text('Post Session')),
        isTrue,
        reason: 'Create session screen did not open.',
      );

      // The submit button only enables once the owner's gyms have loaded and a
      // gym is auto-selected; wait for the "POSTING AS" gym to appear.
      expect(
        await pumpUntilFound(tester, find.text('Atos HQ')),
        isTrue,
        reason: 'Gym did not load on the create form (submit stays disabled).',
      );

      // 4) Submit with the form defaults.
      await tester.tap(find.text('Post Session'));
      expect(
        await pumpUntilFound(tester, find.text('Session posted!')),
        isTrue,
        reason: 'Create did not succeed (no success overlay).',
      );

      // 5) Dismiss the success overlay -> back to the Sessions list.
      await tester.tap(find.text('Done'));
      expect(
        await pumpUntilFound(tester, find.text('Sessions')),
        isTrue,
        reason: 'Did not return to the Sessions list.',
      );

      // 6) VERIFY: the newly created session is now in the list UI.
      expect(
        await pumpUntilFound(tester, find.text(createdTitle)),
        isTrue,
        reason: 'New session "$createdTitle" did not appear in the Sessions list.',
      );
      final int afterCount = find.byType(ListTile).evaluate().length;
      expect(
        afterCount,
        greaterThan(beforeCount),
        reason: 'Session count did not increase ($beforeCount -> $afterCount).',
      );
    },
  );
}
