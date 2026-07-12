import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  webServer: {
    command: 'npx ng serve --port 4200 --configuration development',
    url: 'http://localhost:4200',
    reuseExistingServer: true,
    timeout: 180_000,
  },
  use: { baseURL: 'http://localhost:4200' },
  projects: [
    // Desktop keeps the pixel-diff regression against the delivered reference.
    {
      name: 'desktop',
      testMatch: /visual\.spec\.ts/,
      use: { viewport: { width: 1280, height: 900 } },
    },
    // Mobile is now RESPONSIVE (intentionally different from the old non-
    // responsive ref-mobile.png), so it asserts layout behaviour instead of a
    // pixel diff.
    {
      name: 'mobile',
      testMatch: /responsive\.spec\.ts/,
      use: { viewport: { width: 390, height: 844 } },
    },
    // Tablet only checks for horizontal overflow at the mid breakpoint.
    {
      name: 'tablet',
      testMatch: /responsive\.spec\.ts/,
      use: { viewport: { width: 768, height: 1024 } },
    },
    // Form-submission E2E: drives the lead-capture flows with the API stubbed
    // via page.route. Scoped to forms.e2e.spec.ts so it does not run under the
    // visual/responsive projects (and those do not run this file).
    {
      name: 'forms',
      testMatch: /forms\.e2e\.spec\.ts/,
      use: { viewport: { width: 1280, height: 900 } },
    },
  ],
});
