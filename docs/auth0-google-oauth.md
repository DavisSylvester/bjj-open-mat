# Auth0 + Google OAuth (own keys) — Runbook

Replace Auth0's shared **development keys** on the Google (`google-oauth2`) social
connection with our **own Google OAuth client**, so production Google sign-in works
reliably and the consent screen shows "BJJ Open Mat" + our logo instead of Auth0's.

## Why

Auth0 logs this warning during Google login:

> You are using Auth0 development keys which are only intended for use in
> development and testing. This connection (google-oauth2) should be configured
> with your own Development Keys… AUTH0 DEVELOPMENT KEYS SHOULD NOT BE USED ON
> PRODUCTION ENVIRONMENTS.

Dev keys are rate-limited, unsupported for production, and brand the consent
screen as Auth0. The fix is a Google Cloud OAuth client whose ID/secret we paste
into the Auth0 connection.

## Facts / identifiers

- **Auth0 tenant:** `dev-vhvwupdn45hk7gct.us.auth0.com`
- **Auth0 native app:** `bjj-open-mat-native` (client id `su1vKjCPyEIPC63B1IpSjIwhLKHYX0qf`)
- **Google Cloud project:** `bjj-open-mat` (`bjj-open-mat-501702`)
- **OAuth redirect URI (the one Google must allow):**
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- **Consent logo asset:** `docs/branding/google-oauth-consent-logo-512.png`
- Dev contact / owner email: `dsylvesteriii@gmail.com`

## Steps

### 1. Google Cloud Console → Google Auth Platform → Branding
- App name: **BJJ Open Mat**; user support email; upload logo
  (`docs/branding/google-oauth-consent-logo-512.png`).
- **Authorized domains:** add `auth0.com` (the login redirect targets our
  `…us.auth0.com` tenant). Not strictly required while in Testing, but avoids an
  authorized-domain complaint later.
- Home/privacy/ToS links are cosmetic in Testing. NOTE: earlier drafts used
  `dsylvester.ai`, but the domain we actually own for this app is
  **`dsylvester.io`** (`api.bjj-open-mat.dsylvester.io`). Use `.io` before ever
  submitting for verification.
- **Save.**

### 2. Audience page  ← commonly missed
- App is in **Testing** publishing status, so only listed testers can sign in.
- Add your Google account under **Test users** (else Google blocks sign-in with
  "Access denied / app not verified"). Save.

### 3. Data Access page
- Add scopes: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`. Save.

### 4. Clients page → Create OAuth client
- Application type: **Web application**.
- Name: e.g. `Auth0 – BJJ Open Mat`.
- **Authorized redirect URIs** → add exactly:
  `https://dev-vhvwupdn45hk7gct.us.auth0.com/login/callback`
- Create → copy the **Client ID** and **Client secret**.

### 5. Auth0 Dashboard (the step that actually clears the warning)
- **Authentication → Social → Google** (`google-oauth2`).
- Paste the **Client ID** + **Client Secret** (replaces the dev keys).
- Confirm the connection is enabled for the **bjj-open-mat-native** application.
- **Save.**

### 6. Retest
- Trigger Google login in the app. The dev-keys warning disappears and the
  consent screen shows "BJJ Open Mat" + our logo.

## Going to production later
- Move the app from **Testing** → **Production** (Audience page). If we request
  only the basic `openid`/`email`/`profile` scopes, Google verification is
  typically not required; sensitive/restricted scopes would trigger the
  verification flow (needs a verified, owned authorized domain).

## Related
- Consent logo generated with the app icons — see `docs/branding/` and the
  brand-app-icons notes.
- Broader Auth0 setup (Native app type, audience on native login, App Links /
  SHA-256) lives in the mobile Auth0 notes / `docs/`.
