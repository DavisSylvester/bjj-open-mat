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
- Fill in the security profile **name** and **description**. Save. (The create form does
  NOT ask for a privacy URL — that's set in step 3.)

### 2. Set the Allowed Return URLs
- Open the security profile → **Web Settings** → **Edit** → **Allowed Return URLs** → add
  exactly:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Save.**

### 3. Register the profile for Login with Amazon + set the Consent Privacy Notice URL ⚠️ REQUIRED
> Skipping this step causes Amazon to reject the login with a 400 **"An unknown scope was
> requested"** (`lwa-invalid-parameter-bad-scope`) — even though `profile` is a valid scope.
- Go to the **Login with Amazon Console**
  (`developer.amazon.com/loginwithamazon/console/site/lwa/overview.html`).
- If the profile is NOT already under **"Login with Amazon Configurations"**, pick it from
  the **"Select a Security Profile"** dropdown → **Confirm**.
- In the **"Enter Consent Screen Information"** dialog, set **Consent Privacy Notice URL** =
  `https://bjjopenmat.app/privacy` (logo optional) → **Save**.

### 4. Copy the Client ID and the FULL Client Secret ⚠️
- On **Web Settings** (or the LWA console → **Show Client ID and Client Secret**), copy the
  **Client ID** and reveal + copy the **Client Secret**.
- **The secret starts with `amzn1.oa2-cs.v1.`** followed by a 64-char hex string — copy the
  WHOLE thing. Dropping the `amzn1.oa2-cs.v1.` prefix causes Auth0 code-exchange to fail
  with **"Client authentication failed"** (`invalid_request`) at login.

### 5. Put the keys in `scripts/auth0/.env`
- `AMAZON_CLIENT_ID` = Client ID (`amzn1.application-oa2-client.…`)
- `AMAZON_CLIENT_SECRET` = the full secret (`amzn1.oa2-cs.v1.…`)

### 6. Enable via the setup script
- Commit the connection, then verify:
  ```
  bun run scripts/auth0/setup-social-connections.mts --commit
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```
- Confirm in Auth0 Dashboard → **Authentication → Social** that the `amazon` connection
  exists, is enabled, and is turned on for **bjj-open-mat-native**.

### 7. Verify the login end-to-end
```
bun run scripts/auth0/e2e-social-login.mts amazon
```
Open the printed URL, sign in with Amazon; the script reports **PASS** when Auth0 logs a
successful (`s`) login for the `amazon` connection. (The browser ends on a "can't open
page" for the app's custom scheme — that's expected.)

## Notes / gotchas
- The Auth0 connection name/strategy is `amazon` with scope `profile`, which returns the
  user's **name and email**.
- Two failures we actually hit (both fixed above): the missing **Login-with-Amazon
  registration + Consent Privacy Notice URL** (→ "unknown scope"), and a **truncated
  secret** missing the `amzn1.oa2-cs.v1.` prefix (→ "Client authentication failed").

## Related
- Management API + running the script: `docs/auth0-management-api.md`.
- E2E verifier: `scripts/auth0/e2e-social-login.mts <connection>`.
