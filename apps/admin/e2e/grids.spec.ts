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

test('members grid shows every status', async ({ page }) => {
  await page.goto('/members');
  await expect(page.getByTestId('members-grid')).toBeVisible();
  const statuses = await page.getByTestId('member-status').allInnerTexts();
  expect(statuses).toContain('active');
  expect(statuses).toContain('hidden');
  expect(statuses).toContain('inactive');
});

test('hiding a member updates its status badge', async ({ page }) => {
  await page.goto('/members');
  // Pin the row by its fixture user id (mem-e2e-001 / user-e2e-001, seeded as
  // "active"). Filtering by status text instead would be unstable: the row
  // locator re-evaluates lazily, so once the click flips this row's status,
  // `.first()` would silently re-resolve to the OTHER seeded "active" row
  // (mem-e2e-004) instead of tracking the row we actually acted on.
  const row = page.getByTestId('member-row').filter({ hasText: 'user-e2e-001' });
  await row.getByTestId('member-hide').click();
  await expect(row.getByTestId('member-status')).toHaveText('hidden');
});

test('reactivating a member restores active', async ({ page }) => {
  await page.goto('/members');
  // mem-e2e-003 / user-e2e-003 is seeded as "inactive".
  const row = page.getByTestId('member-row').filter({ hasText: 'user-e2e-003' });
  await row.getByTestId('member-reactivate').click();
  await expect(row.getByTestId('member-status')).toHaveText('active');
});
