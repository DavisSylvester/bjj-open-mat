/**
 * E2E seed script — populates the bjj_admin_e2e database with known fixtures.
 *
 * Usage (from repo root):
 *   bun apps/admin/e2e/seed/seed.ts
 *
 * The MONGODB_URI env var is respected; defaults to localhost:27017.
 */

// Side-effect shim MUST load before mongodb (see bson-bun-shim.ts).
import './bson-bun-shim.ts';
import { buildUsers, gyms, openMats } from './fixtures.ts';
import type { SeedUser, SeedGym, SeedOpenMat } from './fixtures.ts';

const uri: string = process.env['MONGODB_URI'] ?? 'mongodb://localhost:27017';
const DB_NAME = 'bjj_admin_e2e';

async function run(): Promise<void> {
  const { MongoClient } = await import('mongodb');
  const client = new MongoClient(uri);

  try {
    await client.connect();
    console.log(`Connected to MongoDB at ${uri}`);

    const db = client.db(DB_NAME);

    // Drop existing collections for a clean slate
    await db.collection('users').drop().catch(() => undefined);
    await db.collection('gyms').drop().catch(() => undefined);
    await db.collection('openMats').drop().catch(() => undefined);
    console.log('Dropped existing collections (if any).');

    // Insert fixtures
    const users: SeedUser[] = buildUsers();

    const usersResult = await db.collection<SeedUser>('users').insertMany(users);
    console.log(`Inserted ${usersResult.insertedCount} users`);

    const gymsResult = await db.collection<SeedGym>('gyms').insertMany(gyms);
    console.log(`Inserted ${gymsResult.insertedCount} gyms`);

    const openMatsResult = await db.collection<SeedOpenMat>('openMats').insertMany(openMats);
    console.log(`Inserted ${openMatsResult.insertedCount} open mats`);

    console.log('Seed complete.');
  } finally {
    await client.close();
  }
}

run().catch((err: unknown) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
