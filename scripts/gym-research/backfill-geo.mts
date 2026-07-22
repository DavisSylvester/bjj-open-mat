/**
 * Ensure every gym in the `gyms` collection has valid geo — geocoding any that
 * are missing via OSM Nominatim (free, NOT Google). Updates geo in place.
 *
 * Connection reads MONGODB_URI / MONGODB_DB from apps/api/.env.
 * SAFE BY DEFAULT — dry run unless --commit is passed.
 *   bun run scripts/gym-research/backfill-geo.mts            # report only
 *   bun run scripts/gym-research/backfill-geo.mts --commit   # geocode + update
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const COMMIT = process.argv.includes('--commit');
const readEnv = (name: string): string => {
  if (process.env[name]) return process.env[name] as string;
  const env = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
  return (env.match(new RegExp(`^${name}=(.*)$`, 'm'))?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
};

interface GymDoc { _id: string; name: string; address?: string; city?: string; state?: string; postalCode?: string; geo?: { type: 'Point'; coordinates: [number, number] } }

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
const geocodeOne = async (q: string): Promise<{ lat: number; lng: number } | null> => {
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=us&q=${encodeURIComponent(q)}`, { headers: { 'User-Agent': 'bjj-open-mat-research/1.0 (dsylvesteriii@gmail.com)' } });
    const j = (await r.json()) as { lat: string; lon: string }[];
    if (!j[0]) return null;
    return { lat: parseFloat(j[0].lat), lng: parseFloat(j[0].lon) };
  } catch { return null; }
};
const geocodeBest = async (queries: string[]): Promise<{ lat: number; lng: number } | null> => {
  for (const q of queries.filter(Boolean)) {
    const hit = await geocodeOne(q);
    await sleep(1100); // Nominatim policy: <=1 req/s
    if (hit) return hit;
  }
  return null;
};

const invalid = { $or: [{ geo: { $exists: false } }, { geo: null }, { 'geo.coordinates': { $exists: false } }, { 'geo.coordinates': { $size: 0 } }, { 'geo.coordinates': [0, 0] }] };

const main = async (): Promise<void> => {
  const uri = readEnv('MONGODB_URI'), dbName = readEnv('MONGODB_DB');
  // mongodb lives under apps/api/node_modules (not hoisted) — a top-level type import can't resolve from scripts/
  // eslint-disable-next-line @typescript-eslint/consistent-type-imports
  const { MongoClient } = (await import(pathToFileURL(join(import.meta.dir, '..', '..', 'apps', 'api', 'node_modules', 'mongodb', 'lib', 'index.js')).href)) as typeof import('mongodb');
  const client = new MongoClient(uri, { timeoutMS: 20_000 });
  await client.connect();
  try {
    const col = client.db(dbName).collection<GymDoc>('gyms');
    const missing = await col.find(invalid).toArray();
    console.log(`Target: ${uri.replace(/:\/\/[^@]*@/, '://***@')} db=${dbName} | gyms missing geo: ${missing.length}`);
    if (!missing.length) { console.log('All gyms already have geo. Nothing to do.'); return; }

    let fixed = 0, failed = 0;
    for (const g of missing) {
      const q = [
        [g.address, g.city, g.state, g.postalCode].filter(Boolean).join(', '),
        [g.city, g.state, g.postalCode].filter(Boolean).join(', '),
        [g.name, g.city, g.state].filter(Boolean).join(', '),
      ];
      const gc = await geocodeBest(q);
      if (!gc) { failed++; console.log(`  ✗ ${g.name} — no geocode`); continue; }
      const geo = { type: 'Point' as const, coordinates: [gc.lng, gc.lat] as [number, number] };
      if (COMMIT) await col.updateOne({ _id: g._id }, { $set: { geo } });
      fixed++;
      console.log(`  ${COMMIT ? '✓' : '•'} ${g.name} -> [${gc.lng.toFixed(5)}, ${gc.lat.toFixed(5)}]`);
    }
    console.log(`\n${COMMIT ? 'Updated' : 'Would update'}: ${fixed} | failed: ${failed}`);
    if (!COMMIT) console.log('DRY RUN — re-run with --commit to write.');
  } finally { await client.close(); }
};

await main();
