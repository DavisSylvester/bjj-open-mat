import { test, expect } from '@playwright/test';

// Responsive assertions for the mobile (390x844) and tablet (768x1024)
// projects. The site is intentionally responsive now, so these validate LAYOUT
// BEHAVIOUR rather than a pixel diff against the (non-responsive) ref-mobile.png.

interface Box {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
});

test('no horizontal overflow', async ({ page }, testInfo) => {
  const viewportWidth = testInfo.project.use.viewport?.width ?? 0;
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  // Allow a 1px rounding tolerance.
  expect(
    scrollWidth,
    `scrollWidth ${scrollWidth}px exceeds viewport ${viewportWidth}px`,
  ).toBeLessThanOrEqual(viewportWidth + 1);
});

test('hero is stacked (phone below the copy, not side-by-side)', async ({ page }, testInfo) => {
  // The 768px + 390px viewports are both below the 1024px stacking breakpoint.
  const viewportWidth = testInfo.project.use.viewport?.width ?? 0;
  expect(viewportWidth, 'responsive spec expects a sub-1024px viewport').toBeLessThan(1024);

  const hero = page.locator('#demo');
  await expect(hero).toBeVisible();

  // The hero grid should collapse to a single column.
  const gridCols = await hero.evaluate((el) => getComputedStyle(el).gridTemplateColumns);
  const trackCount = gridCols.trim().split(/\s+/).length;
  expect(trackCount, `hero has ${trackCount} grid tracks (${gridCols}); expected 1`).toBe(1);

  // And, structurally, the phone must sit BELOW the copy block.
  const copyBox = (await page.locator('#demo .hero-copy').boundingBox()) as Box | null;
  const phoneBox = (await page.locator('#demo .hero-phone').boundingBox()) as Box | null;
  expect(copyBox, 'hero copy box').not.toBeNull();
  expect(phoneBox, 'hero phone box').not.toBeNull();
  if (copyBox && phoneBox) {
    expect(
      phoneBox.y,
      `phone top ${phoneBox.y} should be below copy top ${copyBox.y}`,
    ).toBeGreaterThan(copyBox.y);
  }
});

test('key sections are present and visible', async ({ page }) => {
  await expect(page.locator('app-site-header nav')).toBeVisible();
  await expect(page.locator('#demo')).toBeVisible();
  await expect(page.locator('.stat-band')).toBeVisible();
  await expect(page.locator('#how')).toBeVisible();
  await expect(page.locator('#gyms')).toBeVisible();
  await expect(page.locator('#join')).toBeVisible();
  await expect(page.locator('.site-footer')).toBeVisible();
});

test('register-gym page has no horizontal overflow', async ({ page }, testInfo) => {
  const viewportWidth = testInfo.project.use.viewport?.width ?? 0;
  await page.goto('/register-gym');
  await page.waitForLoadState('networkidle');
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(
    scrollWidth,
    `register-gym scrollWidth ${scrollWidth}px exceeds viewport ${viewportWidth}px`,
  ).toBeLessThanOrEqual(viewportWidth + 1);
});
