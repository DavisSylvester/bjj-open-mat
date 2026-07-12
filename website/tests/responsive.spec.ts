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

// Required target-device CSS viewport widths (see the responsive-hardening
// brief). Phones first, then tablets. 360 (Samsung S22) is the narrowest and
// most likely to reveal overflow. 1024 (iPad Pro 12.9") intentionally falls
// into the desktop layout and is not swept here.
const TARGET_WIDTHS: readonly number[] = [
  360, // Samsung S22 (narrowest)
  384, // Samsung S22 Ultra
  393, // iPhone 15 / 15 Pro
  412, // Pixel 7 / 8 / 9
  430, // iPhone 15 Plus / Pro Max
  768, // iPad mini
  820, // iPad Air
  834, // iPad Pro 11"
];

const ROUTES: readonly string[] = ['/', '/register-gym'];

async function settle(page: import('@playwright/test').Page): Promise<void> {
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(150);
}

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await settle(page);
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
  await settle(page);
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(
    scrollWidth,
    `register-gym scrollWidth ${scrollWidth}px exceeds viewport ${viewportWidth}px`,
  ).toBeLessThanOrEqual(viewportWidth + 1);
});

// ── Target-device sweep ────────────────────────────────────────────────────
// Data-driven: for every required device width, assert NO horizontal overflow
// on BOTH routes. Driven by page.setViewportSize inside the test so we don't
// multiply Playwright projects. Runs once (under the `mobile` project) — gated
// so the identical sweep is not duplicated under `tablet`.
test('no horizontal overflow across all target device widths', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'mobile', 'device sweep runs once, under the mobile project');

  const failures: string[] = [];

  for (const route of ROUTES) {
    for (const width of TARGET_WIDTHS) {
      await page.setViewportSize({ width, height: 900 });
      await page.goto(route);
      await settle(page);

      const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
      const innerWidth = await page.evaluate(() => window.innerWidth);
      // scrollWidth must never exceed the viewport (1px rounding tolerance).
      if (scrollWidth > innerWidth + 1) {
        failures.push(
          `${route} @ ${width}px: scrollWidth ${scrollWidth} > innerWidth ${innerWidth}`,
        );
      }
    }
  }

  expect(failures, `horizontal overflow detected:\n${failures.join('\n')}`).toEqual([]);
});
