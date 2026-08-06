// End-to-end: switch the search screen into Gyms mode, search by ZIP, and
// verify gym cards render. This deliberately does NOT assert the radius-
// widening notice — search_filter_test.dart creates a gym named
// "North Texas BJJ" at ZIP 75495, so in any environment where that test has
// run there IS a gym within 25 miles and the search will not widen. Widening
// is already proven deterministically by the API-level E2E
// (apps/api/test/gym-search.e2e.test.mts). This test's job is the UI wiring
// only: the toggle switches modes, a ZIP drives a gym query, and gym cards
// render.
//
// Run: bun run mobile:e2e:gyms   (API + Mongo seeded + emulator up)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;
import 'package:bjj_open_mat/shared/widgets/nearby_gym_card.dart';

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

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gyms mode searches by ZIP and renders gym cards', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    app.main();

    // 1) Login gate.
    expect(await pumpUntilFound(tester, find.text('Find your roll')), isTrue,
        reason: 'Did not reach home after login (need DEV_BYPASS + matching token)');

    // Navigate to the Find tab, then switch to Gyms mode.
    await tapText(tester, 'Find');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-mode-toggle')).last);
    await tester.pumpAndSettle();

    // Open-mat-only chips must disappear in Gyms mode.
    expect(find.text('Gi'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    final found = await pumpUntilFound(
      tester,
      find.byType(NearbyGymCard),
      timeout: const Duration(seconds: 20),
    );
    expect(found, isTrue, reason: 'expected at least one gym near ZIP 75495');
  });
}
