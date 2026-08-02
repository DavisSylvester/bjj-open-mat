import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  testMatch: /grids\.spec\.ts/,
  fullyParallel: false,
  webServer: [
    {
      // Launcher: seeds bjj_admin_e2e DB then spawns the API.
      // All env vars (MONGODB_DB, WEBSITE_ORIGIN, etc.) are set inside the script.
      command: 'bun e2e/serve-api.ts',
      url: 'http://localhost:3100/health',
      reuseExistingServer: true,
      timeout: 120_000,
    },
    {
      command: 'bunx ng serve --port 4300 --configuration development',
      url: 'http://localhost:4300',
      reuseExistingServer: true,
      timeout: 180_000,
    },
  ],
  use: { baseURL: 'http://localhost:4300' },
});
