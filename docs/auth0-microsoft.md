# Auth0 + Microsoft Account login — Runbook

Register a Microsoft (Entra) app for **personal** Microsoft accounts and enable the Auth0
`windowslive` social connection so users can sign in with Outlook/Hotmail/Live accounts.

## Why

Auth0's **Microsoft Account** social connection (strategy `windowslive`) needs an
**Application (client) ID** and **client secret** from an Entra app registration that
allows our Auth0 tenant's login-callback URL as a redirect URI. Once the keys are in
`scripts/auth0/.env`, the setup script creates/enables the connection.

## Facts / identifiers

- **Auth0 tenant:** `dev-vhvwupdn45hk7gct.us.auth0.com`
- **Auth0 native app:** `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- **Redirect URI (the one Microsoft must allow):**
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Auth0 connection:** name/strategy `windowslive`, scope `openid,profile,email`
- **Env vars:** `MICROSOFT_CLIENT_ID` / `MICROSOFT_CLIENT_SECRET` in `scripts/auth0/.env`

## Steps

### 1. Entra → new app registration
- Go to the **Microsoft Entra admin center** / Azure Portal → **App registrations →
  New registration**.

### 2. Supported account types
- Choose **Personal Microsoft accounts only** (Outlook/Hotmail/Live). This is the account
  set Auth0's `windowslive` connection expects.

### 3. Set the redirect URI
- Under **Redirect URI**, platform **Web**, value:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Register.**

### 4. Copy the Application (client) ID
- On the app's **Overview** page, copy the **Application (client) ID**.

### 5. Create a client secret
- **Certificates & secrets → New client secret** → add a description + expiry → **Add**.
- Copy the secret **Value** immediately (not the **Secret ID**). The Value is shown only
  once — if you navigate away it is unrecoverable and you must create a new one.

### 6. Put the keys in `scripts/auth0/.env`
- `MICROSOFT_CLIENT_ID` = Application (client) ID
- `MICROSOFT_CLIENT_SECRET` = client secret **Value**

### 7. Enable via the setup script
- Commit the connection, then verify:
  ```
  bun run scripts/auth0/setup-social-connections.mts --commit
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```
- Confirm in Auth0 Dashboard → **Authentication → Social** that the `windowslive`
  connection exists, is enabled, and is turned on for **bjj-open-mat-native**.

## Notes / gotchas
- The Auth0 connection name/strategy is `windowslive` — this is Auth0's **"Microsoft
  Account"** social connection, with scope `openid,profile,email`.
- **Personal accounts** = Outlook / Hotmail / Live. This is intentionally *not* the
  work/school (organizational Entra) directory flow.

## Related
- Management API + running the script: `docs/auth0-management-api.md`.
