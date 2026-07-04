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
