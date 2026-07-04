// E2E: anyone can add an open mat via the first-class "+" CTA, including adding
// a brand-new gym inline. The submission posts live (unverified) to the API.
//
// Run on a connected device/emulator with the API + MongoDB up:
//   flutter test integration_test/community_submission_test.dart \
//     -d emulator-5554 \
//     --dart-define=DEV_BYPASS=true \
//     --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3100
// (Or: bun run mobile:e2e:submit from the repo root.)
//
// The test drives the inline "add a new gym" path rather than the existing-gym
// picker: it's deterministic (no async gym-list load to wait on) and it exercises
// the core community feature — a contributor adding a gym + session in one go.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;

Future<bool> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('anyone can add an open mat (new gym) via the + CTA', (WidgetTester tester) async {
    app.main();

    // 1) Login (dev-bypass) -> home.
    expect(await pumpUntilFound(tester, find.text('Find your roll')), isTrue,
        reason: 'Did not reach home after login.');

    // 2) Tap the first-class center "+" CTA in the nav bar.
    expect(await pumpUntilFound(tester, find.byIcon(Icons.add)), isTrue,
        reason: 'The add (+) CTA was not found in the nav bar.');
    await tester.tap(find.byIcon(Icons.add).first);

    // 3) Create screen opens (its "Post Session" button is unique to it).
    expect(await pumpUntilFound(tester, find.text('Post Session')), isTrue,
        reason: 'Create screen did not open.');

    // 4) Switch to "add a new gym" (deterministic — no async gym list to await).
    final Finder addGym = find.text("Can't find your gym? Add it");
    expect(await pumpUntilFound(tester, addGym), isTrue,
        reason: 'The "add a gym" affordance was not found.');
    await tester.ensureVisible(addGym);
    await tester.tap(addGym);
    await tester.pump(const Duration(milliseconds: 300));

    // 5) Fill the required gym fields (located by their hint text).
    final Finder nameField = find.widgetWithText(TextField, 'e.g. Atos HQ');
    final Finder addrField = find.widgetWithText(TextField, '123 Main St');
    expect(await pumpUntilFound(tester, nameField), isTrue, reason: 'New-gym name field not shown.');
    await tester.enterText(nameField, 'E2E Community Gym');
    await tester.enterText(addrField, '500 Mat Street');
    await tester.pump(const Duration(milliseconds: 200)); // setState re-enables submit

    // 6) Submit -> success overlay.
    final Finder post = find.text('Post Session');
    await tester.ensureVisible(post);
    await tester.tap(post);
    expect(await pumpUntilFound(tester, find.text('Session posted!')), isTrue,
        reason: 'Submission did not succeed (no success overlay). Check POST /api/v1/open-mats.');
  });
}
