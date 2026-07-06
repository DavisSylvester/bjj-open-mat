// Screen-capture harness: deterministically walks the app and screenshots each
// screen (written to build/e2e/*.png by test_driver/integration_test.dart).
// Every step is guarded so one missing finder never aborts the whole sweep.
//
// Run (practitioner bypass, local API):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screens_capture_test.dart -d <device> \
//     --dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<secret> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:3100

import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;
import 'package:bjj_open_mat/shared/widgets/session_row.dart';

Future<bool> pumpUntilFound(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture practitioner screens', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    app.main();

    Future<void> settle([int ms = 700]) async => tester.pump(Duration(milliseconds: ms));
    // Before a screenshot, let any route-push transition finish so we don't
    // capture a mid-transition (blank) frame; bounded so a perpetual
    // animation can't hang the sweep.
    Future<void> shot(String name) async {
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      } catch (_) {
        await settle();
      }
      await binding.takeScreenshot(name);
    }

    // Guarded tap on the first match of a finder; returns whether it tapped.
    Future<bool> tapIf(Finder f, {String? reason}) async {
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await settle();
        return true;
      }
      return false;
    }

    // 1) Home
    await pumpUntilFound(tester, find.text('Find your roll'));
    await shot('cap-01-home');

    // 2) Open-mat detail (tap first session card) then back
    try {
      if (await tapIf(find.byType(SessionRow))) {
        await pumpUntilFound(tester, find.text('About'), timeout: const Duration(seconds: 6));
        await shot('cap-02-detail');
        await tester.pageBack();
        await settle();
      }
    } catch (_) {}

    // 3) Search / Find tab
    try {
      await tapIf(find.text('Find'));
      await pumpUntilFound(tester, find.text('Find a Mat'), timeout: const Duration(seconds: 6));
      await shot('cap-03-search');
    } catch (_) {}

    // 4) Schedule / My Training
    try {
      await tapIf(find.text('Schedule'));
      await shot('cap-04-schedule');
    } catch (_) {}

    // 5) Profile
    try {
      await tapIf(find.text('Profile'));
      await pumpUntilFound(tester, find.text('Settings'), timeout: const Duration(seconds: 6));
      await shot('cap-05-profile');
    } catch (_) {}

    // 6) Settings (gear icon on Profile)
    try {
      if (await tapIf(find.byIcon(LucideIcons.settings))) {
        await shot('cap-06-settings');
        await tester.pageBack();
        await settle();
      }
    } catch (_) {}

    // 7) Notifications (bell icon on Profile)
    try {
      if (await tapIf(find.byIcon(LucideIcons.bell))) {
        await shot('cap-07-notifications');
        await tester.pageBack();
        await settle();
      }
    } catch (_) {}

    // 8) Edit Profile (Account row on Profile → /profile/edit)
    try {
      if (await tapIf(find.text('Account'))) {
        await pumpUntilFound(tester, find.text('Edit Profile'), timeout: const Duration(seconds: 6));
        await shot('cap-08-edit-profile');
        await tester.pageBack();
        await settle();
      }
    } catch (_) {}
  });
}
