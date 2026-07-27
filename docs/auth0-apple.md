# Sign in with Apple — Auth0 setup & verification

How the **Apple** social connection is configured in Auth0 for BJJ Open Mat, how
to (re)create it with the Management-API script, and how to verify it works.

Mirrors the other provider runbooks (`auth0-facebook.md`, `auth0-amazon.md`,
`auth0-microsoft.md`). Apple is different from the OAuth providers: it authenticates
with an **Apple signing key (.p8)**, not a static client secret.

## Facts / identifiers

- Auth0 tenant: `dev-vhvwupdn45hk7gct.us.auth0.com`
- Native app (client id): `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf` (`bjj-open-mat-native`)
- Apple Team ID: `9T6ZZ323UC`
- Apple **Services ID** (this is the Auth0 `client_id` for Apple):
  `com.davissylvester.bjjopenmat.signin`
- iOS app bundle id: `com.davissylvester.bjjOpenMat`
- Auth0 connection name/strategy: `apple`

## Part 1 — Apple Developer portal (one-time)

Under [developer.apple.com → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources):

1. **App ID** — ensure the app id `com.davissylvester.bjjOpenMat` has the
   **Sign In with Apple** capability enabled.
2. **Services ID** — create `com.davissylvester.bjjopenmat.signin` (Identifiers →
   `+` → Services IDs). Enable **Sign In with Apple**, configure it, and set:
   - **Primary App ID:** `com.davissylvester.bjjOpenMat`
   - **Domains:** `dev-vhvwupdn45hk7gct.us.auth0.com`
   - **Return URLs:** `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
3. **Key** — create a **Sign in with Apple** key (Keys → `+`), download the
   `AuthKey_<KEY_ID>.p8` **once** (Apple never lets you re-download it). Note the
   **Key ID**.

The `.p8` is a secret. It lives locally at `scripts/auth0/AuthKey_<KEY_ID>.p8` and
is **gitignored** (`*.p8`). Never commit it.

## Part 2 — Auth0 connection (via the setup script)

The `apple` connection is created/updated by
`scripts/auth0/setup-social-connections.mts`. Unlike the OAuth providers, Apple's
Auth0 `options` are `{ client_id, team_id, kid, app_secret, scope }`, where
`app_secret` is the **contents of the `.p8`** (not a client secret).

### Env (`scripts/auth0/.env`, gitignored)

```
APPLE_CLIENT_ID=com.davissylvester.bjjopenmat.signin
APPLE_TEAM_ID=9T6ZZ323UC
APPLE_KEY_ID=<the Sign-in-with-Apple key id>
APPLE_PRIVATE_KEY_FILE=scripts/auth0/AuthKey_<KEY_ID>.p8
```

The script loads the multi-line `.p8` from `APPLE_PRIVATE_KEY_FILE` (the line-based
`.env` loader can't hold a multi-line value directly).

### Run

```bash
# plan only (safe, no writes)
bun run scripts/auth0/setup-social-connections.mts
# create/update + enable for the native app
bun run scripts/auth0/setup-social-connections.mts --commit
# read-only report of each connection's existence + native-app enablement
bun run scripts/auth0/setup-social-connections.mts --verify
```

Gotchas baked into the script:
- **PATCH replaces the whole `options` object** (no deep merge) and this tenant
  **rejects `enabled_clients` on PATCH** — so update sends `options` only; client
  enablement is set at create time (POST) and read via `/connections/{id}/clients`.
- This tenant uses the newer connection–client association model, so the deprecated
  `enabled_clients` field always reads empty; enablement truth is
  `GET /api/v2/connections/{id}/clients`.

## Part 3 — Verify it works

### Quick config check
```bash
bun run scripts/auth0/setup-social-connections.mts --verify
# apple: EXISTS  native-enabled=true
```

### End-to-end (real Apple sign-in)
Build an `/authorize` URL for the native client with `connection=apple` and PKCE,
open it in a browser, complete the Apple sign-in, then read the Auth0 logs:

```
https://dev-vhvwupdn45hk7gct.us.auth0.com/authorize?client_id=su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf
  &response_type=code&connection=apple
  &redirect_uri=https%3A%2F%2Fdev-vhvwupdn45hk7gct.us.auth0.com%2Fandroid%2Fcom.davissylvester.bjjopenmat%2Fcallback
  &scope=openid+profile+email&audience=https%3A%2F%2Fwww.bjj-open-mat
  &code_challenge=<S256>&code_challenge_method=S256&state=x&nonce=x
```

- Success = Apple's page loads ("Use your Apple Account to sign in to BJJ Open Mat
  Sign In") with **no `invalid_client`**, and after signing in the Auth0 logs show a
  `type=ss` (first-time signup) and/or `type=s` (login) event for `connection=apple`.
- The final redirect lands on the `/android/.../callback` URL (a 404 page) — that is
  expected; success is read from the Auth0 logs, not the browser.

`scripts/auth0/e2e-social-login.mts apple` automates the URL + log polling.

## Part 4 — App Review context (Guideline 2.1(a))

App Review rejected build **1.0 (116)** under **Guideline 2.1(a) — Performance:
App Completeness**: *"your app displayed a network error message when we attempted
to Sign in with Apple"* (tested on iPad Air M3, iPadOS 26.5.2).

**Root cause:** the Auth0 `apple` connection was **not enabled** for the native app,
so `/authorize?connection=apple` returned an error the app surfaced as a network
error.

**Fix:** created + enabled the `apple` connection (this runbook). It is a
**server-side** change — the app binary already shipped the "Sign in with Apple"
button since the first commit, so **no rebuild is required**; the same build 116
now completes Apple sign-in. Resubmit build 116 with a Resolution Center reply
explaining the server-side fix (see
`docs/superpowers/plans/2026-07-26-apple-review-2.1.0-resubmit.md`).
