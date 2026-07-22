/**
 * Phase 5b — Seed runner. Upserts data/gyms.seed.json into the `gyms` collection.
 *
 * Idempotent: upserts by _id, so re-running refreshes rather than duplicates.
 * Ensures the 2dsphere index on `geo` (matches GymRepository.ensureIndexes).
 *
 * SAFE BY DEFAULT — dry run unless --commit is passed:
 *   bun run scripts/gym-research/seed-gyms.mts            # validate + plan only, no DB
 *   bun run scripts/gym-research/seed-gyms.mts --commit   # connect + upsert
 *
 * Connection: reads MONGODB_URI / MONGODB_DB from apps/api/.env (override via env).
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const COMMIT = process.argv.includes('--commit');

interface GymDoc { _id: string; name: string; geo: { type: 'Point'; coordinates: [number, number] }; [k: string]: unknown; }

const docs = JSON.parse(readFileSync(join(DATA, 'gyms.seed.json'), 'utf8')) as GymDoc[];

// --- validate the seed before touching anything ---
const problems: string[] = [];
const ids = new Set<string>();
for (const d of docs) {
  if (!d._id) problems.push(`missing _id: ${d.name}`);
  if (ids.has(d._id)) problems.push(`duplicate _id: ${d._id}`);
  ids.add(d._id);
  const c = d.geo?.coordinates;
  if (!c || c.length !== 2 || typeof c[0] !== 'number' || typeof c[1] !== 'number') problems.push(`bad geo: ${d.name}`);
  else if (c[0] > 0 || c[1] < 0) problems.push(`geo looks like [lat,lng] not [lng,lat]: ${d.name}`);
}
if (problems.length) {
   
  console.error(`Seed validation FAILED (${problems.length}):\n` + problems.slice(0, 20).join('\n'));
  process.exit(1);
}
 
console.log(`Seed valid: ${docs.length} docs, ${ids.size} unique _id, geo order OK.`);

if (!COMMIT) {
   
  console.log('\nDRY RUN — no database connection made. Re-run with --commit to upsert.');
  process.exit(0);
}

// --- commit path ---
const readEnv = (name: string): string => {
  if (process.env[name]) return process.env[name] as string;
  const env = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
  const m = env.match(new RegExp(`^${name}=(.*)$`, 'm'));
  return (m?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
};

const uri = readEnv('MONGODB_URI');
const dbName = readEnv('MONGODB_DB');
if (!uri || !dbName) { console.error('MONGODB_URI / MONGODB_DB not set'); process.exit(1); }

const { pathToFileURL } = await import('node:url');
const mongoEntry = join(import.meta.dir, '..', '..', 'apps', 'api', 'node_modules', 'mongodb', 'lib', 'index.js');
// mongodb lives under apps/api/node_modules (not hoisted) — a top-level type import can't resolve from scripts/
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
const { MongoClient } = (await import(pathToFileURL(mongoEntry).href)) as typeof import('mongodb');
const client = new MongoClient(uri, { timeoutMS: 20_000 });
try {
  await client.connect();
  const col = client.db(dbName).collection<GymDoc>('gyms');
  await col.createIndex({ geo: '2dsphere' });
  const before = await col.countDocuments({});
  const ops = docs.map((d) => ({ updateOne: { filter: { _id: d._id }, update: { $set: d }, upsert: true } }));
  const res = await col.bulkWrite(ops, { ordered: false });
  const after = await col.countDocuments({});
   
  console.log(`Upserted: inserted ${res.upsertedCount}, modified ${res.modifiedCount}. gyms count ${before} -> ${after}.`);
} finally {
  await client.close();
}
