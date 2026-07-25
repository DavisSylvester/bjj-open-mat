/**
 * Idempotently create/update + enable the Facebook, Amazon, and Microsoft
 * (windowslive) social connections in Auth0 via the Management API.
 *
 * SAFE BY DEFAULT — dry run unless --commit is passed:
 *   bun run scripts/auth0/setup-social-connections.mts            # plan only
 *   bun run scripts/auth0/setup-social-connections.mts --commit   # create/update
 *   bun run scripts/auth0/setup-social-connections.mts --verify   # read-only report
 *
 * Env: reads scripts/auth0/.env then falls back to apps/api/.env for AUTH0_DOMAIN.
 * A provider is skipped (with a warning) if its CLIENT_ID/SECRET is absent, so you
 * can enable providers one at a time as their keys arrive.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const COMMIT = process.argv.includes('--commit');
const VERIFY = process.argv.includes('--verify');

function loadEnv(path: string): void {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
loadEnv(join(import.meta.dir, '.env'));
loadEnv(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'));

const DOMAIN = process.env.AUTH0_DOMAIN;
const MGMT_ID = process.env.AUTH0_MGMT_CLIENT_ID;
const MGMT_SECRET = process.env.AUTH0_MGMT_CLIENT_SECRET;
const NATIVE_ID = process.env.AUTH0_NATIVE_CLIENT_ID;

if (!DOMAIN || !MGMT_ID || !MGMT_SECRET || !NATIVE_ID) {
  console.error('Missing AUTH0_DOMAIN / AUTH0_MGMT_CLIENT_ID / AUTH0_MGMT_CLIENT_SECRET / AUTH0_NATIVE_CLIENT_ID');
  process.exit(1);
}

interface ProviderCfg {
  readonly name: string;      // Auth0 connection name (also the strategy for social)
  readonly strategy: string;
  readonly clientId?: string;
  readonly clientSecret?: string;
  readonly scope: string[];
}

const PROVIDERS: ProviderCfg[] = [
  { name: 'facebook', strategy: 'facebook', clientId: process.env.FACEBOOK_CLIENT_ID, clientSecret: process.env.FACEBOOK_CLIENT_SECRET, scope: ['public_profile', 'email'] },
  { name: 'amazon', strategy: 'amazon', clientId: process.env.AMAZON_CLIENT_ID, clientSecret: process.env.AMAZON_CLIENT_SECRET, scope: ['profile'] },
  { name: 'windowslive', strategy: 'windowslive', clientId: process.env.MICROSOFT_CLIENT_ID, clientSecret: process.env.MICROSOFT_CLIENT_SECRET, scope: ['openid', 'profile', 'email'] },
];

async function mgmtToken(): Promise<string> {
  const res = await fetch(`https://${DOMAIN}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'client_credentials',
      client_id: MGMT_ID,
      client_secret: MGMT_SECRET,
      audience: `https://${DOMAIN}/api/v2/`,
    }),
  });
  if (!res.ok) throw new Error(`token failed ${res.status}: ${await res.text()}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

interface Conn { id: string; name: string; strategy: string; enabled_clients?: string[]; }

async function findConn(token: string, strategy: string, name: string): Promise<Conn | null> {
  const res = await fetch(`https://${DOMAIN}/api/v2/connections?strategy=${strategy}&fields=id,name,strategy,enabled_clients&include_fields=true`, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`list ${strategy} failed ${res.status}: ${await res.text()}`);
  const conns = (await res.json()) as Conn[];
  return conns.find((c) => c.name === name) ?? null;
}

async function main(): Promise<void> {
  const token = await mgmtToken();
  console.log(`Auth0 tenant: ${DOMAIN}  (mode: ${VERIFY ? 'verify' : COMMIT ? 'commit' : 'dry-run'})`);

  for (const p of PROVIDERS) {
    const existing = await findConn(token, p.strategy, p.name);

    if (VERIFY) {
      const enabled = existing?.enabled_clients?.includes(NATIVE_ID) ?? false;
      console.log(`${p.name}: ${existing ? 'EXISTS' : 'MISSING'}` + (existing ? `  native-enabled=${enabled}` : ''));
      continue;
    }

    if (!p.clientId || !p.clientSecret) {
      console.log(`${p.name}: SKIP (no client id/secret in env)`);
      continue;
    }

    const enabledClients = Array.from(new Set([...(existing?.enabled_clients ?? []), NATIVE_ID]));
    const body = {
      name: p.name,
      strategy: p.strategy,
      options: { client_id: p.clientId, client_secret: p.clientSecret, scope: p.scope },
      enabled_clients: enabledClients,
    };

    if (!COMMIT) {
      console.log(`${p.name}: would ${existing ? 'PATCH' : 'POST'}  scope=[${p.scope.join(', ')}]  native-enabled=true`);
      continue;
    }

    const url = existing
      ? `https://${DOMAIN}/api/v2/connections/${existing.id}`
      : `https://${DOMAIN}/api/v2/connections`;
    // PATCH must not include name/strategy; POST requires them.
    // Auth0 PATCH replaces the entire `options` object (no deep merge): any option
    // fields previously set on this connection in the dashboard will be dropped.
    if (existing) console.warn(`${p.name}: PATCH replaces ALL connection options with client_id/client_secret/scope only (dashboard-set option fields will be lost).`);
    const payload = existing ? { options: body.options, enabled_clients: body.enabled_clients } : body;
    const res = await fetch(url, {
      method: existing ? 'PATCH' : 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(`${p.name} ${existing ? 'PATCH' : 'POST'} failed ${res.status}: ${await res.text()}`);
    console.log(`${p.name}: ${existing ? 'UPDATED' : 'CREATED'} and enabled for native app.`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
