// Smoke test: log in (dev-bypass) -> land on Discover -> confirm the always-on
// "Within 50 miles" gyms section renders. Prints an "E2ESHOT:<name>" marker that
// the run script (scripts/e2e-discover.mjs) turns into an adb screencap.
//
// Run: bun run mobile:e2e:discover   (API on 3100 seeded + emulator up)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;

Future<bool> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return false;
}

Future<void> shot(WidgetTester tester, String name, {int holdSeconds = 4}) async {
  // ignore: avoid_print
  print('E2ESHOT:$name');
  for (int i = 0; i < holdSeconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discover shows the "Within 50 miles" gyms section', (tester) async {
    app.main();

    expect(await pumpUntilFound(tester, find.text('Find your roll'), timeout: const Duration(seconds: 90)), isTrue,
        reason: 'Did not reach home after login (need DEV_BYPASS + matching token)');

    // The always-on nearby-gyms section (GPS mocked near 75495 by the run script).
    expect(await pumpUntilFound(tester, find.text('Within 50 miles'), timeout: const Duration(seconds: 30)), isTrue,
        reason: 'Discover did not show the "Within 50 miles" gyms section');

    await shot(tester, '01-discover-gyms-within-50mi');
  });
}
