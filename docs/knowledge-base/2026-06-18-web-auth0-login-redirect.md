# Web Auth0 login succeeds but app never reaches the main page

**Status:** Open (fix planned — see `docs/superpowers/plans/2026-06-18-web-auth0-login-redirect-fix.md`)
**Date:** 2026-06-18
**Area:** `apps/mobile` (Flutter web) ↔ Auth0 ↔ `apps/api`
**Symptom severity:** Login is effectively unusable on web.

## Symptom

On the Flutter **web** build, clicking a login button opens Auth0, the user authenticates,
and the browser redirects back to the app — but the app stays on `/login` (the home /
owner-dashboard page never loads). To the user it looks like "login works but doesn't
redirect."

## Root cause

The OAuth **authorization-code → token exchange fails with HTTP 401**:

```
POST https://dev-vhvwupdn45hk7gct.us.auth0.com/oauth/token  →  401
```

`auth0-spa-js` performs this PKCE exchange in the browser after the `?code=` redirect.
A 401 here means the Auth0 application **requires client authentication** (a
`client_secret`) — i.e. it is configured as a **Regular Web Application**, not a
**Single Page Application**. A browser SPA cannot send a secret, so the exchange is
rejected. The same `client_id` was being shared by the server API (which correctly uses
`AUTH0_CLIENT_SECRET`) and the browser app.

When the exchange fails, `Auth0Web.onLoad()` throws → `AuthStateNotifier.checkAuth()`
catches it and falls back to `unauthenticated` → the router keeps the user on `/login`.
Because no token is ever obtained, the API is **never called** (the API request log shows
`/health` and `/ready` but zero `/auth/me` hits — a key tell).

### Contributing issues (must also be fixed, surfaced once the 401 is gone)

1. **Missing audience.** `apps/mobile/.env` had no `AUTH0_AUDIENCE`, so even a successful
   exchange would yield an **opaque** access token. The API verifies a JWT with a specific
   `audience` (`apps/api/src/auth/jwt-verifier.mts:37-40`), so `/auth/me` would then 401.
2. **Script-load race.** `web/index.html` loaded the Auth0 SDK with `defer` (`:36`) while
   Flutter loaded with `async` (`:47`); Flutter could call `Auth0Web` before
   `window.auth0` existed.
3. **Silent failure.** `checkAuth()` swallowed the callback error into a bare
   `unauthenticated`, which is why the failure was invisible and looked like "nothing
   happens."

### Disproven hypotheses (don't chase these)

- *GoRouter stripping the `?code` query on the hash route.* A Playwright probe to
  `http://localhost:8088/?code=...&state=...` showed the query string is **preserved**
  (`...?code=...#/login`). Not the cause.
- *Callback URL mismatch.* That was an earlier, separate error (`Callback URL mismatch`)
  fixed by registering `http://localhost:8088`. The redirect now returns to the app; the
  failure is downstream at `/oauth/token`.

## Fix (summary)

1. Give the Flutter web app its **own Auth0 SPA application** (Token Endpoint
   Authentication Method = `None`); register `http://localhost:8088` in Allowed Callback
   URLs / Web Origins / Logout URLs. Keep the API's Regular Web App separate.
2. Put the **SPA `client_id`** and the **API `audience`** in `apps/mobile/.env`
   (consumed via `--dart-define-from-file=.env`).
3. Load the Auth0 SDK synchronously (remove `defer`) in `web/index.html`.
4. Record (don't swallow) the callback error in `checkAuth()`.

Full step-by-step: `docs/superpowers/plans/2026-06-18-web-auth0-login-redirect-fix.md`.

## How it was diagnosed (repro recipe)

- Read the **browser console "all messages"** — the `401 /oauth/token` line is the
  smoking gun. (Flutter renders to canvas, so drive it with raw Playwright mouse clicks
  by pixel coordinate, not text selectors.)
- Check the **API request log** for `/auth/me`. Its absence proves the client never got a
  token (failure is client-side, before the API).
- Probe the callback URL directly to rule out query-stripping:
  `navigate http://localhost:8088/?code=X&state=Y` and watch whether the query survives.

## Verification of the fix

- `POST /oauth/token` returns **200**.
- API log shows `GET /api/v1/auth/me -> 200`.
- URL becomes `/#/` (practitioner) or `/#/owner/dashboard` (owner) and the page renders.

## Resolution (2026-06-20)

Fixed in commit `87c3f52`. Verified end-to-end: login → practitioner home /
role-select, `GET /api/v1/auth/me -> 200` (single call, no retry loop). The
full chain and the non-obvious `subject_type_authorization` requirement are
documented in [auth0-web-spa-setup.md](../auth0-web-spa-setup.md). The four
tenant-side requirements are NOT in the repo — apply them per environment with
`scripts/auth0-web-setup.sh`.
