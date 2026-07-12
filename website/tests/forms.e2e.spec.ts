import { test, expect, type Route } from '@playwright/test';

// End-to-end tests for the two lead-capture flows. The API is STUBBED via
// page.route so these run purely against the served Angular app: we assert the
// UI reaches its success/error state AND that the correct payload is POSTed.
//
// In dev, environment.apiBaseUrl is http://localhost:3100, so the glob patterns
// match the API host regardless of origin.

interface WaitlistPayload {
  readonly email: string;
}

interface GymLeadPayload {
  readonly gymName: string;
  readonly ownerEmail: string;
}

test('waitlist success — hero form on / posts the email and shows confirmation', async ({
  page,
}) => {
  let captured: WaitlistPayload | undefined;

  await page.route('**/api/v1/waitlist', async (route: Route) => {
    captured = route.request().postDataJSON() as WaitlistPayload;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ data: { status: 'confirmed' } }),
    });
  });

  await page.goto('/');

  // The hero waitlist form is the first email input on the page.
  await page.locator('input[type=email]').first().fill('tester@example.com');
  await page.getByRole('button', { name: /join the founding list/i }).click();

  await expect(page.getByText(/on the list/i)).toBeVisible();
  expect(captured?.email).toBe('tester@example.com');
});

test('gym-lead success — /register-gym posts the lead and shows confirmation', async ({
  page,
}) => {
  let captured: GymLeadPayload | undefined;

  await page.route('**/api/v1/gym-leads', async (route: Route) => {
    captured = route.request().postDataJSON() as GymLeadPayload;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ data: { status: 'new' } }),
    });
  });

  await page.goto('/register-gym');

  await page.getByLabel(/gym name/i).fill('Test BJJ Academy');
  await page.getByLabel(/your email/i).fill('coach@test.com');
  await page.getByRole('button', { name: /register your gym/i }).click();

  await expect(page.getByText(/be in touch/i)).toBeVisible();
  expect(captured?.gymName).toBe('Test BJJ Academy');
  expect(captured?.ownerEmail).toBe('coach@test.com');
});

test('waitlist error — a 400 from the API surfaces the error message', async ({ page }) => {
  await page.route('**/api/v1/waitlist', async (route: Route) => {
    await route.fulfill({
      status: 400,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'bad request' }),
    });
  });

  await page.goto('/');

  await page.locator('input[type=email]').first().fill('tester@example.com');
  await page.getByRole('button', { name: /join the founding list/i }).click();

  await expect(page.getByText(/something went wrong/i)).toBeVisible();
});
