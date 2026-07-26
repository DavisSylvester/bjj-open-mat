import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { ApiClient } from './lib/api-client.mjs';
import type { ResolvedSession } from './lib/resolve-core.mjs';
import { insertSessions, type InsertApi } from './lib/insert-core.mjs';

const OUT_DIR = join(import.meta.dir, '..', '..', 'docs', 'open-mats');
const BASE = process.env.FB_SCRAPER_API_BASE ?? 'https://api.bjj-open-mat.dsylvester.io/api/v1';
const TOKEN = process.env.FB_SCRAPER_API_TOKEN ?? '';
const COMMIT = process.argv.includes('--commit');
const date = process.argv.slice(2).find((a) => !a.startsWith('--')) ?? new Date().toISOString().slice(0, 10);

if (COMMIT && !TOKEN) { console.error('FB_SCRAPER_API_TOKEN is required for --commit.'); process.exit(1); }

const sessions = JSON.parse(readFileSync(join(OUT_DIR, `new-${date}.json`), 'utf8')) as ResolvedSession[];
const client = new ApiClient(BASE, TOKEN);
const api: InsertApi = { createSession: (body) => client.createSession(body) };

const log = await insertSessions(sessions, api, COMMIT);
if (!COMMIT) {
  console.log(`DRY RUN — ${log.planned} sessions would be POSTed to ${BASE}. Re-run with --commit to insert.`);
} else {
  writeFileSync(join(OUT_DIR, `inserted-${date}.json`), JSON.stringify(log, null, 2));
  console.log(`Inserted ${log.inserted.length}/${log.planned}; ${log.errors.length} errors.`);
  const verified = log.inserted.filter((i) => i.verified).length;
  if (verified > 0) console.log(`NOTE: ${verified} landed VERIFIED (your token is admin/owner). Use a practitioner token to keep them unverified.`);
}
