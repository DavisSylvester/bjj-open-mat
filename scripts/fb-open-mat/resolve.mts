import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { lookup } from 'zipcodes';
import type { Candidate } from './lib/types.mjs';
import { ApiClient } from './lib/api-client.mjs';
import { resolveCandidates, type ResolveApi } from './lib/resolve-core.mjs';

const OUT_DIR = join(import.meta.dir, '..', '..', 'docs', 'open-mats');
const BASE = process.env.FB_SCRAPER_API_BASE ?? 'https://api.bjj-open-mat.dsylvester.io/api/v1';
const TOKEN = process.env.FB_SCRAPER_API_TOKEN ?? '';
const date = process.argv.slice(2).find((a) => !a.startsWith('--')) ?? new Date().toISOString().slice(0, 10);

const foundPath = join(OUT_DIR, `found-${date}.json`);
const candidates = JSON.parse(readFileSync(foundPath, 'utf8')) as Candidate[];
const client = new ApiClient(BASE, TOKEN);

const api: ResolveApi = {
  geocodeZip: async (zip) => { const r = lookup(zip); return r ? { lat: r.latitude, lng: r.longitude } : null; },
  gymsNear: (lat, lng, r) => client.gymsNear(lat, lng, r),
  sessionsForGym: (id) => client.sessionsForGym(id),
};

const resolved = await resolveCandidates(candidates, api);
const newPath = join(OUT_DIR, `new-${date}.json`);
writeFileSync(newPath, JSON.stringify(resolved, null, 2));
console.log(`Resolved ${candidates.length} candidates → ${resolved.length} new sessions.`);
console.log(`Wrote ${newPath}. Review it, then run insert.mts --commit.`);
