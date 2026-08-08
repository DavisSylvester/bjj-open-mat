import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  testMatch: /members-shots\.spec\.ts/,
  fullyParallel: false,
  workers: 1,
  reporter: 'line',
  webServer: [
    {
      command: 'bun e2e/serve-api-members.ts',
      url: 'http://localhost:3100/health',
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      command: 'bunx ng serve --port 4300 --configuration development',
      url: 'http://localhost:4300',
      reuseExistingServer: true,
      timeout: 180_000,
    },
  ],
  use: {
    baseURL: 'http://localhost:4300',
    // Denied, so the page exercises its documented fallback: plain
    // alphabetical order with nothing pre-expanded and no error surfaced.
    permissions: [],
  },
});
