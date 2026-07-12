import { test, expect } from '@playwright/test';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

// Desktop pixel-diff regression against the delivered design reference.
//
// The site is now responsive, but the desktop (>=1024px) rendering is an exact
// preservation of the original Nocturne prototype port — all responsive rules
// live in `@media (max-width: ...)` blocks, so this pixel diff must continue to
// pass. The Angular build renders at ~0.77% vs the reference; the residual is
// web-font/blur/gradient antialiasing along edges, not a layout defect. The
// mobile reference (ref-mobile.png) is intentionally NO LONGER used — mobile is
// validated structurally in responsive.spec.ts.
const DESKTOP_THRESHOLD = 0.02;

test('landing matches the desktop design reference', async ({ page }, testInfo) => {
  await page.goto('/');
  // Let fonts + gradients settle.
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(400);

  const actualBuf = await page.screenshot({ fullPage: true });
  const expected = PNG.sync.read(readFileSync('reference/ref-desktop.png'));
  const actual = PNG.sync.read(actualBuf);

  // The reference screenshots were captured by a tool that reserved space for
  // a visible scrollbar, so they are a few px narrower than a Playwright
  // fullPage capture (which hides the scrollbar). Allow a small width delta
  // (scrollbar gutter) and compare over the shared min width/height region.
  const widthDelta = Math.abs(expected.width - actual.width);
  expect(widthDelta, `width delta ${widthDelta}px exceeds scrollbar tolerance`).toBeLessThanOrEqual(
    20,
  );
  const w = Math.min(expected.width, actual.width);
  const h = Math.min(expected.height, actual.height);
  const heightDelta = Math.abs(expected.height - actual.height);

  const diff = new PNG({ width: w, height: h });
  const crop = (src: PNG): PNG => {
    const out = new PNG({ width: w, height: h });
    for (let y = 0; y < h; y++) {
      src.data.copy(out.data, y * w * 4, y * src.width * 4, y * src.width * 4 + w * 4);
    }
    return out;
  };
  const e = crop(expected);
  const a = crop(actual);
  const mismatched = pixelmatch(e.data, a.data, diff.data, w, h, { threshold: 0.1 });
  const ratio = mismatched / (w * h);

  mkdirSync('test-results', { recursive: true });
  writeFileSync('test-results/diff-desktop.png', PNG.sync.write(diff));
  writeFileSync('test-results/actual-desktop.png', actualBuf);
  await testInfo.attach('diff-desktop', {
    path: 'test-results/diff-desktop.png',
    contentType: 'image/png',
  });

  // eslint-disable-next-line no-console
  console.log(
    `[desktop] mismatch ratio=${(ratio * 100).toFixed(2)}% heightDelta=${heightDelta}px (limit ${(DESKTOP_THRESHOLD * 100).toFixed(1)}%)`,
  );
  expect(ratio, `pixel mismatch ${(ratio * 100).toFixed(2)}%`).toBeLessThan(DESKTOP_THRESHOLD);
});
