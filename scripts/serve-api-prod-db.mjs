/**
 * Runs the API LOCALLY against the PRODUCTION database.
 *
 * This exists so that pointing at production is a deliberate, visible act.
 * apps/api/.env defines MONGODB_URI twice — a localhost value followed by the
 * Atlas one — so a plain `bun src/index.mts` silently resolves to production.
 * That ambiguity is the thing this script removes: you run THIS file when you
 * mean production, and the normal entrypoint when you don't.
 *
 * WHAT THIS IS FOR
 *   Driving the admin portal against real data while the portal has no Auth0
 *   login of its own and therefore cannot be deployed.
 *
 * WHAT YOU ARE TOUCHING
 *   Every write the portal performs hits production immediately and is not
 *   undoable from the UI:
 *     - membership status changes (hide / deactivate / approve)
 *     - gym create, update, verify, owner assignment
 *     - POST /admin/gyms/:id/invite SENDS REAL EMAIL to real addresses
 *
 * AUTH
 *   The admin router requires an identity whose USER RECORD carries
 *   role: "admin" — the token's role claim is overridden by a database lookup.
 *   This script authenticates via the bypass path, so it sets DEMO_USER_ID to
 *   an admin account.
 *
 *   It deliberately uses a LOCAL-ONLY bypass secret, never the one in
 *   apps/api/.env. That .env value is the *production* bypass secret: sending
 *   it to the deployed API authenticates you there as the deployed demo user
 *   (verified — it returns 403, not 401). Keeping the local secret distinct
 *   means the token your browser holds is worthless against production.
 *
 * USAGE
 *   node scripts/serve-api-prod-db.mjs --i-know-this-is-production
 *   (then set devToken in apps/admin/src/environments/environment.development.ts
 *    to the LOCAL_BYPASS_SECRET below, and do not commit it)
 */

import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..');
const API_DIR = resolve(REPO, 'apps/api');

// Local-only. Not the production bypass secret, on purpose.
const LOCAL_BYPASS_SECRET = 'local-admin-only';
// Must be a user whose `role` is "admin" in the production users collection.
const ADMIN_USER_ID = 'google-oauth2|113462336056896342775';

if (!process.argv.includes('--i-know-this-is-production')) {
  console.error('\nRefusing to start: pass --i-know-this-is-production.\n');
  console.error('This runs the API against the PRODUCTION database. Portal');
  console.error('writes are immediate and irreversible, and the invite');
  console.error('endpoint sends real email.\n');
  process.exit(1);
}

// Read MONGODB_URI_PROD, never MONGODB_URI. That separation is the whole
// point: MONGODB_URI is the local default, so nothing reaches production
// unless it goes through this script.
const envText = readFileSync(resolve(API_DIR, '.env'), 'utf8');
let atlasUri = '';
let dbName = 'bjj_open_mat';
for (const line of envText.split(/\r?\n/)) {
  const u = line.match(/^MONGODB_URI_PROD=(.*)$/);
  if (u) atlasUri = u[1].trim();
  const d = line.match(/^MONGODB_DB=(.*)$/);
  if (d) dbName = d[1].trim();
}
if (!atlasUri) {
  console.error('No MONGODB_URI_PROD in apps/api/.env — nothing to connect to.');
  process.exit(1);
}
if (/localhost|127\.0\.0\.1/.test(atlasUri)) {
  console.error('MONGODB_URI_PROD points at localhost; use the normal entrypoint.');
  process.exit(1);
}

const redacted = atlasUri.replace(/\/\/[^@]*@/, '//<credentials>@');
console.log('');
console.log('  ============================================================');
console.log('   API -> PRODUCTION DATABASE');
console.log(`   host : ${redacted.slice(0, 72)}`);
console.log(`   db   : ${dbName}`);
console.log(`   admin: ${ADMIN_USER_ID}`);
console.log('   Portal writes are live. Invites send real email.');
console.log('  ============================================================');
console.log('');

const child = spawn(process.execPath, ['src/index.mts'], {
  cwd: API_DIR,
  stdio: 'inherit',
  env: {
    ...process.env,
    // Real env vars beat .env in Bun, so these win over the duplicated keys.
    MONGODB_URI: atlasUri,
    MONGODB_DB: dbName,
    AUTH_BYPASS_SECRET: LOCAL_BYPASS_SECRET,
    DEMO_USER_ID: ADMIN_USER_ID,
    DEMO_USER_ROLE: 'practitioner',
    DEMO_USER_EMAIL: 'dsylvesteriii@gmail.com',
    WEBSITE_ORIGIN: 'http://localhost:4300',
    PORT: '3100',
  },
});

child.on('exit', (code) => process.exit(code ?? 0));
