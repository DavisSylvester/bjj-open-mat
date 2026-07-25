# Facebook / Amazon / Microsoft Social Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users sign into the BJJ Open Mat mobile app with Facebook, Amazon, and Microsoft (personal) accounts on iOS + Android, with the Auth0 connections created/enabled via the Management API.

**Architecture:** All social login is already brokered by Auth0 Universal Login through `auth0_flutter`'s `webAuthentication` (custom scheme `com.davissylvester.bjjopenmat`). Adding a provider = a login button that calls `_socialLogin('<connection>')`, plus an Auth0 connection carrying the provider's OAuth keys and enabled for the native app. No on-device provider SDKs. Auth0 setup is automated by an idempotent Bun/TypeScript Management-API script; the provider OAuth apps are registered by the user (their developer accounts) following per-provider runbooks.

**Tech Stack:** Flutter/Dart (mobile app), Riverpod, `auth0_flutter`; Bun + TypeScript (strict, TypeBox) for the Auth0 setup script; Auth0 Management API v2.

**Reference spec:** `docs/superpowers/specs/2026-07-24-social-login-fb-amazon-msft-design.md`

---

## File Structure

**Create:**
- `scripts/auth0/setup-social-connections.mts` — idempotent Management-API script: create/update + enable the `facebook`, `amazon`, `windowslive` connections; `--verify` (read-only) and `--commit` (mutating) modes; dry-run by default.
- `scripts/auth0/.env.example` — documents the env vars the script reads (no secrets).
- `docs/auth0-management-api.md` — how to obtain/verify Management-API access and run the script.
- `docs/auth0-facebook.md` — Meta for Developers runbook.
- `docs/auth0-amazon.md` — Login with Amazon runbook.
- `docs/auth0-microsoft.md` — Entra ID (personal accounts) runbook.
- `apps/mobile/test/features/login_screen_test.dart` — widget test asserting the provider buttons render.

**Modify:**
- `apps/mobile/lib/core/auth/auth_service.dart` — add `loginWithFacebook`, `loginWithAmazon`, `loginWithMicrosoft`.
- `apps/mobile/lib/features/onboarding/screens/login_screen.dart` — add three `_SocialLoginButton`s.
- `.gitignore` — ensure `scripts/auth0/.env` is ignored.
- `C:\Users\davis\.claude\projects\C--projects-davisSylvester-bjj-open-mat\memory\MEMORY.md` + a memory note — record the added providers + workflow (final task).

---

## Task 1: Mobile — login methods + buttons (TDD)

**Files:**
- Test: `apps/mobile/test/features/login_screen_test.dart` (create)
- Modify: `apps/mobile/lib/core/auth/auth_service.dart:262-265`
- Modify: `apps/mobile/lib/features/onboarding/screens/login_screen.dart:73-86`

- [ ] **Step 1: Write the failing widget test**

Create `apps/mobile/test/features/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/app/theme.dart';
import 'package:bjj_open_mat/features/onboarding/screens/login_screen.dart';

// Unauthenticated state so LoginScreen renders without triggering navigation
// (the ref.listen redirect only fires on AuthStatus.authenticated).
class _UnauthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  testWidgets('login screen shows Google, Apple, Facebook, Amazon, Microsoft, email', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith(_UnauthNotifier.new)],
      child: MaterialApp(theme: AppTheme.glass(), home: const LoginScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Amazon'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });
}
```

Note: if `AppTheme.glass()` is not the theme accessor used elsewhere, mirror the import used in `apps/mobile/test/features/edit_profile_social_test.dart` (`package:bjj_open_mat/core/design/app_theme.dart`). Verify the correct import before running.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/mobile && flutter test test/features/login_screen_test.dart`
Expected: FAIL — "Continue with Facebook" (and Amazon/Microsoft) not found.

- [ ] **Step 3: Add the three login methods**

In `apps/mobile/lib/core/auth/auth_service.dart`, immediately after the existing `loginWithApple` line (around line 263), add:

```dart
  Future<void> loginWithFacebook() async => _socialLogin('facebook');
  Future<void> loginWithAmazon() async => _socialLogin('amazon');
  Future<void> loginWithMicrosoft() async => _socialLogin('windowslive');
```

- [ ] **Step 4: Add the three buttons**

In `apps/mobile/lib/features/onboarding/screens/login_screen.dart`, after the Apple button block (after line 73's `SizedBox`) and before the email button, insert:

```dart
              // Facebook login
              _SocialLoginButton(
                label: 'Continue with Facebook',
                icon: Icons.facebook,
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithFacebook();
                },
              ),
              const SizedBox(height: StitchTokens.md),

              // Amazon login
              _SocialLoginButton(
                label: 'Continue with Amazon',
                icon: Icons.shopping_bag_outlined,
                backgroundColor: const Color(0xFFFF9900),
                foregroundColor: Colors.black,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithAmazon();
                },
              ),
              const SizedBox(height: StitchTokens.md),

              // Microsoft login
              _SocialLoginButton(
                label: 'Continue with Microsoft',
                icon: Icons.window,
                backgroundColor: Colors.white,
                foregroundColor: StitchTokens.primary,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithMicrosoft();
                },
              ),
              const SizedBox(height: StitchTokens.md),
```

(Icons are cosmetic — Material has no brand glyphs for Amazon/Microsoft; these are acceptable placeholders.)

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd apps/mobile && flutter test test/features/login_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Run analyzer + full mobile test suite**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: no analyzer errors; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/core/auth/auth_service.dart apps/mobile/lib/features/onboarding/screens/login_screen.dart apps/mobile/test/features/login_screen_test.dart
git commit -m "feat(mobile): add Facebook, Amazon, and Microsoft login buttons"
```

---

## Task 2: Auth0 Management-API setup script

**Files:**
- Create: `scripts/auth0/setup-social-connections.mts`
- Create: `scripts/auth0/.env.example`
- Modify: `.gitignore`

- [ ] **Step 1: Ignore the secrets file**

Add to `.gitignore` (if not already covered by an existing `.env` rule — verify first):

```
scripts/auth0/.env
```

- [ ] **Step 2: Create the env example**

Create `scripts/auth0/.env.example`:

```
# Auth0 tenant (already in apps/api/.env as AUTH0_DOMAIN)
AUTH0_DOMAIN=dev-vhvwupdn45hk7gct.us.auth0.com

# Management API M2M credentials (see docs/auth0-management-api.md).
# May be the existing apps/api/.env client IF it has api/v2 grants; otherwise a
# dedicated M2M app.
AUTH0_MGMT_CLIENT_ID=
AUTH0_MGMT_CLIENT_SECRET=

# The native app whose enabled_clients each connection is added to.
AUTH0_NATIVE_CLIENT_ID=su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf

# Provider OAuth app credentials (created by you in each provider console).
FACEBOOK_CLIENT_ID=
FACEBOOK_CLIENT_SECRET=
AMAZON_CLIENT_ID=
AMAZON_CLIENT_SECRET=
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=
```

- [ ] **Step 3: Write the script**

Create `scripts/auth0/setup-social-connections.mts`:

```typescript
/**
 * Idempotently create/update + enable the Facebook, Amazon, and Microsoft
 * (windowslive) social connections in Auth0 via the Management API.
 *
 * SAFE BY DEFAULT — dry run unless --commit is passed:
 *   bun run scripts/auth0/setup-social-connections.mts            # plan only
 *   bun run scripts/auth0/setup-social-connections.mts --commit   # create/update
 *   bun run scripts/auth0/setup-social-connections.mts --verify   # read-only report
 *
 * Env: reads scripts/auth0/.env then falls back to apps/api/.env for AUTH0_DOMAIN.
 * A provider is skipped (with a warning) if its CLIENT_ID/SECRET is absent, so you
 * can enable providers one at a time as their keys arrive.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const COMMIT = process.argv.includes('--commit');
const VERIFY = process.argv.includes('--verify');

function loadEnv(path: string): void {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
loadEnv(join(import.meta.dir, '.env'));
loadEnv(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'));

const DOMAIN = process.env.AUTH0_DOMAIN;
const MGMT_ID = process.env.AUTH0_MGMT_CLIENT_ID;
const MGMT_SECRET = process.env.AUTH0_MGMT_CLIENT_SECRET;
const NATIVE_ID = process.env.AUTH0_NATIVE_CLIENT_ID;

if (!DOMAIN || !MGMT_ID || !MGMT_SECRET || !NATIVE_ID) {
  console.error('Missing AUTH0_DOMAIN / AUTH0_MGMT_CLIENT_ID / AUTH0_MGMT_CLIENT_SECRET / AUTH0_NATIVE_CLIENT_ID');
  process.exit(1);
}

interface ProviderCfg {
  readonly name: string;      // Auth0 connection name (also the strategy for social)
  readonly strategy: string;
  readonly clientId?: string;
  readonly clientSecret?: string;
  readonly scope: string[];
}

const PROVIDERS: ProviderCfg[] = [
  { name: 'facebook', strategy: 'facebook', clientId: process.env.FACEBOOK_CLIENT_ID, clientSecret: process.env.FACEBOOK_CLIENT_SECRET, scope: ['public_profile', 'email'] },
  { name: 'amazon', strategy: 'amazon', clientId: process.env.AMAZON_CLIENT_ID, clientSecret: process.env.AMAZON_CLIENT_SECRET, scope: ['profile'] },
  { name: 'windowslive', strategy: 'windowslive', clientId: process.env.MICROSOFT_CLIENT_ID, clientSecret: process.env.MICROSOFT_CLIENT_SECRET, scope: ['openid', 'profile', 'email'] },
];

async function mgmtToken(): Promise<string> {
  const res = await fetch(`https://${DOMAIN}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'client_credentials',
      client_id: MGMT_ID,
      client_secret: MGMT_SECRET,
      audience: `https://${DOMAIN}/api/v2/`,
    }),
  });
  if (!res.ok) throw new Error(`token failed ${res.status}: ${await res.text()}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

interface Conn { id: string; name: string; strategy: string; enabled_clients?: string[]; }

async function findConn(token: string, strategy: string, name: string): Promise<Conn | null> {
  const res = await fetch(`https://${DOMAIN}/api/v2/connections?strategy=${strategy}&fields=id,name,strategy,enabled_clients&include_fields=true`, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`list ${strategy} failed ${res.status}: ${await res.text()}`);
  const conns = (await res.json()) as Conn[];
  return conns.find((c) => c.name === name) ?? null;
}

async function main(): Promise<void> {
  const token = await mgmtToken();
  console.log(`Auth0 tenant: ${DOMAIN}  (mode: ${VERIFY ? 'verify' : COMMIT ? 'commit' : 'dry-run'})`);

  for (const p of PROVIDERS) {
    const existing = await findConn(token, p.strategy, p.name);

    if (VERIFY) {
      const enabled = existing?.enabled_clients?.includes(NATIVE_ID) ?? false;
      console.log(`${p.name}: ${existing ? 'EXISTS' : 'MISSING'}` + (existing ? `  native-enabled=${enabled}` : ''));
      continue;
    }

    if (!p.clientId || !p.clientSecret) {
      console.log(`${p.name}: SKIP (no client id/secret in env)`);
      continue;
    }

    const enabledClients = Array.from(new Set([...(existing?.enabled_clients ?? []), NATIVE_ID]));
    const body = {
      name: p.name,
      strategy: p.strategy,
      options: { client_id: p.clientId, client_secret: p.clientSecret, scope: p.scope },
      enabled_clients: enabledClients,
    };

    if (!COMMIT) {
      console.log(`${p.name}: would ${existing ? 'PATCH' : 'POST'}  scope=[${p.scope.join(', ')}]  native-enabled=true`);
      continue;
    }

    const url = existing
      ? `https://${DOMAIN}/api/v2/connections/${existing.id}`
      : `https://${DOMAIN}/api/v2/connections`;
    // PATCH must not include name/strategy; POST requires them.
    const payload = existing ? { options: body.options, enabled_clients: body.enabled_clients } : body;
    const res = await fetch(url, {
      method: existing ? 'PATCH' : 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(`${p.name} ${existing ? 'PATCH' : 'POST'} failed ${res.status}: ${await res.text()}`);
    console.log(`${p.name}: ${existing ? 'UPDATED' : 'CREATED'} and enabled for native app.`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
```

Note on scopes: Auth0's Management-API option schema for `windowslive`/`amazon` can differ (some strategies use boolean scope flags rather than a `scope` array). The `--verify` step + a dashboard glance in Task 5 confirm the connection is correctly shaped; adjust the `scope` field only if the API rejects it.

- [ ] **Step 4: Type-check the script**

Run: `bun build scripts/auth0/setup-social-connections.mts --target=bun --outfile=/dev/null`
Expected: builds with no type/parse errors. (If the repo has a root `tsc`/eslint task for scripts, run that instead.)

- [ ] **Step 5: Commit**

```bash
git add scripts/auth0/setup-social-connections.mts scripts/auth0/.env.example .gitignore
git commit -m "feat(auth0): idempotent Management-API script to set up social connections"
```

---

## Task 3: Verify Management-API access (Step 0 gate)

**Goal:** determine whether the existing `apps/api/.env` client can call the Management API, or whether a dedicated M2M app is required. **This task involves live Auth0 calls — no code changes.**

- [ ] **Step 1: Try the existing backend client**

Populate `scripts/auth0/.env` with `AUTH0_MGMT_CLIENT_ID` / `AUTH0_MGMT_CLIENT_SECRET` set to the existing `AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET` values from `apps/api/.env`, then run:

Run: `bun run scripts/auth0/setup-social-connections.mts --verify`

- [ ] **Step 2: Interpret the result**

- If it prints the tenant line and a status per provider → the client has Management-API grants. **Proceed.**
- If it fails at `token failed 403` / `access_denied` / `Grant type not allowed` → the client is NOT Management-scoped.

- [ ] **Step 3 (only if not scoped): HUMAN — create a dedicated M2M app**

In the Auth0 dashboard: **Applications → Create Application → Machine to Machine** → authorize the **Auth0 Management API** with scopes:
`read:connections create:connections update:connections read:clients update:clients`.
Put its client id/secret into `scripts/auth0/.env` as `AUTH0_MGMT_CLIENT_ID` / `AUTH0_MGMT_CLIENT_SECRET`, then re-run `--verify` and confirm it succeeds.

- [ ] **Step 4: No commit** (this task changes only the gitignored `scripts/auth0/.env`).

---

## Task 4: Provider registration runbooks (docs)

**Files:** create `docs/auth0-management-api.md`, `docs/auth0-facebook.md`, `docs/auth0-amazon.md`, `docs/auth0-microsoft.md`.

Model the tone/detail on the existing `docs/auth0-google-oauth.md`. The single redirect/return URI every provider must allow is:
`https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`

- [ ] **Step 1: Write `docs/auth0-management-api.md`**

Content must cover: what the M2M app is, the required scopes (`read:connections create:connections update:connections read:clients update:clients`), how to fill `scripts/auth0/.env`, and the three run modes (`--verify`, dry-run, `--commit`).

- [ ] **Step 2: Write `docs/auth0-facebook.md`**

Steps: Meta for Developers → create app (type **Consumer**) → add **Facebook Login** product → Settings → **Valid OAuth Redirect URIs** = the callback URI above → copy **App ID** + **App Secret** → note the app must be switched to **Live** mode for non-test users, and that the `email` permission may need Meta business verification for advanced access. Where to paste keys: `scripts/auth0/.env` as `FACEBOOK_CLIENT_ID` / `FACEBOOK_CLIENT_SECRET`.

- [ ] **Step 3: Write `docs/auth0-amazon.md`**

Steps: Login with Amazon → create a **Security Profile** → Web Settings → **Allowed Return URLs** = the callback URI above → copy **Client ID** + **Client Secret** → paste into `scripts/auth0/.env` as `AMAZON_CLIENT_ID` / `AMAZON_CLIENT_SECRET`.

- [ ] **Step 4: Write `docs/auth0-microsoft.md`**

Steps: Entra ID → **App registrations → New registration** → supported account types = **Personal Microsoft accounts only** → Redirect URI (type **Web**) = the callback URI above → **Certificates & secrets → New client secret** → copy the **Application (client) ID** and the secret **value** → paste into `scripts/auth0/.env` as `MICROSOFT_CLIENT_ID` / `MICROSOFT_CLIENT_SECRET`. Note the connection strategy in Auth0 is `windowslive`.

- [ ] **Step 5: Commit**

```bash
git add docs/auth0-management-api.md docs/auth0-facebook.md docs/auth0-amazon.md docs/auth0-microsoft.md
git commit -m "docs(auth0): provider runbooks for Facebook, Amazon, Microsoft, and Management API"
```

---

## Task 5: Enable each connection (per provider, human-gated)

**Goal:** with provider keys in `scripts/auth0/.env`, create+enable each connection. Repeat per provider as keys arrive; the script skips providers whose keys are absent.

- [ ] **Step 1: HUMAN — register the provider app** following the relevant runbook from Task 4 and paste its keys into `scripts/auth0/.env`.

- [ ] **Step 2: Dry-run**

Run: `bun run scripts/auth0/setup-social-connections.mts`
Expected: the newly-keyed provider shows `would POST` (or `would PATCH`) with `native-enabled=true`; keyless providers show `SKIP`.

- [ ] **Step 3: Commit the change to Auth0**

Run: `bun run scripts/auth0/setup-social-connections.mts --commit`
Expected: `CREATED`/`UPDATED and enabled for native app.`

- [ ] **Step 4: Verify**

Run: `bun run scripts/auth0/setup-social-connections.mts --verify`
Expected: provider prints `EXISTS  native-enabled=true`.

- [ ] **Step 5: Dashboard confirmation**

In Auth0 → **Authentication → Social**, open the connection and confirm the strategy, keys, scopes, and that `bjj-open-mat-native` is a listed application. Adjust the script's `scope` only if the dashboard/API flagged an issue.

- [ ] **Step 6: No repo commit** (Auth0-side state only; `scripts/auth0/.env` is gitignored). Repeat Steps 1–5 for the remaining providers.

---

## Task 6: Manual E2E per provider

**Goal:** prove real end-to-end login for each enabled provider on a device/emulator. See memory notes [[android-emulator-run]] and [[mobile-auth0-native-login]] for launch mechanics (use `adb am start`; on Android emulator the API base is `10.0.2.2:3100`).

- [ ] **Step 1: Build + install the app on an Android emulator** with the Auth0 dart-defines (see `apps/mobile/.env` / existing run scripts), then launch via `adb shell am start`.

- [ ] **Step 2: For each of Facebook, Amazon, Microsoft** — tap the button, complete the real provider consent screen with a real account, and confirm: the app lands on `/role-select` (first login) or home, and the profile syncs (display name / avatar / email where the provider returns it).

- [ ] **Step 3: Record results** — note per provider: success/fail, whether email was returned, and any consent-screen quirks. If a provider fails, capture the Auth0 log (dashboard → Monitoring → Logs) and the `authState.error` shown on the login screen.

- [ ] **Step 4 (iOS, optional this pass):** repeat on iOS simulator or via TestFlight. iOS uses the same connections; no Auth0 change needed.

- [ ] **Step 5: No code change expected.** If a fix is needed (e.g. empty-email onboarding), branch into `superpowers:systematic-debugging`.

---

## Task 7: Memory + finalize

- [ ] **Step 1: Update the social-login memory note**

Update the existing `social-login-user-record-gotchas.md` memory (or add a new note) to record: providers now supported (Google, Apple, Facebook, Amazon, Microsoft-personal via `windowslive`), that setup is automated via `scripts/auth0/setup-social-connections.mts` + the Management API, and that Snapchat is deferred (custom OAuth2 + Login Kit). Add a matching one-line pointer in `MEMORY.md` if a new note is created.

- [ ] **Step 2: Final analyzer + test gate**

Run: `cd apps/mobile && flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin feature/social-login-fb-amazon-msft
gh pr create --fill --base main
```

---

## Self-Review notes

- **Spec coverage:** three connections (Task 2/5), Management-API automation (Task 2/3), app buttons+methods (Task 1), manual E2E per provider (Task 6), docs/runbooks (Task 4), memory (Task 7), Snapchat/web explicitly out of scope (spec). All covered.
- **Human-gated tasks** (3 Step 3, 5 Step 1, 6) are external dependencies (provider consoles, real consent) that cannot be automated; they are called out explicitly rather than hidden.
- **Type consistency:** connection names/strategies (`facebook`, `amazon`, `windowslive`) and env var names are identical across the script, `.env.example`, and runbooks. Dart method names (`loginWithFacebook/Amazon/Microsoft`) match between `auth_service.dart` and `login_screen.dart`.
