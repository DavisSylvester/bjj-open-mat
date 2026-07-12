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

## Design revision (2026-07-12) — actual design received

The `DesignSync` login path proved unreliable; the user instead provided the Claude Design
**handoff bundle** `Nocturne gym app design-handoff.zip`, extracted to
`website/reference/_handoff/`. The authoritative pixel-perfect target is
`.../project/BJJ Open Mat Landing.dc.html` plus its design system
`.../project/_ds/nocturne-8bf90f58-.../styles.css`. This design differs substantially from
the light "liquid glass" concept the original spec assumed. The real design:

- **Theme:** dark "Nocturne" — `--color-bg #161826`, `--color-surface #232532`,
  `--color-text #e9e9ed`, blurple accent `--color-accent #9184d9`, section band
  `--color-section #262a60`. Page chrome uses **Inter** (`--font-heading`/`--font-body`,
  weight 500). The embedded phone mockups use **Barlow** + **Barlow Condensed** and a
  light "liquid glass" palette internal to the app UI (accents `#E94560` red, `#9C27B0`
  purple, `#2196F3` blue, `#16C79A` green, `#FF9800` orange).
- **Sections (top→bottom):** sticky-feel nav → hero (headline + email→*Join the founding
  list* + microcopy + "I own a gym → claim your mat" link + **interactive Android phone
  demo**) → full-bleed stat band (100 mi · 1 tap · Gi·No-Gi · $0) → How it works (3 numbered
  rows) → Gym-owner (copy + *Register your gym — free* / *See owner tools* buttons + a second
  "Post Session" phone mockup) → close/join (email again) → footer. **No FAQ or feature-grid
  sections** (drop them from the original plan).
- **Interactive phone demo (user decision):** reproduce **fully interactive** — port the
  prototype's `DCLogic` state machine to an Angular component: screens home ↔ detail ↔
  check-in ↔ profile, RSVP toggle, star-rating rows, and a home/profile bottom nav. Default
  screen on load is `home`.
- **Gym-lead capture (user decision):** the *Register your gym — free* button routes to a
  **dedicated `/register-gym` page** (Nocturne-styled) hosting the full gym-lead form
  (gym name, owner email, optional owner name/city/state/message) → `submitGymLead`. The
  landing page itself has no inline gym form.
- **Fonts:** replace the earlier "Plus Jakarta Sans" assumption with Inter (chrome) +
  Barlow/Barlow Condensed (phone). Load via Google Fonts as the prototype does.

The backend (Phase 1, complete) is unaffected: both waitlist email inputs call
`joinWaitlist`; the `/register-gym` form calls `submitGymLead`.

## Decisions (resolved during brainstorming)

- **Design source:** Claude Design project `45ac103e-5117-445c-9d19-85dba1f3474f`, file
  `BJJ Open Mat Landing.dc.html` — now delivered via the handoff bundle above (superseded
  the `DesignSync` login fetch).
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
