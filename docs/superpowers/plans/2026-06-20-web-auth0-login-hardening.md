# Web Auth0 Login — Hardening & Reproducibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the now-working web Auth0 login reproducible in any environment and clean up the repo, since the runtime fix (commit `87c3f52`) depends on dev-tenant Auth0 config and a gitignored `.env` that exist nowhere in the repo.

**Architecture:** The code fix shipped in `87c3f52` (SPA-JS load order, email-login button, 401 retry-loop guard, launch flags). The *configuration* it depends on is external: (a) `apps/mobile/.env` values, gitignored; (b) four Auth0 tenant settings. This plan captures (a) as an `.env.example`, captures (b) as a documented + scripted setup, fixes repo hygiene (root-level screenshot ignore), commits the knowledge-base docs, and opens the PR. It does **not** change app code.

**Tech Stack:** Flutter web (`auth0_flutter_web` / auth0-spa-js 2.1), Bun + Elysia API (`jose` JWKS verification), Auth0 (dev tenant `dev-vhvwupdn45hk7gct`), Auth0 CLI v1.31.0.

**Known public (non-secret) config values from this work:**
- `AUTH0_DOMAIN=dev-vhvwupdn45hk7gct.us.auth0.com`
- `AUTH0_CLIENT_ID=uTPDmW3nW7CFTMbgKyZlmTFYJDzIl90m` (SPA app `Bjj-open-mat`)
- `AUTH0_AUDIENCE=https://www.bjj-open-mat` (resource server `BJJ-API`)
- Local web origin / callback: `http://localhost:8088`

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `.gitignore` (root) | Stop tracking root-level debug screenshots | Modify |
| `apps/mobile/.env.example` | Document the required mobile build keys (no secrets) | Create |
| `docs/auth0-web-spa-setup.md` | Reproducible Auth0 tenant setup (manual steps + CLI) | Create |
| `scripts/auth0-web-setup.sh` | One-shot CLI script to apply the Auth0 config to a tenant | Create |
| `docs/knowledge-base/2026-06-18-web-auth0-login-redirect.md` | Existing root-cause writeup | Commit (already on disk) + mark resolved |
| Loose `*.png` in repo root | Debug artifacts from this/prior session | Delete |

---

## Task 1: Ignore root-level debug screenshots and remove the loose ones

**Files:**
- Modify: `.gitignore` (root)

`apps/mobile/.gitignore` already has `*.png`, but the root `.gitignore` does not, so Playwright/debug screenshots dropped in the repo root (`auth0-page.png`, `login-screen.png`, …) show as untracked clutter and risk being committed.

- [ ] **Step 1: Append a screenshot-ignore section to the root `.gitignore`**

Add these lines to the end of `.gitignore` (the leading `/` anchors to repo root only, so it will NOT affect asset PNGs in subdirectories like `apps/mobile/...` or icons):

```gitignore

# Debug/audit screenshots dropped in the repo root
/*.png
```

- [ ] **Step 2: Delete the existing loose debug screenshots**

Run:
```bash
cd /c/projects/davisSylvester/bjj-open-mat
rm -f after-click.png after-login-click.png auth-login-screen.png auth0-page.png \
      auth0-redirect.png auth0-retry.png login-check.png login-error.png \
      login-fixed.png login-screen.png owner-dashboard.png run-verify.png
```

- [ ] **Step 3: Verify the root is clean and the ignore works**

Run: `git status --short`
Expected: no `*.png` entries; `.gitignore` shows as modified (` M .gitignore`).

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore root-level debug screenshots"
```

---

## Task 2: Create `apps/mobile/.env.example`

**Files:**
- Create: `apps/mobile/.env.example`

The real `apps/mobile/.env` is gitignored. Without an example, no teammate or CI run can build a working web login. Client IDs, domains, and API audiences are **public** OIDC values (not secrets), so they are safe to commit verbatim and make onboarding trivial.

- [ ] **Step 1: Create the example file**

Create `apps/mobile/.env.example` with exactly:

```dotenv
# Mobile/web build configuration — consumed via:
#   flutter run --dart-define-from-file=.env ...
# Copy this file to apps/mobile/.env and adjust per environment.
# These Auth0 values are PUBLIC client config (not secrets); the dev-tenant
# values below are safe to use for local development.

# --- Auth0 (Single Page Application client) ---
# Must be a SPA app (Token Endpoint Auth Method = None), NOT the M2M API app.
AUTH0_DOMAIN=dev-vhvwupdn45hk7gct.us.auth0.com
AUTH0_CLIENT_ID=uTPDmW3nW7CFTMbgKyZlmTFYJDzIl90m
# Must equal the API resource-server identifier the backend verifies
# (apps/api/.env AUTH0_AUDIENCE). Required, or the access token is opaque and
# the API rejects it at /auth/me.
AUTH0_AUDIENCE=https://www.bjj-open-mat

# --- Dev-only demo user (optional; used by the API bypass path) ---
DEMO_USER_ID=
DEMO_USER_ROLE=practitioner
DEMO_USER_EMAIL=

# NOTE: API_BASE_URL is passed separately on the command line
#   --dart-define=API_BASE_URL=http://localhost:3100
# (see package.json "mobile:web"), not from this file.
```

- [ ] **Step 2: Confirm it is NOT gitignored (the `!.env.example` allowlist applies)**

Run: `git check-ignore apps/mobile/.env.example; echo "exit=$?"`
Expected: no output and `exit=1` (meaning NOT ignored).

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/.env.example
git commit -m "docs(mobile): add .env.example documenting web Auth0 build keys"
```

---

## Task 3: Document and script the Auth0 tenant setup

**Files:**
- Create: `docs/auth0-web-spa-setup.md`
- Create: `scripts/auth0-web-setup.sh`

The four tenant-side requirements discovered while fixing this live only in the dev tenant. Any new environment (staging/prod/another dev) will hit the same wall without them.

- [ ] **Step 1: Write the setup doc**

Create `docs/auth0-web-spa-setup.md` with exactly:

```markdown
# Auth0 setup for the Flutter **web** login

The web build uses the Authorization Code + PKCE flow via auth0-spa-js. Four
tenant-side things must be true or the user never leaves `/login`. Each was a
separate failure while bringing this up; fix them in order.

## 1. A dedicated Single Page Application (SPA) client
- Application type: **Single Page Application** (`app_type: spa`).
- **Token Endpoint Authentication Method: `None`** — a browser cannot hold a
  secret. Using the API's Machine-to-Machine app instead causes `401` at
  `POST /oauth/token`.
- Grant types include `authorization_code` (+ `refresh_token` if you want
  silent refresh).
- Put this client's **Client ID** in `apps/mobile/.env` `AUTH0_CLIENT_ID`.

## 2. Register the web origin (per environment)
On the SPA client add the exact origin (no trailing slash variations matter —
add both forms) to:
- **Allowed Callback URLs**
- **Allowed Web Origins**
- **Allowed Origins (CORS)**
- **Allowed Logout URLs**

Local dev value: `http://localhost:8088` (and `http://localhost:8088/`).
**Always drive the app via `localhost`, never `127.0.0.1`** — the redirect_uri
must exactly match a registered callback.

## 3. Request the API audience
- `apps/mobile/.env` must set `AUTH0_AUDIENCE` to the API resource-server
  identifier (here `https://www.bjj-open-mat`), matching `apps/api/.env`
  `AUTH0_AUDIENCE` (verified at `apps/api/src/auth/jwt-verifier.mts:39`).
- Without it, Auth0 issues an **opaque (JWE) token**, not a JWT, and the API
  returns `401` at `/api/v1/auth/me`.

## 4. Authorize the SPA for the API in the **user** flow  ← the non-obvious one
The `BJJ-API` resource server has:
\`\`\`json
"subject_type_authorization": {
  "user":   { "policy": "require_client_grant" },
  "client": { "policy": "require_client_grant" }
}
\`\`\`
This requires an explicit **client grant whose `subject_type` is `user`** for
the authorization_code (user) flow. A default client grant is
`subject_type: "client"` (M2M only) and does NOT satisfy it. Symptom:
`/authorize` returns `403 invalid_request`, "Client … is not authorized to
access resource server …", BEFORE the login form.

`skip_consent_for_verifiable_first_party_clients` is a **red herring** — a
public SPA is "non-verifiable", so that flag never applies to it.

## Apply via CLI
Authenticate once (interactive, in your own terminal — the menu needs a TTY):
\`\`\`bash
auth0 login            # choose "As a user"
\`\`\`
Then run `scripts/auth0-web-setup.sh <spa-client-id> <api-identifier> <origin>`.

## Diagnosing
- Browser console `401 /oauth/token` ⇒ requirement 1 (app type/secret).
- API log no `/auth/me` + `401 /oauth/token` ⇒ requirement 1.
- `/authorize` `403 ... not authorized to access resource server` ⇒ requirement 4.
- `/auth/me 401` (token is a 5-segment JWE) ⇒ requirement 3 (audience).
- Auth0 logs give the exact reason: `auth0 api get "logs?q=type:f&sort=date:-1"`.
```

- [ ] **Step 2: Write the setup script**

Create `scripts/auth0-web-setup.sh` with exactly:

```bash
#!/usr/bin/env bash
# Apply the web-SPA Auth0 config to the currently-authenticated tenant.
# Prereq: `auth0 login` (as a user) already run. Requires create:client_grants.
# Usage: scripts/auth0-web-setup.sh <spa_client_id> <api_identifier> <web_origin>
set -euo pipefail

SPA_CLIENT_ID="${1:?spa client id required}"
API_IDENTIFIER="${2:?api identifier (audience) required}"
ORIGIN="${3:?web origin required, e.g. http://localhost:8088}"

echo "1/3 Registering origin ${ORIGIN} on SPA client ${SPA_CLIENT_ID}..."
auth0 api patch "clients/${SPA_CLIENT_ID}" --data "{
  \"callbacks\":[\"${ORIGIN}/\",\"${ORIGIN}\"],
  \"web_origins\":[\"${ORIGIN}\"],
  \"allowed_origins\":[\"${ORIGIN}\"],
  \"allowed_logout_urls\":[\"${ORIGIN}\"]
}" >/dev/null

echo "2/3 Ensuring a subject_type=user client grant for ${API_IDENTIFIER}..."
EXISTING=$(auth0 api get "client-grants?client_id=${SPA_CLIENT_ID}&audience=${API_IDENTIFIER}" 2>/dev/null || echo "[]")
if echo "$EXISTING" | grep -q '"subject_type": *"user"'; then
  echo "    user-subject grant already present."
else
  auth0 api post "client-grants" --data "{
    \"client_id\":\"${SPA_CLIENT_ID}\",
    \"audience\":\"${API_IDENTIFIER}\",
    \"scope\":[],
    \"subject_type\":\"user\"
  }" >/dev/null
  echo "    created user-subject grant."
fi

echo "3/3 Done. Verify a login lands past /login and the API logs /auth/me -> 200."
```

- [ ] **Step 3: Make the script executable and smoke-check its help path**

Run:
```bash
cd /c/projects/davisSylvester/bjj-open-mat
chmod +x scripts/auth0-web-setup.sh
bash scripts/auth0-web-setup.sh || true   # no args -> prints the ":?" usage error
```
Expected: a usage error naming `spa client id required` (proves arg-guards work; it does not call Auth0 without args).

- [ ] **Step 4: Commit**

```bash
git add docs/auth0-web-spa-setup.md scripts/auth0-web-setup.sh
git commit -m "docs: document + script reproducible Auth0 web SPA setup"
```

---

## Task 4: Commit the existing knowledge-base writeup and mark it resolved

**Files:**
- Modify: `docs/knowledge-base/2026-06-18-web-auth0-login-redirect.md`

The root-cause writeup is on disk but untracked. Commit it, and add a resolution note pointing at the fix commit and the setup doc.

- [ ] **Step 1: Append a resolution note to the writeup**

Append to the END of `docs/knowledge-base/2026-06-18-web-auth0-login-redirect.md`:

```markdown

## Resolution (2026-06-20)

Fixed in commit `87c3f52`. Verified end-to-end: login → practitioner home /
role-select, `GET /api/v1/auth/me -> 200` (single call, no retry loop). The
full chain and the non-obvious `subject_type_authorization` requirement are
documented in [auth0-web-spa-setup.md](../auth0-web-spa-setup.md). The four
tenant-side requirements are NOT in the repo — apply them per environment with
`scripts/auth0-web-setup.sh`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/knowledge-base/2026-06-18-web-auth0-login-redirect.md
git commit -m "docs: commit web Auth0 login root-cause writeup + resolution"
```

---

## Task 5: Open the pull request

**Files:** none.

- [ ] **Step 1: Push the accumulated commits**

Run:
```bash
cd /c/projects/davisSylvester/bjj-open-mat
git push
```
Expected: pushes Task 1–4 commits to `origin/feature/monorepo-restructure`.

- [ ] **Step 2: Create the PR with `gh`**

Run:
```bash
gh pr create --base main --head feature/monorepo-restructure \
  --title "fix(auth): web Auth0 login works end-to-end + monorepo restructure" \
  --body "Completes the Flutter web Auth0 login (SPA-JS load order, email-login button, audience, 401 retry-loop guard, launch flags) and documents the reproducible Auth0 tenant setup. Tenant config (SPA app, web origins, subject_type:user client grant) must be applied per environment via scripts/auth0-web-setup.sh — see docs/auth0-web-spa-setup.md."
```
Expected: prints the new PR URL.

- [ ] **Step 3: Confirm**

Run: `gh pr view --json url,state,title`
Expected: `state: OPEN` with the title above.

---

## Appendix (optional investigation, not required for the fix): release web build renders blank

During verification, `flutter build web` (release, dart2js + CanvasKit) rendered a blank page when served statically, while `flutter run -d web-server` (debug) rendered correctly. The debug build is sufficient for local dev, but if you ship the web build, investigate:

- [ ] **Step A:** Build and serve release, capture uncaught JS errors:
  ```bash
  cd apps/mobile && /c/apps/flutter/bin/flutter.bat build web \
    --dart-define-from-file=.env --dart-define=API_BASE_URL=http://localhost:3100
  ```
  Serve `build/web` with a single threaded static server (correct `.wasm` MIME), open it, and in DevTools run `window.addEventListener('error', e => console.log('ERR', e.message))` before reload. Capture whether `flutter.js` / `main.dart.js` / `canvaskit.wasm` all load 200 and whether a `flutter-view` element is ever created.
- [ ] **Step B:** If CanvasKit is the cause, try `--web-renderer html` (or the `flutter_bootstrap.js` renderer config) and re-test.
- [ ] **Step C:** File findings in `docs/knowledge-base/` and, if a config fix is found, fold it into `package.json` `mobile:build`.

> Reminder: serve via a single server on a clean port. Multiple servers / a stray `flutter run` racing on port 8088 (SO_REUSEADDR) produce intermittent blank screens — confirm exactly one listener (`netstat -ano | grep ':8088 ' | grep LISTENING | wc -l` → `1`).

---

## Self-Review

- **Spec coverage:** Follow-ups raised after commit `87c3f52` — (1) `.env.example` → Task 2; (2) ignore root screenshots → Task 1; (3) reproduce Auth0 tenant config across environments → Task 3 (doc + script) + Task 4 (writeup); (4) open the PR → Task 5; (5) release-build-blank → Appendix (explicitly optional). Covered.
- **Placeholder scan:** No TODO/TBD. `.env.example`, the setup doc, and the script contain full literal content. `DEMO_USER_ID`/`DEMO_USER_EMAIL` are intentionally blank in the example (per-developer optional values), with `DEMO_USER_ROLE` defaulted — documented inline, not a gap.
- **Type/value consistency:** `AUTH0_CLIENT_ID=uTPDmW3nW7CFTMbgKyZlmTFYJDzIl90m`, `AUTH0_AUDIENCE=https://www.bjj-open-mat`, domain `dev-vhvwupdn45hk7gct.us.auth0.com`, and origin `http://localhost:8088` are identical across the example, the doc, and the script args. The script's `subject_type:"user"` grant matches requirement 4 in the doc. No secrets are committed (real `.env` stays gitignored; only public OIDC client values appear).
