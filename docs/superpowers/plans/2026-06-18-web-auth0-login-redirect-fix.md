# Web Auth0 Login Redirect Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a successful Auth0 login on the Flutter **web** build, the user lands on the main app page (`/` for practitioners, `/owner/dashboard` for owners) instead of being bounced back to `/login`.

**Architecture:** Login *authentication* already works (the user reaches Auth0 and authenticates). The break is the PKCE **code→token exchange**: `auth0-spa-js` calls `POST https://<tenant>/oauth/token` and gets **HTTP 401**, because the Auth0 application the browser uses requires *client authentication* (a `client_secret`) — i.e. it is a **Regular Web Application**, not a **Single Page Application**. The same `client_id` is currently shared by the server API (which legitimately uses a secret) and the browser SPA (which cannot hold a secret). The fix is to give the Flutter web app its **own Auth0 SPA application** (Token Endpoint Auth Method = `None`), feed its `client_id` + the API `audience` to the web build, and harden the web bootstrap so `onLoad()` reliably completes and the existing router redirect fires.

**Tech Stack:** Flutter web, `auth0_flutter` / `auth0_flutter_web` (auth0-spa-js 2.1), `go_router`, Riverpod; Bun + Elysia API with `jose` JWKS verification.

---

## Root Cause Evidence (confirmed)

| Evidence | Source | Meaning |
|---|---|---|
| `401 @ .../oauth/token` after callback | browser console (all login attempts) | PKCE code→token exchange is rejected |
| **Zero** `/auth/me` requests after login | API log (`/health`, `/ready` ARE logged) | client never gets a token → never calls the API |
| App returns to `/login`, query `?code=&state=` preserved | Playwright URL probe | not a URL-stripping bug; `onLoad()` throws on the failed exchange and `checkAuth()` swallows it → `unauthenticated` |
| `AUTH0_CLIENT_SECRET` + `AUTH0_CALLBACK_URL` present in `apps/api/.env`; same `client_id` (`S6Kc…sbGSw`) used by web | env key audit | the shared app is a Regular Web App, not a SPA |
| `apps/mobile/.env` has **no** `AUTH0_AUDIENCE` | env key audit | even after the exchange is fixed, the access token would be **opaque**, and the API (`jwt-verifier.mts:37-40` verifies `audience`) would 401 `/auth/me` |
| `web/index.html:36` loads SDK with `defer`; `:47` loads Flutter with `async` | source | script-order race: Flutter can call `Auth0Web` before `window.auth0` exists |

**Disproven hypothesis:** GoRouter stripping the `?code` query on the hash route. The Playwright probe showed the query string is preserved (`...?code=...#/login`). Do **not** spend time on URL-strategy changes for this bug.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| Auth0 Dashboard (SPA application) | Browser OIDC client (PKCE, no secret) | **Create/configure** (manual) |
| `apps/mobile/.env` | Web build dart-defines (domain, client id, audience) | Modify |
| `apps/mobile/web/index.html` | Load the Auth0 SDK before Flutter boots | Modify (`:36`) |
| `apps/mobile/lib/core/auth/auth_service.dart` | Surface callback errors instead of silently swallowing | Modify (`checkAuth` `:151-155`, `webOnLoad` `:222-230`) |
| `package.json` / launch command | Pass `--dart-define-from-file=.env` | Verify only |

---

## Task 1: Configure a dedicated Auth0 Single Page Application (MANUAL — user)

This is the actual root-cause fix. It is a dashboard change; the AI worker cannot perform it and must hand it to the user, then verify the effect in Task 5.

**Files:** none (Auth0 Dashboard).

- [ ] **Step 1: Create or identify a SPA application**

In the Auth0 Dashboard → **Applications**:
- Preferred: **Create Application** → type **Single Page Web Applications** → name it e.g. `BJJ Open Mat (Web SPA)`.
- Alternative (only if the existing app is *not* also used as a Regular Web App by the API): change the existing app's type to **Single Page Application**. Because `apps/api/.env` uses `AUTH0_CLIENT_SECRET` with the current `client_id`, **do not repurpose it** — create a new SPA app instead and leave the API's Regular Web App untouched.

- [ ] **Step 2: Verify Token Endpoint Authentication Method = `None`**

SPA app → **Settings** → **Advanced Settings** → **Grant Types**: ensure **Authorization Code** is enabled. Under **Application** basics, confirm **Token Endpoint Authentication Method** is `None` (SPA default). This is what makes the PKCE exchange succeed without a secret and resolves the `401 /oauth/token`.

- [ ] **Step 3: Register the local web origin**

SPA app → **Settings**, add **exactly** `http://localhost:8088` (no trailing slash, no path) to:
- **Allowed Callback URLs**
- **Allowed Web Origins**
- **Allowed Logout URLs**

Save Changes.

- [ ] **Step 4: Confirm the API Authorization API audience**

Auth0 Dashboard → **APIs**: note the **Identifier** of the API the backend verifies against (this is the value in `apps/api/.env` → `AUTH0_AUDIENCE`). The web app must request **this same audience** so the issued access token is a JWT the API can verify. Authorize the SPA app for this API if an explicit authorization is required.

- [ ] **Step 5: Record the SPA `client_id` and audience**

Copy the SPA application's **Client ID** and the API **Identifier**. These feed Task 2. **Do not** copy any client secret — the SPA has none and must never receive one.

---

## Task 2: Point the Flutter web build at the SPA client + audience

**Files:**
- Modify: `apps/mobile/.env`

The app code already reads these via `String.fromEnvironment` and forwards `audience` to both `loginWithRedirect` and `onLoad` (`auth_service.dart:13`, `:223-226`, `:240-245`). Only the `.env` values are missing/wrong.

- [ ] **Step 1: Set the SPA client id and audience in `apps/mobile/.env`**

> The worker must NOT print `.env` contents. Edit it to contain these keys (values from Task 1, Step 5). `AUTH0_CLIENT_ID` must be the **SPA** client id, not the Regular Web App id.

```dotenv
AUTH0_DOMAIN=dev-vhvwupdn45hk7gct.us.auth0.com
AUTH0_CLIENT_ID=<SPA client id from Task 1>
AUTH0_AUDIENCE=<API Identifier from Task 1 / apps/api/.env AUTH0_AUDIENCE>
# DEMO_USER_* keys retained as-is
```

- [ ] **Step 2: Confirm the launch passes the env file**

The web app is launched from `apps/mobile` with:

```bash
flutter run -d chrome --web-port=8088 \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=http://localhost:3100
```

Verify `package.json`'s `mobile:run` (or your launch command) includes `--dart-define-from-file=.env`. If it does not, update it:

Run: `grep -n "mobile:run" package.json`
Expected: a `flutter run` line that includes `--dart-define-from-file=.env`. Add it if absent.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/.env package.json
git commit -m "fix(mobile): use Auth0 SPA client id + API audience for web login"
```

> Note: confirm `apps/mobile/.env` is git-ignored before committing if it holds secrets. If it is ignored, commit only `package.json` and document the required keys in `.env.example` instead.

---

## Task 3: Guarantee the Auth0 SDK loads before Flutter boots

**Files:**
- Modify: `apps/mobile/web/index.html:36`

`defer` (SDK) + `async` (Flutter) do not guarantee order; Flutter can run `Auth0Web(...)`/`onLoad()` before `window.auth0` exists, making the callback throw intermittently.

- [ ] **Step 1: Make the SDK a blocking script in `<head>`**

Change line 36 from:

```html
    <!-- Required by auth0_flutter for web: the Auth0 SPA-JS SDK -->
    <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js" defer></script>
```

to (remove `defer` so it is fully loaded before `flutter_bootstrap.js` executes):

```html
    <!-- Required by auth0_flutter for web: the Auth0 SPA-JS SDK.
         Loaded synchronously (no defer/async) so window.auth0 exists before Flutter boots. -->
    <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js"></script>
```

- [ ] **Step 2: Rebuild and confirm the SDK is present at boot**

Restart `flutter run` (hot restart does not re-read `index.html`). After load, in the browser console:

Run (DevTools console): `typeof window.auth0`
Expected: `"object"` (not `"undefined"`).

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/web/index.html
git commit -m "fix(mobile): load Auth0 SPA-JS before Flutter boots to avoid onLoad race"
```

---

## Task 4: Surface callback errors instead of silently swallowing them

**Files:**
- Modify: `apps/mobile/lib/core/auth/auth_service.dart` (`checkAuth` catch at `:151-155`)

Today any `onLoad()` failure is swallowed into a bare `unauthenticated`, which is exactly why this bug looked like "nothing happens." Keep the safe fallback but record the error so it is visible in the UI/console and future regressions are diagnosable.

- [ ] **Step 1: Capture the error in the catch block**

Replace `:151-155`:

```dart
    } catch (_) {
      // Any failure (e.g. secure storage / Auth0 init on web) -> unauthenticated,
      // so the app always leaves the splash and lands on /login.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
```

with:

```dart
    } catch (e) {
      // Any failure (e.g. token exchange / secure storage / Auth0 init on web) ->
      // unauthenticated so the app always leaves the splash and lands on /login,
      // but keep the reason so the login screen and console can show it.
      debugPrint('checkAuth failed: $e');
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
    }
```

- [ ] **Step 2: Add the `foundation` import if not already present**

At the top of the file, ensure `debugPrint` is available:

Run: `grep -n "package:flutter/foundation.dart" apps/mobile/lib/core/auth/auth_service.dart`
Expected: a line importing `foundation` (it already imports `show kIsWeb` at `:3`). Update that import to also expose `debugPrint`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
```

- [ ] **Step 3: Analyze and commit**

Run: `cd apps/mobile && flutter analyze lib/core/auth/auth_service.dart`
Expected: No new errors.

```bash
git add apps/mobile/lib/core/auth/auth_service.dart
git commit -m "fix(mobile): surface web auth callback errors instead of swallowing them"
```

---

## Task 5: End-to-end verification (MANUAL login + automated checks)

A real Auth0 login requires typing real credentials, so the final click-through is done by the user; the AI worker verifies the observable side effects.

**Files:** none.

- [ ] **Step 1: Restart the stack**

```bash
# from repo root
docker start bjj-mongo
bun run --filter @bjj/api seed   # idempotent
bun run api:dev                  # http://localhost:3100
# in apps/mobile:
flutter run -d chrome --web-port=8088 --dart-define-from-file=.env --dart-define=API_BASE_URL=http://localhost:3100
```

- [ ] **Step 2: Perform a login (user)**

Open `http://localhost:8088`, click a login button, complete Auth0 authentication.

- [ ] **Step 3: Confirm the token exchange now succeeds**

In the browser console / Network tab, the `POST .../oauth/token` request returns **200** (no longer 401). `typeof window.auth0` is `"object"`.

- [ ] **Step 4: Confirm the API is now called**

Run: `grep -E "auth/me" /tmp/api.log`
Expected: a `GET /api/v1/auth/me -> 200` entry (proves a verifiable JWT reached the API). If it shows `-> 401`, the audience is still wrong — re-check Task 2 Step 1.

- [ ] **Step 5: Confirm the redirect to the main page**

After login the URL is `http://localhost:8088/#/` (practitioner) or `http://localhost:8088/#/owner/dashboard` (owner), and the home/dashboard renders. (The existing router already performs this redirect at `lib/app/router.dart:57` once `authStateProvider` becomes `authenticated`; no router change is required.)

- [ ] **Step 6: Update the knowledge-base entry status**

Mark the issue **Resolved** in `docs/knowledge-base/2026-06-18-web-auth0-login-redirect.md` and note the SPA `client_id` (not secret) used.

---

## Optional Hardening (not required for the fix; do only if revisiting auth)

- **Router recreation:** `routerProvider` does `ref.watch(authStateProvider)` (`router.dart:34`), recreating the entire `GoRouter` on every auth change. It works, but the idiomatic pattern is a stable router with a `refreshListenable` bridged from the auth notifier. Defer unless it causes observable issues.
- **`.env.example` for mobile:** add an `apps/mobile/.env.example` documenting `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` (SPA), `AUTH0_AUDIENCE`, `API_BASE_URL` so the required keys are discoverable without reading the real `.env`.

---

## Self-Review

- **Spec coverage:** Goal = land on main page after login. Task 1 fixes the 401 token exchange (root cause); Task 2 ensures a verifiable JWT (so `/auth/me` succeeds); Tasks 3–4 remove the race and the silent failure; Task 5 verifies the redirect. Covered.
- **Placeholder scan:** Remaining `<...>` tokens are deliberate secret placeholders (SPA client id / audience) the user supplies from their tenant — values that must not be invented. No TODO/TBD logic gaps.
- **Type consistency:** `AuthState(status:, error:)` matches the constructor at `auth_service.dart:30-34`; `debugPrint` import matches usage; router redirect target matches existing `router.dart:57`.
