# Auth0 Management API + setup script — Runbook

Configure the Machine-to-Machine (M2M) credentials the setup script needs, then run
`scripts/auth0/setup-social-connections.mts` to create/enable the Facebook, Amazon, and
Microsoft social connections on our tenant.

## Why

The script talks to the **Auth0 Management API** to create social connections and enable
them for the native app. That requires an M2M application that is authorized for the
Management API with connection + client scopes. Without those grants the token request
comes back `access_denied` and nothing can be created.

## Facts / identifiers

- **Auth0 tenant:** `dev-vhvwupdn45hk7gct.us.auth0.com`
- **Auth0 native app:** `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- **Script:** `scripts/auth0/setup-social-connections.mts`
- **Env file:** `scripts/auth0/.env` (gitignored — copy from `scripts/auth0/.env.example`)

## Steps

### 0. Try the existing backend client first  ← do this before creating anything
Our backend already has an Auth0 client (`AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET` in
`apps/api/.env`). It may already carry Management grants — check before creating a new app.

- Copy `scripts/auth0/.env.example` → `scripts/auth0/.env`.
- Set `AUTH0_MGMT_CLIENT_ID` / `AUTH0_MGMT_CLIENT_SECRET` to the existing
  `AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET` values from `apps/api/.env`.
- Run the read-only verify:
  ```
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```
- **If it prints the tenant line + one status line per provider** (`EXISTS`/`MISSING` + `native-enabled`), that client already has
  Management grants — you are done with this step, skip to step 3.
- **If it fails** with `token failed 403`, `access_denied`, or `Grant type not allowed`,
  the client is not authorized for the Management API. Continue to step 1.

### 1. Create a dedicated M2M app (only if step 0 failed)
- Auth0 Dashboard → **Applications → Create Application → Machine to Machine**.
- When prompted, authorize the **Auth0 Management API** with these scopes:
  `read:connections create:connections update:connections read:clients update:clients`.
- Create → open the app → **Settings** → copy the **Client ID** and **Client Secret**.

### 2. Put the M2M credentials in `scripts/auth0/.env`
- Set `AUTH0_MGMT_CLIENT_ID` and `AUTH0_MGMT_CLIENT_SECRET` to the new M2M app's values.
- Re-run `--verify` (step 0) to confirm the token now works.

### 3. Fill in the rest of `scripts/auth0/.env`
Copy from `.env.example` and set:

- `AUTH0_DOMAIN` — `dev-vhvwupdn45hk7gct.us.auth0.com`
- `AUTH0_MGMT_CLIENT_ID` / `AUTH0_MGMT_CLIENT_SECRET` — from step 0 or step 1
- `AUTH0_NATIVE_CLIENT_ID` — `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf` (already defaulted)
- Per-provider credentials, added as you complete each provider runbook:
  - `FACEBOOK_CLIENT_ID` / `FACEBOOK_CLIENT_SECRET` — see `docs/auth0-facebook.md`
  - `AMAZON_CLIENT_ID` / `AMAZON_CLIENT_SECRET` — see `docs/auth0-amazon.md`
  - `MICROSOFT_CLIENT_ID` / `MICROSOFT_CLIENT_SECRET` — see `docs/auth0-microsoft.md`

### 4. Run the script
The script has three modes:

- **Dry-run (default)** — shows what it *would* do, changes nothing:
  ```
  bun run scripts/auth0/setup-social-connections.mts
  ```
- **Commit** — creates/updates the connections and enables them for the native app:
  ```
  bun run scripts/auth0/setup-social-connections.mts --commit
  ```
- **Verify** — read-only report of the tenant + per-provider connection status:
  ```
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```

The script is **dry-run by default** and **skips any provider whose keys are absent** from
`scripts/auth0/.env`, so you can enable providers one at a time — fill in one provider's
keys, `--commit`, `--verify`, then move on to the next.

## Related
- Google is configured manually (own OAuth client) — see `docs/auth0-google-oauth.md`.
- Provider runbooks: `docs/auth0-facebook.md`, `docs/auth0-amazon.md`,
  `docs/auth0-microsoft.md`.
