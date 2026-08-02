/**
 * E2E reset script — drops the entire bjj_admin_e2e database.
 *
 * Usage (from repo root):
 *   bun apps/admin/e2e/seed/reset.ts
 *
 * The MONGODB_URI env var is respected; defaults to localhost:27017.
 */

import { MongoClient } from 'mongodb';

const uri: string = process.env['MONGODB_URI'] ?? 'mongodb://localhost:27017';
const DB_NAME = 'bjj_admin_e2e';

async function run(): Promise<void> {
  const client = new MongoClient(uri);

  try {
    await client.connect();
    console.log(`Connected to MongoDB at ${uri}`);

    await client.db(DB_NAME).dropDatabase();
    console.log(`Dropped database '${DB_NAME}'.`);
  } finally {
    await client.close();
  }
}

run().catch((err: unknown) => {
  console.error('Reset failed:', err);
  process.exit(1);
});
