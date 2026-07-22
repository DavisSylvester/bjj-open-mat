/**
 * Seed the `openMats` collection from openmats-merged.json (docs anchored to
 * real gym _ids from the gyms seed). Upserts by _id; ensures 2dsphere on geo.
 *
 * Connection reads MONGODB_URI / MONGODB_DB from apps/api/.env (override via env).
 * SAFE BY DEFAULT — dry run unless --commit is passed.
 *   bun run scripts/gym-research/seed-openmats.mts            # validate only
 *   bun run scripts/gym-research/seed-openmats.mts --commit   # connect + upsert
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const COMMIT = process.argv.includes('--commit');

interface OpenMatDoc { _id: string; gymId: string; geo: { type: 'Point'; coordinates: [number, number] } | null; [k: string]: unknown }
const fileArg = process.argv.slice(2).find((a) => !a.startsWith('--') && a.endsWith('.json')) ?? 'openmats-merged.json';
const docs = JSON.parse(readFileSync(join(DATA, fileArg), 'utf8')) as OpenMatDoc[];
console.log(`Source: ${fileArg}`);

const problems: string[] = [];
const ids = new Set<string>();
for (const d of docs) {
  if (!d._id) problems.push(`missing _id: ${String(d['gymName'])}`);
  if (ids.has(d._id)) problems.push(`duplicate _id: ${d._id}`);
  ids.add(d._id);
  if (!d.gymId) problems.push(`missing gymId: ${d._id}`);
  if (!d.geo || !Array.isArray(d.geo.coordinates) || d.geo.coordinates.length !== 2) problems.push(`missing geo: ${d._id}`);
  else if (d.geo.coordinates[0] > 0 || d.geo.coordinates[1] < 0) problems.push(`geo looks like [lat,lng]: ${d._id}`);
}
if (problems.length) { console.error(`Validation FAILED:\n${problems.slice(0, 20).join('\n')}`); process.exit(1); }
console.log(`Seed valid: ${docs.length} openMat docs, ${ids.size} unique _id, ${docs.filter((d) => d.geo).length} with geo.`);

if (!COMMIT) { console.log('\nDRY RUN — no DB connection. Re-run with --commit to upsert.'); process.exit(0); }

const readEnv = (name: string): string => {
  if (process.env[name]) return process.env[name] as string;
  const env = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
  return (env.match(new RegExp(`^${name}=(.*)$`, 'm'))?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
};
const uri = readEnv('MONGODB_URI');
const dbName = readEnv('MONGODB_DB');
if (!uri || !dbName) { console.error('MONGODB_URI / MONGODB_DB not set'); process.exit(1); }
console.log(`Target: ${uri.replace(/:\/\/[^@]*@/, '://***@')} db=${dbName} collection=openMats`);

const { pathToFileURL } = await import('node:url');
const mongoEntry = join(import.meta.dir, '..', '..', 'apps', 'api', 'node_modules', 'mongodb', 'lib', 'index.js');
// mongodb lives under apps/api/node_modules (not hoisted) — a top-level type import can't resolve from scripts/
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
const { MongoClient } = (await import(pathToFileURL(mongoEntry).href)) as typeof import('mongodb');
const client = new MongoClient(uri, { timeoutMS: 20_000 });
try {
  await client.connect();
  const col = client.db(dbName).collection<OpenMatDoc>('openMats');
  await col.createIndex({ geo: '2dsphere' });
  await col.createIndex({ gymId: 1 });
  const before = await col.countDocuments({});
  const res = await col.bulkWrite(docs.map((d) => ({ updateOne: { filter: { _id: d._id }, update: { $set: d }, upsert: true } })), { ordered: false });
  const after = await col.countDocuments({});
  console.log(`Upserted: inserted ${res.upsertedCount}, modified ${res.modifiedCount}. openMats ${before} -> ${after}.`);
} finally {
  await client.close();
}
