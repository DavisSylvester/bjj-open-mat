/**
 * Interactive E2E verifier for an Auth0 social connection.
 *
 *   bun run scripts/auth0/e2e-social-login.mts <connection>
 *   # e.g. amazon | facebook | windowslive | google-oauth2 | apple
 *
 * It prints an Auth0 /authorize URL for the native app, then polls the Auth0
 * Management API logs. You open the URL in a browser, complete the provider
 * login, and the script reports PASS (a `s`/`ss` success login event for that
 * connection) or FAIL (an `f*` failed-login event, with the error detail).
 *
 * The final redirect is the app's custom scheme, so the browser can't open it —
 * that's expected; success/failure is read from Auth0's logs, not the browser.
 *
 * Env: reads scripts/auth0/.env then apps/api/.env (same as the setup script).
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { createHash, randomBytes } from 'node:crypto';

function loadEnv(path: string): void {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
loadEnv(join(import.meta.dir, '.env'));
loadEnv(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'));

const connection = process.argv[2] ?? 'amazon';
const DOMAIN = process.env.AUTH0_DOMAIN;
const MGMT_ID = process.env.AUTH0_MGMT_CLIENT_ID;
const MGMT_SECRET = process.env.AUTH0_MGMT_CLIENT_SECRET;
const NATIVE_ID = process.env.AUTH0_NATIVE_CLIENT_ID;
const AUDIENCE = process.env.AUTH0_AUDIENCE ?? '';

if (!DOMAIN || !MGMT_ID || !MGMT_SECRET || !NATIVE_ID) {
  console.error('Missing AUTH0_DOMAIN / AUTH0_MGMT_CLIENT_ID / AUTH0_MGMT_CLIENT_SECRET / AUTH0_NATIVE_CLIENT_ID');
  process.exit(1);
}

const b64url = (b: Buffer): string => b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const verifier = b64url(randomBytes(32));
const challenge = b64url(createHash('sha256').update(verifier).digest());
const redirectUri = `com.davissylvester.bjjopenmat://${DOMAIN}/android/com.davissylvester.bjjopenmat/callback`;

const authorizeUrl =
  `https://${DOMAIN}/authorize?` +
  new URLSearchParams({
    client_id: NATIVE_ID,
    response_type: 'code',
    connection,
    redirect_uri: redirectUri,
    scope: 'openid profile email',
    code_challenge: challenge,
    code_challenge_method: 'S256',
    state: `e2e-${connection}`,
    nonce: `e2e-${connection}-nonce`,
    ...(AUDIENCE ? { audience: AUDIENCE } : {}),
  }).toString();

async function mgmtToken(): Promise<string> {
  const res = await fetch(`https://${DOMAIN}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ grant_type: 'client_credentials', client_id: MGMT_ID, client_secret: MGMT_SECRET, audience: `https://${DOMAIN}/api/v2/` }),
  });
  if (!res.ok) throw new Error(`token failed ${res.status}: ${await res.text()}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

interface LogEntry { date: string; type: string; connection?: string; strategy?: string; description?: string; user_name?: string; details?: { error?: { message?: string } }; }

async function latestLogFor(token: string): Promise<LogEntry | null> {
  const res = await fetch(`https://${DOMAIN}/api/v2/logs?sort=date%3A-1&per_page=25`, { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`logs failed ${res.status}: ${await res.text()}`);
  const logs = (await res.json()) as LogEntry[];
  return logs.find((l) => (l.connection === connection || l.strategy === connection) && /^(s|ss|f|fs|fu|fp)$/.test(l.type)) ?? null;
}

async function main(): Promise<void> {
  const token = await mgmtToken();
  const before = await latestLogFor(token);
  const baselineDate = before?.date ?? '';

  console.log(`\n=== E2E: ${connection} login ===`);
  console.log('1) Open this URL in a browser and complete the provider login:\n');
  console.log(authorizeUrl);
  console.log('\n2) The browser will end on a "can\'t open page" (the app custom scheme) — that is expected.');
  console.log('   Waiting for the Auth0 login result (up to ~3 min)…\n');

  for (let i = 0; i < 36; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const evt = await latestLogFor(token);
    if (evt && evt.date !== baselineDate) {
      const success = evt.type === 's' || evt.type === 'ss';
      if (success) {
        console.log(`✅ PASS — ${connection} login succeeded for ${evt.user_name ?? '(unknown user)'} at ${evt.date}`);
        process.exit(0);
      }
      console.log(`❌ FAIL — ${connection} login failed (${evt.type}) at ${evt.date}: ${evt.description ?? ''} ${evt.details?.error?.message ?? ''}`.trim());
      process.exit(1);
    }
  }
  console.log('⏱️  Timed out waiting for a login event. Re-run and complete the login faster, or check the Auth0 dashboard logs.');
  process.exit(2);
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
