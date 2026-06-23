// End-to-end test: log in (dev-bypass) -> tap an open-mat card -> land on the
// open-mat detail page.
//
// Run on a connected device/emulator:
//   flutter test integration_test/login_open_mat_detail_test.dart \
//     -d emulator-5554 \
//     --dart-define=DEV_BYPASS=true \
//     --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3100
//
// DEV_BYPASS + a non-empty AUTH_BYPASS_TOKEN make checkAuth() authenticate as
// the demo user without Auth0, so the app leaves splash/login and lands on the
// home (Discover) screen. The home and detail screens render from local stub
// data, so this test needs no live API.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;

/// Pumps frames (allowing real timers/animations to advance) until [finder]
/// matches at least one widget, or [timeout] elapses. We avoid
/// [WidgetTester.pumpAndSettle] because the app has continuous animations
/// (live dot, ticker strip) that never let the frame scheduler go idle.
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

  testWidgets(
    'login -> tap open mat -> lands on detail page',
    (WidgetTester tester) async {
      // Boot the real app (ProviderScope + router + auth bootstrap).
      app.main();

      // 1) LOGIN: dev-bypass auto-authenticates; wait for the home screen.
      final Finder home = find.text('Find your roll');
      expect(
        await pumpUntilFound(tester, home),
        isTrue,
        reason: 'Did not reach the home screen after login. Run with '
            '--dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<secret>.',
      );
      // We must have left the login screen.
      expect(find.text('Continue with email'), findsNothing);

      // 2) CLICK AN OPEN MAT: the first "Open Mats" card is Atos HQ.
      final Finder card = find.text('Atos HQ');
      expect(
        await pumpUntilFound(tester, card),
        isTrue,
        reason: 'No open-mat card found on the home screen.',
      );
      await tester.tap(card.first);

      // 3) LAND ON DETAIL: the detail screen shows the gym name in caps and a
      //    "Check In" CTA (present in both the Glass and Sport themes).
      final Finder detailTitle = find.text('ATOS HQ');
      expect(
        await pumpUntilFound(tester, detailTitle),
        isTrue,
        reason: 'Did not land on the open-mat detail page.',
      );
      expect(
        find.textContaining('Check In'),
        findsWidgets,
        reason: 'Detail page should show a Check In action.',
      );
    },
  );
}
