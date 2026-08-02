/**
 * E2E API launcher — seeds the bjj_admin_e2e database then starts the API.
 *
 * This script is the webServer command for the API in playwright.config.ts.
 * Because `VAR=val cmd` env-prefix syntax does not work on Windows, all
 * required env vars are set in-process before spawning the API child process.
 *
 * Windows note: Bun.spawn with the `cwd` option crashes (uv_spawn ENOENT) on
 * this host. The workaround is to call process.chdir() before spawning so the
 * child inherits the correct working directory without needing the option.
 *
 * Usage (from apps/admin):
 *   bun e2e/serve-api.ts
 */

import { resolve } from 'path';
import { MongoClient } from 'mongodb';
import { buildUsers, gyms, openMats } from './seed/fixtures.ts';
import type { SeedUser, SeedGym, SeedOpenMat } from './seed/fixtures.ts';

// ---------------------------------------------------------------------------
// 1. Set required env defaults in-process before spawning the API
// ---------------------------------------------------------------------------

process.env['MONGODB_URI'] ??= 'mongodb://localhost:27017';
process.env['MONGODB_DB'] = 'bjj_admin_e2e';
process.env['AUTH_BYPASS_SECRET'] ??= 'e2e-secret';
process.env['DEMO_USER_ID'] ??= 'e2e-demo';
process.env['DEMO_USER_ROLE'] ??= 'practitioner';
process.env['DEMO_USER_EMAIL'] ??= 'e2e@demo.dev';
// CORS: admin app serves on 4300; must be in the allowed-origins list
process.env['WEBSITE_ORIGIN'] = 'http://localhost:4300';
process.env['PORT'] ??= '3100';

// ---------------------------------------------------------------------------
// 2. Seed the database so it is populated before the API accepts traffic
// ---------------------------------------------------------------------------

async function seed(): Promise<void> {
  const uri: string = process.env['MONGODB_URI'] as string;
  const client = new MongoClient(uri);

  try {
    await client.connect();
    console.log(`[serve-api] Connected to MongoDB at ${uri}`);

    const db = client.db('bjj_admin_e2e');

    // Drop collections for a clean slate on each test run
    await db.collection('users').drop().catch(() => undefined);
    await db.collection('gyms').drop().catch(() => undefined);
    await db.collection('openMats').drop().catch(() => undefined);
    console.log('[serve-api] Dropped existing collections.');

    const users: SeedUser[] = buildUsers();
    const usersResult = await db.collection<SeedUser>('users').insertMany(users);
    console.log(`[serve-api] Inserted ${usersResult.insertedCount} users`);

    const gymsResult = await db.collection<SeedGym>('gyms').insertMany(gyms);
    console.log(`[serve-api] Inserted ${gymsResult.insertedCount} gyms`);

    const openMatsResult = await db.collection<SeedOpenMat>('openMats').insertMany(openMats);
    console.log(`[serve-api] Inserted ${openMatsResult.insertedCount} open mats`);

    console.log('[serve-api] Seed complete.');
  } finally {
    await client.close();
  }
}

await seed();

// ---------------------------------------------------------------------------
// 3. Change to apps/api and spawn the API.
//    NOTE: Do NOT pass the cwd option to Bun.spawn — it triggers a uv_spawn
//    ENOENT bug on Windows. Call process.chdir() before spawning instead.
// ---------------------------------------------------------------------------

// import.meta.dir = apps/admin/e2e  →  ../../api = apps/api
const apiDir: string = resolve(import.meta.dir, '../../api');
console.log(`[serve-api] Starting API from ${apiDir} on port ${process.env['PORT']}...`);

process.chdir(apiDir);

const api = Bun.spawn([process.execPath, 'src/index.mts'], {
  stdout: 'inherit',
  stderr: 'inherit',
  stdin: 'ignore',
  env: process.env as Record<string, string>,
});

// Keep this process alive until the API exits so Playwright's webServer
// health-check can succeed and the server stays up for the test run.
const exitCode: number = await api.exited;
console.log(`[serve-api] API exited with code ${String(exitCode)}`);
process.exit(exitCode);
