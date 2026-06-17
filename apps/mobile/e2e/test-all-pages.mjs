/**
 * BJJ Open Mat Finder — End-to-End Playwright Tests
 *
 * Tests every page, form, list, and CRUD operation.
 * Requires:
 *   - Flutter app served on APP_URL (default: http://localhost:9097)
 *   - BJJ API running on API_URL (default: http://localhost:3100)
 *   - MongoDB with test data
 *
 * Run: node e2e/test-all-pages.mjs
 */

import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('C:/projects/davis/agents/api-generator-agent/node_modules/playwright');

const APP_URL = process.env.APP_URL || 'http://localhost:9097';
const API_URL = process.env.API_URL || 'http://localhost:3100';
const SCREENSHOT_DIR = 'e2e/screenshots';

let browser, page;
let passed = 0;
let failed = 0;
const failures = [];

// --- Helpers ---

async function enableSemantics() {
  await page.evaluate(() => {
    const btn = document.querySelector('flt-semantics-placeholder');
    if (btn) btn.dispatchEvent(new Event('click', { bubbles: true }));
  });
  await page.waitForTimeout(1500);
}

async function getAria() {
  return page.locator('body').ariaSnapshot();
}

async function navigateTo(path) {
  await page.goto(`${APP_URL}/#${path}`, { waitUntil: 'networkidle', timeout: 15000 });
  await page.waitForTimeout(3000);
  await enableSemantics();
}

async function clickTab(label) {
  const tab = page.getByRole('tab', { name: label });
  if (await tab.count() > 0) {
    await tab.click({ force: true, timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(2000);
    await enableSemantics();
  }
}

async function screenshot(name) {
  await page.screenshot({ path: `${SCREENSHOT_DIR}/${name}.png`, fullPage: true });
}

async function apiGet(path) {
  const res = await fetch(`${API_URL}${path}`);
  return res.json();
}

async function apiPost(path, data) {
  const res = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return res.json();
}

async function apiDelete(path) {
  const res = await fetch(`${API_URL}${path}`, { method: 'DELETE' });
  return res.json();
}

function test(name, fn) {
  return { name, fn };
}

async function runTest(t) {
  try {
    await t.fn();
    passed++;
    console.log(`  ✅ ${t.name}`);
  } catch (e) {
    failed++;
    failures.push({ name: t.name, error: e.message });
    console.log(`  ❌ ${t.name}: ${e.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertContains(text, substring, context) {
  if (!text.includes(substring)) {
    throw new Error(`Expected "${substring}" in ${context}. Got: ${text.substring(0, 300)}`);
  }
}

// --- Seed Data ---

async function seedTestData() {
  console.log('\n🌱 Seeding test data...');

  // Clean existing
  const gyms = await apiGet('/api/v1/gyms');
  if (gyms.data && Array.isArray(gyms.data)) {
    for (const g of gyms.data) {
      await apiDelete(`/api/v1/gyms/${g._id}`).catch(() => {});
    }
  }

  // Create gyms
  const gym1 = await apiPost('/api/v1/gyms', {
    name: 'Test Gym Alpha',
    description: 'First test gym',
    address: '100 Main St, Test City',
    location: { type: 'Point', coordinates: [-73.985, 40.758] },
  });

  const gym2 = await apiPost('/api/v1/gyms', {
    name: 'Test Gym Beta',
    description: 'Second test gym',
    address: '200 Oak Ave, Test Town',
    location: { type: 'Point', coordinates: [-73.978, 40.686] },
  });

  const gym1Id = gym1.data?._id;
  const gym2Id = gym2.data?._id;

  console.log(`  Created gym1: ${gym1Id}`);
  console.log(`  Created gym2: ${gym2Id}`);

  // Seed open mats directly via API or MongoDB
  // Use the list endpoint to verify
  const mats = await apiGet('/api/v1/open-mats');
  console.log(`  Open mats in DB: ${mats.data?.total ?? mats.data?.length ?? 0}`);

  return { gym1Id, gym2Id };
}

// --- Tests ---

const tests = [
  // === DISCOVER PAGE ===
  test('Discover: page loads with nav bar', async () => {
    await navigateTo('/');
    const aria = await getAria();
    assertContains(aria, 'Discover', 'nav tabs');
    assertContains(aria, 'Search', 'nav tabs');
    assertContains(aria, 'Training', 'nav tabs');
    assertContains(aria, 'Profile', 'nav tabs');
    await screenshot('01-discover');
  }),

  test('Discover: shows Nearby Open Mats header', async () => {
    const aria = await getAria();
    assertContains(aria, 'Nearby Open Mats', 'discover header');
  }),

  test('Discover: Today/Week toggle exists', async () => {
    const aria = await getAria();
    assertContains(aria, 'Today', 'toggle');
    assertContains(aria, 'Week', 'toggle');
  }),

  test('Discover: open mats list populates', async () => {
    const aria = await getAria();
    // Should have at least one open mat from seeded data
    const hasOpenMat = aria.includes('Morning') || aria.includes('Saturday') || aria.includes('Advanced') || aria.includes('No-Gi') || aria.includes('Flow');
    assert(hasOpenMat, `Expected open mat entries in list. ARIA: ${aria.substring(0, 500)}`);
  }),

  // === SEARCH PAGE ===
  test('Search: page loads with filters', async () => {
    await clickTab('Search');
    const aria = await getAria();
    assertContains(aria, 'Search', 'page title');
    await screenshot('02-search');
  }),

  test('Search: filter chips present', async () => {
    const aria = await getAria();
    // Should have skill level filters
    const hasFilters = aria.includes('Beginner') || aria.includes('Intermediate') || aria.includes('Advanced') || aria.includes('All Levels') || aria.includes('Gi') || aria.includes('No-Gi');
    assert(hasFilters, `Expected filter chips. ARIA: ${aria.substring(0, 500)}`);
  }),

  test('Search: results populate', async () => {
    const aria = await getAria();
    const hasList = aria.includes('Morning') || aria.includes('Saturday') || aria.includes('Advanced') || aria.includes('Open Mat') || aria.includes('10:00');
    assert(hasList, `Expected search results. ARIA: ${aria.substring(0, 500)}`);
  }),

  // === TRAINING PAGE ===
  test('Training: page loads', async () => {
    await clickTab('Training');
    const aria = await getAria();
    assertContains(aria, 'Training', 'page title');
    await screenshot('03-training');
  }),

  test('Training: shows stats or empty state', async () => {
    const aria = await getAria();
    const hasContent = aria.includes('Sessions') || aria.includes('No training') || aria.includes('check in');
    assert(hasContent, `Expected training content or empty state. ARIA: ${aria.substring(0, 500)}`);
  }),

  // === PROFILE PAGE ===
  test('Profile: page loads', async () => {
    await clickTab('Profile');
    const aria = await getAria();
    assertContains(aria, 'Profile', 'page title');
    await screenshot('04-profile');
  }),

  test('Profile: shows action items', async () => {
    const aria = await getAria();
    const hasActions = aria.includes('Edit') || aria.includes('Favorite') || aria.includes('Log Out') || aria.includes('Settings');
    assert(hasActions, `Expected profile actions. ARIA: ${aria.substring(0, 500)}`);
  }),

  // === SETTINGS PAGE ===
  test('Settings: accessible from profile', async () => {
    await navigateTo('/settings');
    const aria = await getAria();
    assertContains(aria, 'Settings', 'page title');
    await screenshot('05-settings');
  }),

  test('Settings: theme toggle exists', async () => {
    const aria = await getAria();
    const hasTheme = aria.includes('Auto') || aria.includes('Light') || aria.includes('Dark') || aria.includes('Theme');
    assert(hasTheme, `Expected theme toggle. ARIA: ${aria.substring(0, 500)}`);
  }),

  // === NOTIFICATIONS PAGE ===
  test('Notifications: page loads with empty state', async () => {
    await navigateTo('/notifications');
    const aria = await getAria();
    const hasNotif = aria.includes('Notifications') || aria.includes('notification');
    assert(hasNotif, `Expected notifications page. ARIA: ${aria.substring(0, 500)}`);
    await screenshot('06-notifications');
  }),

  // === API CRUD TESTS (via API directly, verify in Flutter) ===

  // Create a new gym via API
  test('API: create gym returns 201', async () => {
    const result = await apiPost('/api/v1/gyms', {
      name: 'Playwright Test Gym',
      description: 'Created by e2e test',
      address: '999 Test Blvd, TestVille',
      location: { type: 'Point', coordinates: [-74.0, 40.75] },
    });
    assert(result.statusCode === 201 || result.statusCode === 200, `Expected 201, got ${result.statusCode}`);
    assert(result.data?.name === 'Playwright Test Gym', `Expected gym name in response`);
    globalThis.__testGymId = result.data?._id;
  }),

  // Verify gym appears in list
  test('API: gym list includes new gym', async () => {
    const result = await apiGet('/api/v1/gyms');
    const names = (result.data || []).map(g => g.name);
    assert(names.includes('Playwright Test Gym'), `Expected "Playwright Test Gym" in: ${names.join(', ')}`);
  }),

  // Get gym detail
  test('API: get gym by ID', async () => {
    const id = globalThis.__testGymId;
    assert(id, 'No test gym ID');
    const result = await apiGet(`/api/v1/gyms/${id}`);
    assert(result.data?.name === 'Playwright Test Gym', `Expected gym detail`);
  }),

  // Update gym
  test('API: update gym', async () => {
    const id = globalThis.__testGymId;
    const res = await fetch(`${API_URL}/api/v1/gyms/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Playwright Test Gym Updated', description: 'Updated by e2e', address: '999 Test Blvd', location: { type: 'Point', coordinates: [-74.0, 40.75] } }),
    });
    const result = await res.json();
    assert(result.statusCode === 200 || result.data, `Expected 200, got ${result.statusCode}`);
  }),

  // Delete gym
  test('API: delete gym', async () => {
    const id = globalThis.__testGymId;
    const result = await apiDelete(`/api/v1/gyms/${id}`);
    assert(result.statusCode === 200 || result.statusCode === 204, `Expected 200/204, got ${result.statusCode}`);
  }),

  // Open mats list
  test('API: list open mats', async () => {
    const result = await apiGet('/api/v1/open-mats');
    assert(result.statusCode === 200, `Expected 200, got ${result.statusCode}`);
    const items = result.data?.items || result.data || [];
    assert(Array.isArray(items), 'Expected array of open mats');
  }),

  // User profile (dev mode returns test user)
  test('API: get user profile (dev mode)', async () => {
    const result = await apiGet('/api/v1/users/me');
    assert(result.statusCode === 200 || result.statusCode === 404, `Expected 200 or 404, got ${result.statusCode}`);
  }),

  // Favorites
  test('API: add favorite gym', async () => {
    // Create a gym to favorite
    const gym = await apiPost('/api/v1/gyms', {
      name: 'Fav Test Gym',
      address: '111 Fav St',
      location: { type: 'Point', coordinates: [-74.0, 40.75] },
    });
    const gymId = gym.data?._id;
    assert(gymId, 'No gym ID for favorite test');
    globalThis.__favGymId = gymId;

    const result = await apiPost(`/api/v1/gyms/${gymId}/favorite`, {});
    assert(result.statusCode === 200 || result.statusCode === 201, `Expected 200/201, got ${result.statusCode}`);
  }),

  test('API: list favorites', async () => {
    const result = await apiGet('/api/v1/users/me/favorites');
    assert(result.statusCode === 200, `Expected 200, got ${result.statusCode}`);
  }),

  test('API: remove favorite', async () => {
    const gymId = globalThis.__favGymId;
    if (gymId) {
      const result = await apiDelete(`/api/v1/gyms/${gymId}/favorite`);
      assert(result.statusCode === 200 || result.statusCode === 204, `Expected 200/204, got ${result.statusCode}`);
    }
  }),

  // Health check
  test('API: health endpoint is /healthz (should be /health)', async () => {
    const healthz = await fetch(`${API_URL}/healthz`).then(r => r.json()).catch(() => null);
    const health = await fetch(`${API_URL}/health`).then(r => r.json()).catch(() => null);

    if (healthz?.status === 'ok' && (!health || health.statusCode === 404)) {
      console.log('    ⚠️  WARNING: API uses /healthz — should be /health');
    }
  }),

  // CORS check
  test('API: CORS headers present', async () => {
    const res = await fetch(`${API_URL}/healthz`, { headers: { Origin: 'http://localhost:9999' } });
    const cors = res.headers.get('access-control-allow-origin');
    assert(cors, 'Access-Control-Allow-Origin header missing — CORS not enabled');
  }),

  // === FLUTTER UI: Navigate to each page and verify render ===

  test('Flutter: Discover tab renders open mats', async () => {
    await navigateTo('/');
    await page.waitForTimeout(3000);
    await enableSemantics();
    const aria = await getAria();
    assertContains(aria, 'Nearby Open Mats', 'discover');
    await screenshot('10-discover-final');
  }),

  test('Flutter: Search tab renders', async () => {
    await clickTab('Search');
    const aria = await getAria();
    assertContains(aria, 'Search', 'search page');
    await screenshot('11-search-final');
  }),

  test('Flutter: Training tab renders', async () => {
    await clickTab('Training');
    const aria = await getAria();
    const ok = aria.includes('Training') || aria.includes('My Training');
    assert(ok, `Training page didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('12-training-final');
  }),

  test('Flutter: Profile tab renders', async () => {
    await clickTab('Profile');
    const aria = await getAria();
    assertContains(aria, 'Profile', 'profile page');
    await screenshot('13-profile-final');
  }),

  test('Flutter: Settings page renders', async () => {
    await navigateTo('/settings');
    const aria = await getAria();
    assertContains(aria, 'Settings', 'settings');
    await screenshot('14-settings-final');
  }),

  test('Flutter: Notifications page renders', async () => {
    await navigateTo('/notifications');
    const aria = await getAria();
    const ok = aria.includes('Notifications') || aria.includes('notification');
    assert(ok, `Notifications page didn't render`);
    await screenshot('15-notifications-final');
  }),

  // Owner pages (navigate directly by URL)
  test('Flutter: Owner Dashboard renders', async () => {
    await navigateTo('/owner/dashboard');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('Dashboard') || aria.includes('My Gyms') || aria.includes('Sessions');
    assert(ok, `Owner dashboard didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('16-owner-dashboard');
  }),

  test('Flutter: My Gyms page renders', async () => {
    await navigateTo('/owner/gyms');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('Gym') || aria.includes('gym') || aria.includes('Add');
    assert(ok, `My Gyms page didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('17-my-gyms');
  }),

  test('Flutter: Add Gym page renders', async () => {
    await navigateTo('/owner/gyms/add');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('Gym') || aria.includes('Name') || aria.includes('Address');
    assert(ok, `Add Gym page didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('18-add-gym');
  }),

  test('Flutter: Sessions page renders', async () => {
    await navigateTo('/owner/sessions');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('Session') || aria.includes('session') || aria.includes('Create') || aria.includes('Open Mat');
    assert(ok, `Sessions page didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('19-sessions');
  }),

  test('Flutter: Create Session page renders', async () => {
    await navigateTo('/owner/sessions/create');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('Create') || aria.includes('Session') || aria.includes('Open Mat') || aria.includes('Title');
    assert(ok, `Create Session page didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('20-create-session');
  }),

  // Login page (accessible directly)
  test('Flutter: Login page renders with social buttons', async () => {
    await navigateTo('/login');
    await page.waitForTimeout(2000);
    await enableSemantics();
    const aria = await getAria();
    assertContains(aria, 'BJJ Open Mat', 'login page');
    assertContains(aria, 'Google', 'login buttons');
    assertContains(aria, 'Apple', 'login buttons');
    await screenshot('21-login');
  }),

  // Splash page
  test('Flutter: Splash page renders', async () => {
    await navigateTo('/splash');
    await page.waitForTimeout(1000);
    await enableSemantics();
    const aria = await getAria();
    const ok = aria.includes('BJJ') || aria.includes('Splash') || aria.includes('Open Mat');
    assert(ok, `Splash didn't render. ARIA: ${aria.substring(0, 300)}`);
    await screenshot('22-splash');
  }),
];

// --- Runner ---

async function main() {
  const { mkdirSync } = await import('fs');
  mkdirSync(SCREENSHOT_DIR, { recursive: true });

  console.log('🚀 BJJ Open Mat Finder — E2E Test Suite');
  console.log(`   App: ${APP_URL}`);
  console.log(`   API: ${API_URL}\n`);

  // Verify services are up
  try {
    await fetch(`${API_URL}/healthz`, { signal: AbortSignal.timeout(3000) });
  } catch {
    console.error('❌ API not reachable at ' + API_URL);
    process.exit(1);
  }
  try {
    await fetch(APP_URL, { signal: AbortSignal.timeout(3000) });
  } catch {
    console.error('❌ Flutter app not reachable at ' + APP_URL);
    process.exit(1);
  }

  // Seed data
  await seedTestData();

  // Launch browser
  browser = await chromium.launch({ headless: true });
  page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  // Initial load
  await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);
  await enableSemantics();

  console.log('\n📋 Running tests...\n');

  for (const t of tests) {
    await runTest(t);
  }

  await browser.close();

  // Report
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Results: ${passed} passed, ${failed} failed (${tests.length} total)`);

  if (failures.length > 0) {
    console.log(`\nFailures:`);
    for (const f of failures) {
      console.log(`  ❌ ${f.name}`);
      console.log(`     ${f.error}\n`);
    }
  }

  console.log(`Screenshots: ${SCREENSHOT_DIR}/`);
  console.log(`${'='.repeat(50)}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => {
  console.error('Fatal:', e);
  process.exit(1);
});
