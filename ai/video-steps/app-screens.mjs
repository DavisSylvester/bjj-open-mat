// Playwright-video steps: walk every main screen of the BJJ Open Mat web build
// (served at :8088 with DEV_BYPASS so the demo gym-owner is auto-authenticated),
// capturing any browser console / page errors along the way.
export const name = 'BJJ Open Mat — App Screens';

const BASE = 'http://localhost:4200';

// [label, hash-route]. Flutter web uses the default hash URL strategy, so a route
// like /search is reached at <base>/#/search.
const ROUTES = [
  ['Home / Discover', '/'],
  ['Search', '/search'],
  ['Profile', '/profile'],
  ['Edit profile', '/profile/edit'],
  ['Training history', '/profile/training'],
  ['Favorites', '/profile/favorites'],
  ['Report a bug / feature', '/report'],
  ['Owner dashboard', '/owner/dashboard'],
  ['My gyms', '/owner/gyms'],
  ['My sessions', '/owner/sessions'],
];

export async function steps(page) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console.error: ${m.text()}`);
  });

  // Boot the Flutter engine; DEV_BYPASS logs in the demo gym-owner and routes to
  // the owner dashboard. Give the engine + first API load time to settle.
  await page.goto(`${BASE}/#/`, { waitUntil: 'load' });
  await page.waitForTimeout(8000);

  for (const [label, route] of ROUTES) {
    // In-app fragment navigation — Flutter's router reacts to hashchange without a
    // full reload, so the walkthrough flows screen-to-screen.
    await page.evaluate((r) => { window.location.hash = `#${r}`; }, route);
    await page.waitForTimeout(3500); // let the screen render + linger for the video
    console.log(`visited: ${label} (#${route})`);
  }

  console.log(
    errors.length
      ? `\n⚠️ CONSOLE/PAGE ERRORS (${errors.length}):\n${[...new Set(errors)].join('\n')}`
      : '\n✅ No console/page errors captured across any screen.',
  );
}
