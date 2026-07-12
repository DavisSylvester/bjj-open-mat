# Design: BJJ Open Mat Marketing Website + Lead Capture

**Date:** 2026-07-11
**Status:** Approved (brainstorming complete)

## Summary

A pixel-perfect Angular landing page that matches the Claude Design file
`BJJ Open Mat Landing.dc.html`, with two public actions — **Join the founding list**
(practitioner) and **Claim your gym** (gym owner). Both POST to new **public** endpoints in
the existing API, persist to MongoDB, and trigger a confirmation email via Amazon SES. The
site is deployed to `bjj-open-mat.dsylvester.ai` (Hostinger DNS + AWS S3/CloudFront). Pixel
accuracy is verified with Playwright.

## Decisions (resolved during brainstorming)

- **Design source:** Claude Design project `45ac103e-5117-445c-9d19-85dba1f3474f`, file
  `BJJ Open Mat Landing.dc.html`. This is the pixel-perfect target. Fetching it requires a
  claude.ai login (`/login` → "Claude account with subscription") for the design tool
  (`DesignSync`).
- **Endpoint model:** Two dedicated **public** lead endpoints in `apps/api`
  (`POST /api/v1/waitlist`, `POST /api/v1/gym-leads`). No Auth0 on the website. The existing
  `POST /api/v1/gyms` (Auth0 owner-only) is untouched; real gym records are still created
  in-app after an owner signs up.
- **Email:** Amazon SES, sender `no-reply@dsylvester.ai`. Gym-lead admin alerts go to
  `davis.sylvester@davaco.com`. SES send lives behind an interface so it is stubbable /
  log-only when SES is not configured.
- **Domain:** Website on **`dsylvester.ai` via Hostinger** — `bjj-open-mat.dsylvester.ai`.
  The API stays on the existing `api.bjj-open-mat.dsylvester.io` (Route 53). This is a
  deliberate two-domain, cross-origin setup.
- **Deploy scope:** Full — build + Playwright-verify locally **and** provision AWS hosting +
  Hostinger DNS.
- **Website location:** `website/` at the repo root (not under `apps/`).
- **Angular:** v21, standalone components, signals, SCSS, per the user's global standards.

## Known caveats

- **SES sandbox:** SES starts in sandbox mode (verified recipients only, ~200/day). Public
  launch needs production access (support request). Built so this is a config change, not a
  code change; dev/test uses verified inboxes.
- **ACM validation on Hostinger:** A Hostinger-hosted domain cannot auto-validate an ACM cert
  via Route 53. Flow: create cert → emit validation records → add on Hostinger (via the
  `hostinger-dns` agent) → deploy completes. The CloudFront cert **must** be in `us-east-1`.
- **Marketing copy references `.io`:** `docs/marketing/landing-page-copy.md` uses
  `bjj-open-mat.dsylvester.io`. Source of truth is now `.ai`; copy fix is out of scope here.

## Architecture

Three parts, following the existing API layering (contract → repository → facade → route).

### A. Website — `website/`

- Angular v21 static SPA (standalone components, signals, SCSS).
- Single landing route composed of section components: `hero`, `how-it-works`, `features`,
  `gym-owner`, `faq`, `footer`; plus form components `waitlist-form`, `gym-lead-form`.
- `LeadApiService` — typed client (`httpResource` / `fetch`) posting to the API; base URL from
  Angular environment config (`https://api.bjj-open-mat.dsylvester.io`).
- Brand tokens (colors, typography from `docs/marketing/claude-design-prompt.md`) as SCSS
  variables; Plus Jakarta Sans embedded (weights 600/700/800).

### B. API additions — `apps/api`

- **Contract** (`packages/contract/src/schemas/requests/`): TypeBox `WaitlistLeadRequest`,
  `GymLeadRequest` + response types; derive types with `Static<>`; barrel exports.
- **Repositories:** `waitlist-lead.repository.mts`, `gym-lead.repository.mts` extending
  `base.repository.mts`; new collections `waitlist_leads`, `gym_leads` registered in
  `db/collections.mts`. Unique index on `waitlist_leads.email`.
- **Service:** `email.service.mts` — SES wrapper (`@aws-sdk/client-ses`) behind an interface;
  log-only fallback when unconfigured. Registered via DI in the container.
- **Facade:** `lead.facade.mts` — orchestrates persist → send confirmation (+ admin alert for
  gym leads). Returns `Result<T, E>`.
- **Routes:** `lead.routes.mts` — **public, no auth**: `POST /api/v1/waitlist`,
  `POST /api/v1/gym-leads`. Registered in `index.mts`.
- **CORS:** allow `https://bjj-open-mat.dsylvester.ai` and `http://localhost:4200` (dev).

### C. Infra — `infra/` (CDK)

- New `WebsiteStack`: private S3 bucket + CloudFront (OAC, SPA 403/404 → `index.html`) + ACM
  cert in `us-east-1`.
- SES: domain identity for `dsylvester.ai` + DKIM; `ses:SendEmail` IAM grant to the API
  Lambda; config `SES_FROM`, `ADMIN_EMAIL`, `WEBSITE_ORIGIN` (env / secret).
- **Hostinger DNS** (via `hostinger-dns` agent): CloudFront CNAME, ACM validation CNAME, SES
  DKIM CNAMEs, SPF + DMARC TXT records.

## Data model

- **`waitlist_leads`**: `{ _id, email (unique, lowercased), createdAt, source, utm { source,
  medium, campaign }, status: 'pending' | 'confirmed', confirmationSentAt? }`
- **`gym_leads`**: `{ _id, gymName, ownerName?, ownerEmail, city?, state?, message?, createdAt,
  utm, status: 'new' | 'contacted' }`

## Data flow — Join the list

1. User submits email in `waitlist-form` → `LeadApiService.joinWaitlist({ email, utm, hp })`.
2. `POST /api/v1/waitlist` validates (TypeBox) → honeypot check → `lead.facade`:
   - Upsert into `waitlist_leads` (email unique → **idempotent**; re-submits succeed silently,
     no duplicates).
   - `email.service.sendWaitlistConfirmation(email)` via SES.
3. Returns `{ data: { status: 'confirmed' } }`; UI swaps form → success state
   ("You're on the list 🥋").

Gym flow is the same, plus an admin notification email to `davis.sylvester@davaco.com`.

## Error handling

- `Result<T, E>` / discriminated unions in facade and service.
- Email send failure **does not** fail the request — the lead is already persisted; the error
  is logged (Winston) and the user still sees success.
- Validation errors → 422 with field message; form shows inline error.
- Spam mitigation: hidden honeypot field + simple per-IP throttle; bot/malformed submissions
  rejected quietly.

## Pixel-perfect verification (Playwright)

1. Fetch `BJJ Open Mat Landing.dc.html` (after `/login`); render at fixed viewports
   (mobile 390px + desktop 1280px) → **reference screenshots**.
2. Build the Angular site; serve on a local dev server.
3. Playwright screenshots at the same viewports; pixel-diff vs reference; iterate until
   ≥ ~98% match. Mobile-first (most traffic is mobile per the copy).
4. Functional E2E: fill + submit each form → assert success state (API stubbed for the
   visual/CI run; live-API smoke run separately).

## Testing

- `bun test`: `lead.facade` (persist + email orchestration, SES mocked), repositories
  (idempotent upsert), `email.service` (payload shape).
- Playwright (in `website/`): visual regression + form E2E.
- ESLint clean on all changed TypeScript; strict mode, no `any`.

## Sequencing

1. **API:** contract schemas → repositories → email service → facade → routes (+ CORS) →
   `bun test`.
2. **Website:** Angular scaffold in `website/` → build sections/forms → pixel loop against the
   design → Playwright visual + E2E green.
3. **Infra:** SES identity + `WebsiteStack` + Hostinger DNS → deploy → live smoke test.

## Out of scope

- Migrating the API/mobile app to `.ai`.
- Fixing `.io` references in existing marketing copy.
- Full gym creation / Auth0 login on the website.
- Admin UI for managing captured leads (DB-only for now).
