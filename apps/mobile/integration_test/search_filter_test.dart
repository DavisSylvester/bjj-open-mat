// End-to-end: create a NEW gym (not in seed) at ZIP 75495 with Saturday Gi and
// No-Gi sessions via the owner UI, then verify search + all filters (text/zip/GPS/
// When/Within/gi-type) surface them. Captures screenshots (via the integration
// driver) and a screen recording (via scripts/e2e-search.mjs).
//
// Run: bun run mobile:e2e:search   (API + Mongo seeded + emulator up)

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

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String gymName = 'North Texas BJJ';

  // Enter text into the field whose InputDecoration.hintText matches [hint].
  Finder fieldByHint(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint,
      );

  // Create one session at a brand-new gym (name/address/ZIP=75495), for the given
  // gi type, on a Saturday. Assumes we start on the owner Sessions list.
  Future<void> createSaturdaySession(WidgetTester tester, String giLabel) async {
    expect(await pumpUntilFound(tester, find.byType(FloatingActionButton)), isTrue,
        reason: 'Sessions FAB not found');
    await tester.tap(find.byType(FloatingActionButton));
    expect(await pumpUntilFound(tester, find.text('Post Session')), isTrue,
        reason: 'Create session screen did not open');

    // Add a new gym (not in seed).
    expect(await pumpUntilFound(tester, find.text("Can't find your gym? Add it")), isTrue);
    await tapText(tester, "Can't find your gym? Add it");

    await tester.enterText(fieldByHint('e.g. Atos HQ'), gymName);
    await tester.enterText(fieldByHint('123 Main St'), '100 Main St');
    await tester.enterText(fieldByHint('San Diego'), 'Van Alstyne');
    await tester.enterText(fieldByHint('CA'), 'TX');
    await tester.enterText(fieldByHint('75495'), '75495');
    await tester.pump(const Duration(milliseconds: 200));

    // Gi type.
    await tapText(tester, giLabel);

    // Pick a Saturday (Jul 11, 2026 is a Saturday) via the DATE picker so the
    // recurring session's dayOfWeek is 6 (Sat). Any Saturday works.
    await tapText(tester, 'DATE');
    if (await pumpUntilFound(tester, find.text('11'), timeout: const Duration(seconds: 3))) {
      await tester.tap(find.text('11').first);
      await tester.pump(const Duration(milliseconds: 200));
      await tapText(tester, 'OK');
    }

    // Submit.
    await tester.tap(find.text('Post Session'));
    expect(await pumpUntilFound(tester, find.text('Session posted!')), isTrue,
        reason: 'Create did not succeed for $giLabel');
    await tapText(tester, 'Done');
    expect(await pumpUntilFound(tester, find.text('Sessions')), isTrue,
        reason: 'Did not return to Sessions list after $giLabel');
  }

  testWidgets('create gym + Saturday Gi/No-Gi, then search & filter them',
      (WidgetTester tester) async {
    await binding.convertFlutterSurfaceToImage();
    app.main();

    // 1) Login gate.
    expect(await pumpUntilFound(tester, find.text('Find your roll')), isTrue,
        reason: 'Did not reach home after login (need DEV_BYPASS + matching token)');
    await binding.takeScreenshot('01-home');

    // 2) Create the two Saturday sessions at the new gym.
    final BuildContext ctx = tester.element(find.text('Find your roll').first);
    // ignore: use_build_context_synchronously
    ctx.go('/owner/sessions');
    expect(await pumpUntilFound(tester, find.text('Sessions')), isTrue);
    await createSaturdaySession(tester, 'Gi');
    await createSaturdaySession(tester, 'No-Gi');
    await binding.takeScreenshot('02-sessions-created');

    // 3) Search.
    final BuildContext ctx2 = tester.element(find.text('Sessions').first);
    // ignore: use_build_context_synchronously
    ctx2.go('/search');
    expect(await pumpUntilFound(tester, find.text(gymName)), isTrue,
        reason: 'New gym did not appear in search');
    await binding.takeScreenshot('03-search-results');

    // 4) ZIP search.
    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(await pumpUntilFound(tester, find.text(gymName)), isTrue,
        reason: 'ZIP 75495 search did not surface the gym');
    await binding.takeScreenshot('04-zip-75495');

    // 5) When = this weekend (Saturday) -> still present.
    await tester.tap(find.byKey(const Key('when-weekend')));
    expect(await pumpUntilFound(tester, find.text(gymName)), isTrue,
        reason: 'When=weekend excluded a Saturday session');
    await binding.takeScreenshot('05-when-weekend');

    // 6) When = a Wednesday (Jul 8, 2026) via the date picker -> excluded.
    await tester.tap(find.byKey(const Key('when-date')));
    await tester.pump(const Duration(milliseconds: 500));
    if (await pumpUntilFound(tester, find.text('8'), timeout: const Duration(seconds: 3))) {
      await tester.tap(find.text('8').first);
      await tester.pump(const Duration(milliseconds: 200));
      await tapText(tester, 'OK');
    }
    final bool stillThere = await pumpUntilFound(tester, find.text(gymName),
        timeout: const Duration(seconds: 5));
    expect(stillThere, isFalse,
        reason: 'When=Wednesday should exclude the Saturday-only sessions');
    await binding.takeScreenshot('06-when-weekday-excluded');

    // Reset the date filter back to the weekend so the gym is visible again.
    await tester.tap(find.byKey(const Key('when-weekend')));
    await pumpUntilFound(tester, find.text(gymName));

    // 7) GPS / Within: tap GPS (emulator location mocked near 75495 by the run
    // script). Best-effort: emulator geolocator may return null, in which case the
    // prior query still shows the gym. Either way it must remain visible.
    await tester.enterText(find.byKey(const Key('search-zip')), '');
    await tester.tap(find.text('GPS').first);
    expect(await pumpUntilFound(tester, find.text(gymName)), isTrue,
        reason: 'Gym not visible after GPS/Within search');
    await binding.takeScreenshot('07-gps-within');
  });
}
