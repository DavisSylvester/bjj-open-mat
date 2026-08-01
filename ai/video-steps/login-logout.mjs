// Playwright-video steps: a real Auth0 login → app → logout round-trip for the
// BJJ Open Mat web build, using the local test account (test-user@local.priv).
//
// The web build is served (no DEV_BYPASS) on http://localhost:4200, so it boots
// to the login screen. The login screen is Flutter CanvasKit (no DOM buttons), so
// its buttons are driven by enabling Flutter's semantics tree and clicking the
// semantics nodes; the Auth0 Universal Login page is normal HTML (filled by
// selector). Credentials are read from a temp file OUTSIDE the repo so they never
// touch source or a command line.
import { readFileSync } from 'node:fs';

export const name = 'BJJ Open Mat — Login and Logout';

const creds = JSON.parse(readFileSync(process.env.TEMP + '/_bjj_video_creds.json', 'utf8'));
const EMAIL = creds.email;
const PASSWORD = creds.password;
const BASE = 'http://localhost:4200';

// Flutter web only builds its accessible DOM (flt-semantics[role="button"] nodes)
// after the hidden "Enable accessibility" placeholder is activated. Each full page
// load resets it, so re-enable on every Flutter screen.
async function enableSemantics(page) {
  await page.evaluate(() => { const ph = document.querySelector('flt-semantics-placeholder'); if (ph) ph.click(); });
  await page.waitForTimeout(700);
}

export async function steps(page) {
  // 1. Boot the login screen (no DEV_BYPASS → starts unauthenticated).
  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(9000); // Flutter engine boot + first paint
  await enableSemantics(page);
  await page.waitForTimeout(2500); // linger on the 6 social/email login buttons

  // 2. Tap "Continue with email" (the 6th/last button on the login screen) to
  //    launch Auth0 Universal Login.
  await page.evaluate(() => {
    const b = document.querySelectorAll('flt-semantics[role="button"]');
    if (b.length >= 6) b[5].click();
  });
  await page.waitForURL(/auth0\.com/, { timeout: 25000 });
  await page.waitForTimeout(2000);

  // 3. Auth0 hosted login form (HTML). fill()/click() are auto-paced 2s each.
  await page.fill('#username', EMAIL);
  await page.fill('#password', PASSWORD);
  await page.click('button[name="action"][value="default"]');

  // 4. First-time authorizations may show a consent screen; accept if present.
  await page.waitForTimeout(4000);
  if (/\/u\/consent/.test(page.url()) || (await page.locator('button:has-text("Accept")').count()) > 0) {
    await page.click('button:has-text("Accept")');
  }

  // 5. Back in the app, authenticated. Let the code→token exchange + first data
  //    load settle, then linger on the home screen.
  await page.waitForURL(/localhost:4200/, { timeout: 25000 });
  await page.waitForTimeout(9000);
  await enableSemantics(page);
  await page.waitForTimeout(3000);

  // 6. Open the Profile screen (where Sign out lives).
  await page.evaluate(() => { window.location.hash = '#/profile'; });
  await page.waitForTimeout(4500);
  await enableSemantics(page);
  await page.waitForTimeout(2500); // linger showing the profile + Settings list

  // 7. Tap "Sign out" — the 5th full-width Settings row (My Training,
  //    Notifications, Account, Switch to Student, Sign out, Delete Account).
  await page.evaluate(() => {
    const rows = [...document.querySelectorAll('flt-semantics[role="button"]')]
      .map((n) => ({ n, r: n.getBoundingClientRect() }))
      .filter((o) => o.r.width > 1000)
      .sort((a, b) => a.r.top - b.r.top);
    if (rows[4]) rows[4].n.click(); // Sign out
  });

  // 8. Logout redirects through Auth0 and returns to the login screen.
  await page.waitForTimeout(9000);
  await enableSemantics(page);
  await page.waitForTimeout(3000); // linger back on the login screen

  console.log('login/logout flow complete; final url =', page.url());
}
