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
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 900 } } },
  ],
});
