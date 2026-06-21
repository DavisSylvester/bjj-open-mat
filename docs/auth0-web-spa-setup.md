# Auth0 setup for the Flutter **web** login

The web build uses the Authorization Code + PKCE flow via auth0-spa-js. Four tenant-side things must be true or the user never leaves `/login`. Each was a separate failure while bringing this up; fix them in order.

## 1. A dedicated Single Page Application (SPA) client

- Application type: **Single Page Application** (`app_type: spa`).
- **Token Endpoint Authentication Method: `None`** — a browser cannot hold a secret. Using the API's Machine-to-Machine app instead causes `401` at `POST /oauth/token`.
- Grant types include `authorization_code` (+ `refresh_token` if you want silent refresh).
- Put this client's **Client ID** in `apps/mobile/.env` `AUTH0_CLIENT_ID`.

## 2. Register the web origin (per environment)

On the SPA client add the exact origin to: **Allowed Callback URLs**, **Allowed Web Origins**, **Allowed Origins (CORS)**, **Allowed Logout URLs**. Local dev value: `http://localhost:8088` (and `http://localhost:8088/`). **Always drive the app via `localhost`, never `127.0.0.1`** — the redirect_uri must exactly match a registered callback.

## 3. Request the API audience

- `apps/mobile/.env` must set `AUTH0_AUDIENCE` to the API resource-server identifier (here `https://www.bjj-open-mat`), matching `apps/api/.env` `AUTH0_AUDIENCE` (verified at `apps/api/src/auth/jwt-verifier.mts:39`).
- Without it, Auth0 issues an **opaque (JWE) token**, not a JWT, and the API returns `401` at `/api/v1/auth/me`.

## 4. Authorize the SPA for the API in the **user** flow  ← the non-obvious one

The `BJJ-API` resource server has:

```json
{
  "subject_type_authorization": {
    "user":   { "policy": "require_client_grant" },
    "client": { "policy": "require_client_grant" }
  }
}
```

This requires an explicit **client grant whose `subject_type` is `user`** for the authorization_code (user) flow. A default client grant is `subject_type: "client"` (M2M only) and does NOT satisfy it. Symptom: `/authorize` returns `403 invalid_request`, "Client … is not authorized to access resource server …", BEFORE the login form.

`skip_consent_for_verifiable_first_party_clients` is a **red herring** — a public SPA is "non-verifiable", so that flag never applies to it.

## Apply via CLI

Authenticate once (interactive, in your own terminal — the menu needs a TTY):

```bash
auth0 login            # choose "As a user"
```

Then run `scripts/auth0-web-setup.sh <spa-client-id> <api-identifier> <origin>`.

## Diagnosing

- Browser console `401 /oauth/token` ⇒ requirement 1 (app type/secret).
- API log no `/auth/me` + `401 /oauth/token` ⇒ requirement 1.
- `/authorize` `403 ... not authorized to access resource server` ⇒ requirement 4.
- `/auth/me 401` (token is a 5-segment JWE) ⇒ requirement 3 (audience).
- Auth0 logs give the exact reason: `auth0 api get "logs?q=type:f&sort=date:-1"`.
