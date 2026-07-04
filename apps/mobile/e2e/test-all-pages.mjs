/**
 * DEPRECATED — this Playwright web suite has been removed.
 *
 * It no longer ran: it `require()`d Playwright from a hardcoded path in an
 * unrelated project, asserted UI strings that no longer exist, and drove the
 * Flutter *web* build where Auth0 login fails (Regular Web App used as SPA).
 *
 * The end-to-end coverage now lives in a Flutter integration test that runs on
 * a real device/emulator and exercises the actual widgets:
 *
 *   apps/mobile/integration_test/login_open_mat_detail_test.dart
 *     login (dev-bypass) -> tap an open-mat card -> land on the detail page
 *
 * Run it from the repo root:
 *
 *   bun run mobile:e2e
 *
 * or directly:
 *
 *   cd apps/mobile && flutter test integration_test/login_open_mat_detail_test.dart \
 *     -d <device-id> \
 *     --dart-define=DEV_BYPASS=true \
 *     --dart-define=AUTH_BYPASS_TOKEN=<api AUTH_BYPASS_SECRET> \
 *     --dart-define=API_BASE_URL=http://10.0.2.2:3100   # 10.0.2.2 = host, from an Android emulator
 */

console.log(
  [
    "This Playwright web E2E suite has been removed.",
    "",
    "End-to-end tests now run as a Flutter integration test:",
    "  apps/mobile/integration_test/login_open_mat_detail_test.dart",
    "",
    "Run:  bun run mobile:e2e",
  ].join("\n"),
);
