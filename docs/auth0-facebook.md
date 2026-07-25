# Auth0 + Facebook (Meta) login — Runbook

Register a Facebook (Meta) OAuth app and enable the Auth0 `facebook` social connection so
users can sign in with Facebook.

## Why

Auth0's `facebook` connection needs an **App ID / App Secret** from a Meta app that allows
our Auth0 tenant's login-callback URL as an OAuth redirect. Once the keys are in
`scripts/auth0/.env`, the setup script creates/enables the connection.

## Facts / identifiers

- **Auth0 tenant:** `dev-vhvwupdn45hk7gct.us.auth0.com`
- **Auth0 native app:** `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- **OAuth redirect URI (the one Meta must allow):**
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Auth0 connection:** name/strategy `facebook`, scope `public_profile,email`
- **Env vars:** `FACEBOOK_CLIENT_ID` / `FACEBOOK_CLIENT_SECRET` in `scripts/auth0/.env`

## Steps

### 1. Meta for Developers → create an app
- Go to [developers.facebook.com](https://developers.facebook.com) → **My Apps → Create App**.
- App type: **Consumer**. Give it a name (e.g. `BJJ Open Mat`) and finish creation.

### 2. Add the Facebook Login product
- On the app dashboard, **Add Product** → **Facebook Login** → **Set up**.

### 3. Set the Valid OAuth Redirect URI
- **Facebook Login → Settings** → **Valid OAuth Redirect URIs** → add exactly:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Save Changes.**

### 4. Copy the App ID and App Secret
- **Settings → Basic** → copy the **App ID** and click **Show** to reveal the **App Secret**.

### 5. Put the keys in `scripts/auth0/.env`
- `FACEBOOK_CLIENT_ID` = App ID
- `FACEBOOK_CLIENT_SECRET` = App Secret

### 6. Enable via the setup script
- Commit the connection, then verify:
  ```
  bun run scripts/auth0/setup-social-connections.mts --commit
  bun run scripts/auth0/setup-social-connections.mts --verify
  ```
- Confirm in Auth0 Dashboard → **Authentication → Social** that the `facebook` connection
  exists, is enabled, and is turned on for **bjj-open-mat-native**.

## Notes / gotchas
- **App mode:** while the app is in **Development** mode only the app's own test users /
  admins/developers can log in. Switch the app to **Live** mode before real users can sign
  in (top toggle on the dashboard).
- **`email` permission:** `public_profile` is standard access, but `email` is
  **advanced access** and may require Meta **business verification** before it is generally
  available. Test users work in Development mode immediately, so you can validate the flow
  before verification completes.
- The Auth0 connection name/strategy is `facebook` with scope `public_profile,email`.

## Related
- Management API + running the script: `docs/auth0-management-api.md`.
