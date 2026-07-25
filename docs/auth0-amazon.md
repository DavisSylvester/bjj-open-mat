# Auth0 + Login with Amazon — Runbook

Register a Login with Amazon security profile and enable the Auth0 `amazon` social
connection so users can sign in with their Amazon account.

## Why

Auth0's `amazon` connection needs a **Client ID / Client Secret** from a Login with Amazon
security profile that allows our Auth0 tenant's login-callback URL as a return URL. Once
the keys are in `scripts/auth0/.env`, the setup script creates/enables the connection.

## Facts / identifiers

- **Auth0 tenant:** `dev-vhvwupdn45hk7gct.us.auth0.com`
- **Auth0 native app:** `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- **OAuth return URL (the one Amazon must allow):**
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Auth0 connection:** name/strategy `amazon`, scope `profile`
- **Env vars:** `AMAZON_CLIENT_ID` / `AMAZON_CLIENT_SECRET` in `scripts/auth0/.env`

## Steps

### 1. Amazon Developer → create a security profile
- Go to [developer.amazon.com](https://developer.amazon.com) → **Login with Amazon** →
  **Create a New Security Profile**.
- Fill in the security profile **name**, **description**, and a **consent privacy notice
  URL** (required). Save.

### 2. Set the Allowed Return URLs
- Open the security profile → **Web Settings** → **Edit** → **Allowed Return URLs** → add
  exactly:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Save.**

### 3. Copy the Client ID and Client Secret
- Still on **Web Settings**, copy the **Client ID** and reveal + copy the **Client Secret**.

### 4. Put the keys in `scripts/auth0/.env`
- `AMAZON_CLIENT_ID` = Client ID
- `AMAZON_CLIENT_SECRET` = Client Secret

### 5. Enable via the setup script
- Commit the connection, then verify:
  ```
  bun run scripts/auth0/setup-social-connections.mts --commit
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```
- Confirm in Auth0 Dashboard → **Authentication → Social** that the `amazon` connection
  exists, is enabled, and is turned on for **bjj-open-mat-native**.

## Notes / gotchas
- The Auth0 connection name/strategy is `amazon` with scope `profile`, which returns the
  user's **name and email**.

## Related
- Management API + running the script: `docs/auth0-management-api.md`.
