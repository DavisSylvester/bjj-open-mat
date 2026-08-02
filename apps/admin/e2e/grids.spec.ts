import { test, expect } from '@playwright/test';

test('users grid has data', async ({ page }) => {
  await page.goto('/users');
  const grid = page.getByTestId('users-grid');
  await expect(grid).toBeVisible();
  await expect(page.getByTestId('user-row').first()).toBeVisible();
  expect(await page.getByTestId('user-row').count()).toBeGreaterThan(0);
});

test('gyms grid has data', async ({ page }) => {
  await page.goto('/gyms');
  const grid = page.getByTestId('gyms-grid');
  await expect(grid).toBeVisible();
  await expect(page.getByTestId('gym-row').first()).toBeVisible();
  expect(await page.getByTestId('gym-row').count()).toBeGreaterThan(0);
});
