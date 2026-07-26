# Design: Add Facebook, Amazon & Microsoft social login

**Date:** 2026-07-24
**Status:** Approved (pending spec review)
**Owner:** Davis Sylvester

## Goal

Let users sign into the BJJ Open Mat mobile app with **Facebook**, **Amazon**, and
**Microsoft (personal accounts)** — in addition to the existing Google and Apple
options — on **iOS and Android**. Set up and enable the connections in Auth0, wire
the login buttons, and verify each provider end-to-end with a real account.

**Snapchat is explicitly deferred to a phase 2** (see Out of Scope).

## Context / current state

The app already brokers **all** social login through Auth0 Universal Login using
`auth0_flutter`'s `webAuthentication` with the custom callback scheme
`com.davissylvester.bjjopenmat`. Google (`google-oauth2`) and Apple (`apple`) ride
this exact path via a generic `_socialLogin(connection)` helper in
`apps/mobile/lib/core/auth/auth_service.dart`.

Key consequence: **no on-device provider SDKs are required.** Auth0 performs each
OAuth handshake server-side. Adding a provider is therefore:

1. An Auth0 connection configured with the provider's OAuth keys.
2. That connection enabled for the native (and optionally SPA) Auth0 app.
3. A login button in the app that calls `_socialLogin('<connection>')`.

Facebook, Amazon, and Microsoft-personal are all **built-in Auth0 social
connectors**, so no custom connection is needed for any of the three.

**Facts / identifiers:**
- Auth0 tenant: `dev-vhvwupdn45hk7gct.us.auth0.com`
- Native app: `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- OAuth redirect URI every provider must allow:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- A confidential backend app already exists (`AUTH0_CLIENT_SECRET` in `apps/api/.env`).

## Decisions (from brainstorming)

- **Auth0 setup:** automated via the **Management API (M2M)**, not hand-clicked.
- **Platforms:** iOS + Android (not web).
- **Snapchat:** deferred to phase 2.
- **Testing:** manual end-to-end per provider (real consent screen + real account).
- **Microsoft:** personal accounts only → the built-in `windowslive` connection.
- **Division of labor:**
  - **User** registers the OAuth app in each provider console (requires the user's
    own developer accounts) and hands over the client ID + secret.
  - **Claude** pushes those keys into Auth0 and creates/enables each connection via
    the Management API, does all app code changes, and writes the runbooks.

## The three connections

| Provider | Auth0 connection (strategy) | Provider console + app type | Scopes |
|---|---|---|---|
| Facebook | `facebook` | Meta for Developers → "Consumer" app + Facebook Login product | `public_profile`, `email` |
| Amazon | `amazon` | Login with Amazon → Security Profile | `profile` (name + email) |
| Microsoft (personal) | `windowslive` | Entra ID app registration → "Personal Microsoft accounts only" | `openid`, `email`, `profile` |

All three use the same OAuth **redirect / return URI**:
`https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`

Provider-side notes to capture in the runbooks:
- **Facebook:** Consumer app type; add Facebook Login; app must be in **Live** mode
  for non-test users; `email` permission is "advanced access" and may require Meta
  business verification before general availability.
- **Amazon:** create a Login with Amazon Security Profile; add the Auth0 callback as
  an Allowed Return URL; copy the LWA client id/secret.
- **Microsoft:** Entra app registration with supported account type
  "Personal Microsoft accounts only"; add the Auth0 callback as a Web redirect URI;
  create a client secret.

## Auth0 setup via Management API

**Step 0 — verify M2M access:** first test whether the existing `apps/api/.env`
client is authorized for the Auth0 Management API (grant on
`https://<tenant>/api/v2/`). If not, the user creates a dedicated M2M app authorized
for the Management API with scopes:
`read:connections create:connections update:connections read:clients update:clients`.

**Setup script:** `scripts/auth0/setup-social-connections.mts` (Bun/TypeScript,
strict, TypeBox for any env validation, Winston-free CLI logging acceptable for a
one-off script but prefer no `console.*` noise). For each provider it:

1. Obtains a Management API token via client-credentials.
2. Creates-or-updates the connection (`GET /api/v2/connections?strategy=...` then
   `POST` or `PATCH /api/v2/connections/{id}`) with the provider `client_id`,
   `client_secret`, and scopes.
3. Enables the connection for the **native** app (and SPA if desired) via
   `enabled_clients`.

Requirements: **idempotent** (safe to re-run), keys read from environment variables
(never committed), and a `--verify` mode that lists each connection's strategy and
`enabled_clients` without mutating anything.

## App code changes

In `apps/mobile/lib/core/auth/auth_service.dart` add:

```dart
Future<void> loginWithFacebook() async => _socialLogin('facebook');
Future<void> loginWithAmazon() async => _socialLogin('amazon');
Future<void> loginWithMicrosoft() async => _socialLogin('windowslive');
```

Add the three corresponding buttons to the login screen widget, following the
existing Google/Apple button pattern (Glass theme).

Confirm the existing social-user onboarding handling covers the new providers:
- Empty-email guard (social access tokens may lack `email`) — keep the guard even
  though Facebook/Microsoft/Amazon normally return email.
- Role selection for social users (previously fixed).
- In-app birthday collection (social providers don't supply birthday).

## Testing

- **Config verification:** run the setup script's `--verify` mode (or curl) to
  confirm each connection exists, uses the right strategy, and is enabled for the
  native app.
- **Manual E2E per provider:** a checklist run on emulator/device — Android via
  `adb` (launch via `am start`), iOS via simulator/TestFlight. For each provider:
  tap the button → complete the real consent screen → land on home → profile synced
  (name/avatar/email where available). Claude drives the emulator where possible;
  the user completes the provider consent prompts.
- **Automated tests:** update the widget/unit tests that assert the set of available
  login methods (e.g. `edit_profile_social_test.dart` and login screen tests) to
  include the three new providers.

## Docs & memory

- Per-provider runbooks under `docs/` (exact console steps, redirect URIs, scopes),
  mirroring the style of `docs/auth0-google-oauth.md`.
- An Auth0 Management-API setup doc (M2M app, scopes, running the script).
- Update the auto-memory social-login note with the added providers and the
  Management-API workflow.

## Out of scope

- **Snapchat** — phase 2. Requires a **Custom OAuth2 connection** + Snap **Login
  Kit** + a Snap **Business** account and app review (weeks of lead time, approval
  not guaranteed). Tracked separately as a spike.
- **Web platform** — not targeted now (iOS + Android only). Because it is the same
  Auth0 connection, web would light up later by enabling the connection for the SPA
  app; no design change needed.
- **Sign in with Apple** — already satisfied (Apple is wired), so the App Store
  requirement to offer Apple alongside other social logins is already met.

## Risks / open items

- **M2M access:** if the existing backend app lacks Management API grants, the user
  must create a dedicated M2M app before automation can run (Step 0 handles this).
- **Facebook `email` permission:** may require Meta business verification for
  general availability; test users work immediately in Dev mode.
- **Provider approval latency:** each provider console app is created by the user;
  the automation cannot proceed for a given provider until its client id/secret
  exists.
