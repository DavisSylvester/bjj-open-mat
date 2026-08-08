/**
 * Screenshot pass over the reworked Members page, for visual review.
 * Run from apps/admin with:
 *   bunx playwright test --config=playwright.members-shots.config.ts
 */
import { test, expect } from '@playwright/test';

const OUT = 'screenshots/members';

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1500, height: 1000 });
});

test('01 tree collapsed', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await expect(page.getByTestId('members-page')).toBeVisible();
  // The detected state expands asynchronously; geolocation is denied in this
  // context, so the tree settles into plain alphabetical order.
  await expect(page.getByTestId('state-group').first()).toBeVisible();
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${OUT}/01-tree-collapsed.png`, fullPage: true });
});

test('02 state expanded showing gyms', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /^TX/ }).click();
  await expect(page.getByTestId('gym-header').first()).toBeVisible();
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${OUT}/02-state-expanded.png`, fullPage: true });
});

test('03 roster with every badge and the switcher', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /^TX/ }).click();
  await page.getByRole('button', { name: /Renzo Gracie Dallas/ }).click();
  await expect(page.getByTestId('member-row').first()).toBeVisible();
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${OUT}/03-roster-badges-switcher.png`, fullPage: true });
});

test('04 roster close-up', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /^TX/ }).click();
  await page.getByRole('button', { name: /Renzo Gracie Dallas/ }).click();
  await expect(page.getByTestId('member-row').first()).toBeVisible();
  await page.waitForTimeout(600);
  const rows = page.locator('table').first();
  await rows.screenshot({ path: `${OUT}/04-roster-closeup.png` });
});

test('05 no-gym group expanded', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByTestId('no-gym-group').getByRole('button').first().click();
  await page.waitForTimeout(700);
  await page.screenshot({ path: `${OUT}/05-no-gym-group.png`, fullPage: true });
});

test('06 no-state group with an unknown gym', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /No State/ }).click();
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${OUT}/06-no-state-group.png`, fullPage: true });
});

test('07 status changed via the switcher', async ({ page }) => {
  await page.goto('/members', { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /^TX/ }).click();
  await page.getByRole('button', { name: /Renzo Gracie Dallas/ }).click();
  await expect(page.getByTestId('member-row').first()).toBeVisible();

  // Approve the pending member: clicking Active on a pending row IS the
  // approve action, and is the switcher's least obvious behaviour.
  const pendingRow = page.getByTestId('member-row').filter({ hasText: 'Devon Pass' });
  // `exact` matters: a substring match on "Active" also hits "Inactive".
  await pendingRow.getByRole('button', { name: 'Active', exact: true }).click();
  await page.waitForTimeout(900);
  await page.screenshot({ path: `${OUT}/07-pending-approved.png`, fullPage: true });
});
