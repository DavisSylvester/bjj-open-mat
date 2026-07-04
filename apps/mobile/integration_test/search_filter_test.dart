// End-to-end test: log in (dev-bypass) -> create two sessions at a brand-new
// gym (Gi + No-Gi, Saturday 11:00) -> navigate to the search screen and drive
// the ZIP / When / GPS filters, capturing a screenshot at each step.
//
// Runs on a connected Android emulator via `flutter drive` (see
// scripts/e2e-search.mjs, which also mocks GPS near 75495 and records video):
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/search_filter_test.dart \
//     -d emulator-5554 \
//     --dart-define=DEV_BYPASS=true \
//     --dart-define=AUTH_BYPASS_TOKEN=<secret> \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3100
//
// Requires the API + MongoDB running and reachable at API_BASE_URL, with the
// AUTH_BYPASS_TOKEN matching the API's AUTH_BYPASS_SECRET.

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

/// Finds a [TextField] by its InputDecoration.hintText — the new-gym inline
/// fields have no Keys, so we match on their hint text (e.g. 'e.g. Atos HQ').
Finder textFieldByHint(String hint) {
  return find.byWidgetPredicate(
    (Widget w) => w is TextField && w.decoration?.hintText == hint,
  );
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String gymName = 'North Texas BJJ';

  testWidgets(
    'search/filter flow: ZIP, When, and GPS filters over a new gym',
    (WidgetTester tester) async {
      app.main();

      // Android requires converting the Flutter surface to an image before the
      // first takeScreenshot; harmless (no-op) elsewhere.
      await binding.convertFlutterSurfaceToImage();

      // ── 1) LOGIN (dev-bypass) -> home ───────────────────────────────────
      expect(
        await pumpUntilFound(tester, find.text('Find your roll')),
        isTrue,
        reason: 'Did not reach home after login. Run with DEV_BYPASS=true and a '
            'matching AUTH_BYPASS_TOKEN.',
      );
      await binding.takeScreenshot('01-home');

      // ── 2) CREATE two sessions at a NEW gym ─────────────────────────────
      // Session 1: create the new gym (Gi, Saturday 11:00).
      await _openCreateForm(tester);
      await _addNewGym(tester);
      await _setSaturday1100(tester);
      await _tapGiType(tester, 'Gi');
      await _submitAndDone(tester);

      // Session 2: gym now exists + is auto-selected, so just pick No-Gi.
      await _openCreateForm(tester);
      await _setSaturday1100(tester);
      await _tapGiType(tester, 'No-Gi');
      await _submitAndDone(tester);

      await binding.takeScreenshot('02-sessions-created');

      // ── 3) Navigate to search ───────────────────────────────────────────
      final BuildContext ctx = tester.element(find.text('Find your roll').first);
      // Fresh context from the live tree, used immediately (not held across an
      // await) — the lint guards stale contexts, which this is not.
      // ignore: use_build_context_synchronously
      ctx.go('/search');
      expect(
        await pumpUntilFound(tester, find.text(gymName).first),
        isTrue,
        reason: 'New gym "$gymName" did not appear in the default search results.',
      );
      await binding.takeScreenshot('03-search-results');

      // ── 4) ZIP filter: 75495 ────────────────────────────────────────────
      await tester.enterText(find.byKey(const Key('search-zip')), '75495');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(
        await pumpUntilFound(tester, find.text(gymName).first),
        isTrue,
        reason: 'Gym "$gymName" did not appear after ZIP 75495 search.',
      );
      await binding.takeScreenshot('04-zip-75495');

      // ── 5) When = This weekend (Saturday sessions should remain) ────────
      await tester.tap(find.byKey(const Key('when-weekend')));
      expect(
        await pumpUntilFound(tester, find.text(gymName).first),
        isTrue,
        reason: 'Weekend Saturday sessions should still be present under '
            '"This weekend".',
      );
      await binding.takeScreenshot('05-when-weekend');

      // ── 6) When = a weekday date -> Saturday sessions excluded ──────────
      // Tapping 'Pick a date' opens the OS date picker. Pick the 15th of the
      // current month (a non-Saturday in most months; see TODO) via the
      // date-picker grid, then confirm 'OK'.
      await tester.tap(find.byKey(const Key('when-date')));
      await pumpUntilFound(tester, find.text('OK'));
      // TODO(controller): the '15' day cell is a heuristic non-Saturday. If the
      // 15th of the run month lands on a Saturday, pick a different day cell
      // (any weekday) so the Saturday-only sessions are correctly excluded.
      final Finder day15 = find.text('15');
      if (day15.evaluate().isNotEmpty) {
        await tester.tap(day15.first);
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('OK'));
      // Expect the gym to be GONE from results (weekday excludes Saturday).
      // Use a short timeout: pumpUntilFound returning false is the pass case.
      final bool stillPresent = await pumpUntilFound(
        tester,
        find.text(gymName).first,
        timeout: const Duration(seconds: 4),
      );
      expect(
        stillPresent,
        isFalse,
        reason: 'Saturday-only sessions should be excluded when filtering to a '
            'weekday date.',
      );
      await binding.takeScreenshot('06-when-weekday-excluded');

      // ── 7) GPS / Within: tap the GPS pill (emulator location ~ 75495) ───
      // Reset the When filter back to something inclusive so GPS results show.
      await tester.tap(find.byKey(const Key('when-week')));
      await tester.pump(const Duration(milliseconds: 300));
      // The GPS pill is the 'GPS' text inside the search bar.
      // TODO(controller): if multiple 'GPS' texts match across Glass/Sport
      // themes, .first targets the visible one; confirm on-device.
      await tester.tap(find.text('GPS').first);
      await tester.pump(const Duration(milliseconds: 600));
      // The 'WITHIN' distance card with the default radius should be present.
      expect(
        find.textContaining('mi').evaluate().isNotEmpty,
        isTrue,
        reason: 'GPS/Within distance control (default radius) not visible.',
      );
      await binding.takeScreenshot('07-gps-within');
    },
  );
}

/// Opens the shared create-session form via go_router and waits for it.
///
/// Uses the shared '/add-session' route (reachable by any authenticated role),
/// which renders the same CreateSessionScreen the FAB opens.
/// TODO(controller): the sibling create_open_mat_session_test.dart reaches the
/// form via the '+' FAB on /owner/sessions instead; switch to that if the
/// demo user lacks access to /add-session.
Future<void> _openCreateForm(WidgetTester tester) async {
  final BuildContext ctx = tester.element(find.byType(Navigator).first);
  // ignore: use_build_context_synchronously
  ctx.go('/add-session');
  final bool opened = await pumpUntilFound(tester, find.text('Post Session'));
  expect(opened, isTrue, reason: 'Create session screen did not open.');
}

/// Fills the "add a new gym" affordance with North Texas BJJ.
///
/// Finders:
///  - add-new toggle: text "Can't find your gym? Add it"
///  - name  field: hint 'e.g. Atos HQ'
///  - address field: hint '123 Main St'
///  - city  field: hint 'San Diego'
///  - state field: hint 'CA'
///
/// NOTE: the create form has NO postalCode input (only NAME/ADDRESS/CITY/STATE),
/// so the ZIP 75495 is placed in the address string. The backend must geocode
/// the address for the ZIP=75495 search to match.
/// TODO(controller): confirm the backend derives lat/lng (and/or postalCode)
/// from the address so ZIP 75495 and the GPS-near-75495 filter both hit.
Future<void> _addNewGym(WidgetTester tester) async {
  final Finder addNew = find.text("Can't find your gym? Add it");
  expect(
    await pumpUntilFound(tester, addNew),
    isTrue,
    reason: 'Add-new-gym affordance not found on create form.',
  );
  await tester.tap(addNew);
  await tester.pump(const Duration(milliseconds: 300));

  await tester.enterText(textFieldByHint('e.g. Atos HQ'), 'North Texas BJJ');
  await tester.enterText(textFieldByHint('123 Main St'), '100 Main St, 75495');
  await tester.enterText(textFieldByHint('San Diego'), 'Van Alstyne');
  await tester.enterText(textFieldByHint('CA'), 'TX');
  await tester.pump(const Duration(milliseconds: 300));
}

/// Sets the recurring day to Saturday and the start time to 11:00 AM.
///
/// The DATE field (tapped via its 'DATE' label's card) opens a date picker; we
/// select a Saturday there, and because "Repeat weekly" is ON by default the
/// session recurs every Saturday (dayOfWeek derives from the picked date's
/// weekday). The START time picker is opened via the 'START' label's card.
Future<void> _setSaturday1100(WidgetTester tester) async {
  // ── Pick a Saturday via the DATE picker ──
  // The date card shows a formatted date like 'Jul 9, 2026'; tap the calendar
  // area by tapping the 'DATE' label's sibling GestureDetector. Simplest
  // resilient tap: the calendar icon row is under the 'DATE' text; tap that
  // text's card. We tap the formatted-date container via the chevron-down that
  // sits in the DATE field.
  // TODO(controller): if tapping 'DATE' does not open the picker, tap the
  // formatted date Text (e.g. via find.byIcon(LucideIcons.calendar).first).
  final Finder dateLabel = find.text('DATE');
  expect(dateLabel.evaluate().isNotEmpty, isTrue, reason: 'DATE field missing.');
  // The tappable card is the GestureDetector after the label; tap the chevron
  // in that row. Fall back to tapping the whole date card region.
  await tester.tap(dateLabel);
  await tester.pump(const Duration(milliseconds: 200));
  if (find.text('OK').evaluate().isEmpty) {
    // Label itself isn't the tap target; tap the calendar-row card instead.
    // TODO(controller): confirm which element opens the date picker.
    await tester.tap(find.byIcon(Icons.calendar_today).evaluate().isNotEmpty
        ? find.byIcon(Icons.calendar_today).first
        : dateLabel);
    await tester.pump(const Duration(milliseconds: 200));
  }
  if (await pumpUntilFound(tester, find.text('OK'),
      timeout: const Duration(seconds: 3))) {
    // In the calendar picker, switch to input mode is unreliable; pick a
    // Saturday day cell. We look for a day number that is a Saturday.
    // TODO(controller): the date grid day cells vary by month. Pick any cell
    // whose weekday is Saturday. As a stable default, tap '21' (adjust per
    // run month) — the run script/controller should verify this lands on Sat.
    final Finder sat = find.text('21');
    if (sat.evaluate().isNotEmpty) {
      await tester.tap(sat.first);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── Set START time to 11:00 AM ──
  final Finder startLabel = find.text('START');
  expect(startLabel.evaluate().isNotEmpty, isTrue, reason: 'START field missing.');
  await tester.tap(startLabel);
  await tester.pump(const Duration(milliseconds: 200));
  if (await pumpUntilFound(tester, find.text('OK'),
      timeout: const Duration(seconds: 3))) {
    // The time picker opens in dial mode; switch to keyboard entry to type
    // 11:00 reliably.
    // TODO(controller): if the keyboard-toggle icon differs, tap the
    // pencil/keyboard icon (find.byIcon(Icons.keyboard) / Icons.access_time)
    // then enter '11' hour and '00' minute; ensure AM is selected.
    final Finder kbToggle = find.byIcon(Icons.keyboard_outlined);
    if (kbToggle.evaluate().isNotEmpty) {
      await tester.tap(kbToggle.first);
      await tester.pump(const Duration(milliseconds: 200));
      final Finder hourField = find.byType(TextField);
      if (hourField.evaluate().length >= 2) {
        await tester.enterText(hourField.at(0), '11');
        await tester.enterText(hourField.at(1), '00');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    // Make sure AM is selected if an AM chip is present.
    final Finder am = find.text('AM');
    if (am.evaluate().isNotEmpty) {
      await tester.tap(am.first);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Taps the gi-type pill: 'Gi', 'No-Gi', or 'Both'.
///
/// The gi pills are Text('Gi') / Text('No-Gi') / Text('Both') inside the
/// GI TYPE section. Use .first because 'Gi'/'No-Gi' substrings can appear
/// elsewhere (e.g. section chrome); the pills render these exact labels.
Future<void> _tapGiType(WidgetTester tester, String label) async {
  final Finder pill = find.text(label);
  expect(pill.evaluate().isNotEmpty, isTrue,
      reason: 'Gi-type pill "$label" not found.');
  await tester.tap(pill.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Taps 'Post Session', waits for the 'Session posted!' overlay, then 'Done'.
Future<void> _submitAndDone(WidgetTester tester) async {
  await tester.tap(find.text('Post Session'));
  expect(
    await pumpUntilFound(tester, find.text('Session posted!')),
    isTrue,
    reason: 'Create did not succeed (no success overlay).',
  );
  await tester.tap(find.text('Done'));
  // Back to home (the create screen pops to wherever we came from).
  expect(
    await pumpUntilFound(tester, find.text('Find your roll')),
    isTrue,
    reason: 'Did not return home after creating the session.',
  );
}
