// End-to-end: search for the "RM BJJ" open mat, open its detail page, and tap
// the gym's address/location row to launch directions in the platform maps app.
//
// Screenshots are captured by the run script (scripts/e2e-location.mjs) via
// `adb screencap`, NOT binding.takeScreenshot — the latter returns blank frames
// under Impeller and throws PixelCopy errors on this emulator. The test prints a
// unique "E2ESHOT:<name>" marker to logcat at each capture point and then holds
// briefly (real wall-clock time) so the run script can grab the current screen.
//
// Run: bun run mobile:e2e:location   (API + Mongo seeded with RM BJJ + emulator up)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// Pumps frames while letting [seconds] of real wall-clock time pass, so the
/// run script's adb screencap can capture the currently-rendered screen.
Future<void> hold(WidgetTester tester, {int seconds = 3}) async {
  for (int i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Signals the run script to screencap into `build/e2e/<name>.png`, then holds so
/// the capture lands on this frame.
Future<void> shot(WidgetTester tester, String name, {int holdSeconds = 3}) async {
  // Relayed to the `flutter test` host stdout, where the run script sees it and
  // fires an adb screencap. Using print (not debugPrint) to avoid any throttling.
  // ignore: avoid_print
  print('E2ESHOT:$name');
  await hold(tester, seconds: holdSeconds);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // "RM BJJ" is the colloquial name; the seeded gym is "RM Elite Brazilian Jiu-Jitsu".
  const String gymName = 'RM Elite Brazilian Jiu-Jitsu';

  testWidgets('search RM BJJ -> open detail -> tap location -> directions',
      (WidgetTester tester) async {
    app.main();

    // 1) Login gate (dev-bypass auto-authenticates).
    expect(await pumpUntilFound(tester, find.text('Find your roll'), timeout: const Duration(seconds: 90)), isTrue,
        reason: 'Did not reach home after login (need DEV_BYPASS + matching token)');

    // 2) Go to Search and query by ZIP 75495 (RM BJJ's area; GPS is also mocked
    //    near there by the run script).
    final BuildContext ctx = tester.element(find.text('Find your roll').first);
    // ignore: use_build_context_synchronously
    ctx.go('/search');
    expect(await pumpUntilFound(tester, find.byKey(const Key('search-zip'))), isTrue,
        reason: 'Search screen did not open');
    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // 3) Find the RM BJJ session row and open its detail page.
    expect(await pumpUntilFound(tester, find.textContaining(gymName)), isTrue,
        reason: 'RM BJJ did not appear in search results (is it seeded?)');
    await shot(tester, '01-search-rm-bjj');
    await tester.tap(find.textContaining(gymName).first);

    // 4) Land on the detail page and confirm the gym street address renders.
    expect(await pumpUntilFound(tester, find.byKey(const Key('open-mat-location'))), isTrue,
        reason: 'Detail page did not show the location row');
    expect(find.textContaining('203 Bear Rd'), findsOneWidget,
        reason: 'Detail page did not show the seeded street address');
    await shot(tester, '02-detail-with-address', holdSeconds: 4);

    // 5) Tap the location row -> launches directions in the platform maps app.
    //    This backgrounds our app, so we must NOT keep pumping frames (pumping a
    //    backgrounded engine hangs the test until timeout). Print the marker and
    //    wait real wall-clock time (no pump) so the run script can screencap the
    //    maps window, then let the test complete.
    await tester.tap(find.byKey(const Key('open-mat-location')));
    // ignore: avoid_print
    print('E2ESHOT:03-directions-launched');
    await Future<void>.delayed(const Duration(seconds: 8));
  });
}
