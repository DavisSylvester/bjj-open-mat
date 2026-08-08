/**
 * Screenshot API launcher for the Members-by-gym page.
 *
 * Seeds its OWN database (`bjj_admin_members_shots`) rather than reusing
 * `bjj_admin_e2e`, because the tracked fixtures in seed/fixtures.ts are
 * asserted against by the existing e2e specs — extending them to showcase the
 * new tree would break those tests.
 *
 * The data here deliberately covers every case the Members page can render:
 * two states, a gym with no state, a gym with no members (must NOT appear),
 * users with no membership at all, all four statuses, a self-hidden member,
 * a gym owner (switcher locks Hidden/Inactive), and a membership pointing at
 * a gym that no longer exists.
 *
 * SAFETY: MONGODB_URI is pinned to localhost here. apps/api/.env defines
 * MONGODB_URI twice, the second pointing at production Atlas; in Bun a real
 * environment variable beats a .env entry, so setting it in-process before
 * spawning keeps this run off production.
 *
 * Usage (from apps/admin):
 *   bun e2e/serve-api-members.ts
 */

import { resolve } from 'path';
// Side-effect shim MUST load before mongodb (see seed/bson-bun-shim.ts).
import './seed/bson-bun-shim.ts';

const DB_NAME: string = 'bjj_admin_members_shots';
const ADMIN_USER_ID: string = 'shots-admin';

// Pinned, not defaulted: this must win over apps/api/.env's Atlas URI.
process.env['MONGODB_URI'] = 'mongodb://localhost:27017';
process.env['MONGODB_DB'] = DB_NAME;
process.env['AUTH_BYPASS_SECRET'] = 'shots-secret';
// The admin guard reads the role from the USER RECORD, not the token, so this
// must name a seeded user whose `role` is "admin" or every request 403s.
process.env['DEMO_USER_ID'] = ADMIN_USER_ID;
process.env['DEMO_USER_ROLE'] = 'practitioner';
process.env['DEMO_USER_EMAIL'] = 'admin@shots.dev';
process.env['WEBSITE_ORIGIN'] = 'http://localhost:4300';
process.env['PORT'] = '3100';

const T = (iso: string): string => iso;

interface Doc { [key: string]: unknown }

const users: Doc[] = [
  { _id: ADMIN_USER_ID, id: ADMIN_USER_ID, email: 'admin@shots.dev', displayName: 'Dana Reyes', role: 'admin', createdAt: T('2025-02-01T10:00:00.000Z') },
  { _id: 'u-owner', id: 'u-owner', email: 'marcus.silva@shots.dev', displayName: 'Marcus Silva', role: 'gym_owner', createdAt: T('2025-01-10T10:00:00.000Z') },
  { _id: 'u-alice', id: 'u-alice', email: 'alice.grappler@shots.dev', displayName: 'Alice Grappler', role: 'practitioner', createdAt: T('2025-03-04T10:00:00.000Z') },
  { _id: 'u-bob', id: 'u-bob', email: 'bob.nogi@shots.dev', displayName: 'Bob Nogueira', role: 'practitioner', createdAt: T('2025-04-18T10:00:00.000Z') },
  { _id: 'u-carol', id: 'u-carol', email: 'carol.sweep@shots.dev', displayName: 'Carol Sweep', role: 'practitioner', createdAt: T('2025-05-22T10:00:00.000Z') },
  { _id: 'u-dev', id: 'u-dev', email: 'devon.pass@shots.dev', displayName: 'Devon Pass', role: 'practitioner', createdAt: T('2025-06-30T10:00:00.000Z') },
  { _id: 'u-erin', id: 'u-erin', email: 'erin.choke@shots.dev', displayName: 'Erin Choque', role: 'practitioner', createdAt: T('2025-07-14T10:00:00.000Z') },
  { _id: 'u-frank', id: 'u-frank', email: 'frank.berimbolo@shots.dev', displayName: 'Frank Berimbolo', role: 'practitioner', createdAt: T('2025-08-02T10:00:00.000Z') },
  { _id: 'u-grace', id: 'u-grace', email: 'grace.armbar@shots.dev', displayName: 'Grace Armbar', role: 'practitioner', createdAt: T('2025-09-09T10:00:00.000Z') },
  // No membership anywhere -> the "No Gym" group.
  { _id: 'u-nogym-1', id: 'u-nogym-1', email: 'hana.newcomer@shots.dev', displayName: 'Hana Newcomer', role: 'practitioner', createdAt: T('2026-07-30T10:00:00.000Z') },
  { _id: 'u-nogym-2', id: 'u-nogym-2', email: 'ivan.browsing@shots.dev', displayName: 'Ivan Browsing', role: 'practitioner', createdAt: T('2026-08-02T10:00:00.000Z') },
  { _id: 'u-nogym-3', id: 'u-nogym-3', email: 'june.lurker@shots.dev', displayName: 'June Lurker', role: 'practitioner', createdAt: T('2026-08-05T10:00:00.000Z') },
];

const gyms: Doc[] = [
  { _id: 'g-renzo', id: 'g-renzo', name: 'Renzo Gracie Dallas', address: '4500 Commerce St', city: 'Dallas', state: 'TX', ownerId: 'u-owner', amenities: ['showers', 'parking'], isVerified: true, createdAt: T('2025-01-10T10:00:00.000Z') },
  { _id: 'g-alliance', id: 'g-alliance', name: 'Alliance Frisco', address: '8500 Gaylord Pkwy', city: 'Frisco', state: 'TX', amenities: ['parking'], isVerified: true, createdAt: T('2025-02-11T10:00:00.000Z') },
  { _id: 'g-austin', id: 'g-austin', name: 'Austin BJJ Academy', address: '1200 Congress Ave', city: 'Austin', state: 'TX', amenities: ['showers'], isVerified: false, createdAt: T('2025-03-12T10:00:00.000Z') },
  { _id: 'g-sd', id: 'g-sd', name: 'San Diego Grappling Lab', address: '800 Kettner Blvd', city: 'San Diego', state: 'CA', amenities: ['showers', 'parking'], isVerified: true, createdAt: T('2025-04-13T10:00:00.000Z') },
  // No `state` -> the "(No State)" group.
  { _id: 'g-nostate', id: 'g-nostate', name: 'Nowhere Jiu Jitsu', address: '17 Unknown Rd', amenities: [], isVerified: false, createdAt: T('2025-05-14T10:00:00.000Z') },
  // No memberships -> must be ABSENT from the tree entirely.
  { _id: 'g-empty', id: 'g-empty', name: 'Empty Mat Club', address: '99 Vacant Way', city: 'Plano', state: 'TX', amenities: [], isVerified: false, createdAt: T('2025-06-15T10:00:00.000Z') },
];

interface M { id: string; gymId: string; userId: string; status: string; role: string; verified: boolean; visible: boolean; joined: string }

const memberships: M[] = [
  // Renzo Dallas — every status, the owner, and a self-hidden member.
  { id: 'm-01', gymId: 'g-renzo', userId: 'u-owner', status: 'active', role: 'owner', verified: true, visible: true, joined: '2025-01-10T10:00:00.000Z' },
  { id: 'm-02', gymId: 'g-renzo', userId: 'u-alice', status: 'active', role: 'coach', verified: true, visible: true, joined: '2025-03-04T10:00:00.000Z' },
  { id: 'm-03', gymId: 'g-renzo', userId: 'u-bob', status: 'hidden', role: 'member', verified: false, visible: true, joined: '2025-04-18T10:00:00.000Z' },
  { id: 'm-04', gymId: 'g-renzo', userId: 'u-carol', status: 'inactive', role: 'member', verified: false, visible: true, joined: '2025-05-22T10:00:00.000Z' },
  { id: 'm-05', gymId: 'g-renzo', userId: 'u-dev', status: 'pending', role: 'member', verified: false, visible: true, joined: '2026-08-05T10:00:00.000Z' },
  // Self-hidden: active, but the MEMBER hid themselves. Distinct from `hidden`.
  { id: 'm-06', gymId: 'g-renzo', userId: 'u-erin', status: 'active', role: 'member', verified: true, visible: false, joined: '2025-07-14T10:00:00.000Z' },
  { id: 'm-07', gymId: 'g-renzo', userId: 'u-frank', status: 'active', role: 'member', verified: false, visible: true, joined: '2025-08-02T10:00:00.000Z' },
  { id: 'm-08', gymId: 'g-renzo', userId: 'u-grace', status: 'active', role: 'member', verified: true, visible: true, joined: '2025-09-09T10:00:00.000Z' },
  // Alliance Frisco — two pending, so the group header shows a pending count.
  { id: 'm-09', gymId: 'g-alliance', userId: 'u-alice', status: 'pending', role: 'member', verified: false, visible: true, joined: '2026-08-04T10:00:00.000Z' },
  { id: 'm-10', gymId: 'g-alliance', userId: 'u-bob', status: 'pending', role: 'member', verified: false, visible: true, joined: '2026-08-06T10:00:00.000Z' },
  { id: 'm-11', gymId: 'g-alliance', userId: 'u-grace', status: 'active', role: 'member', verified: true, visible: true, joined: '2025-10-01T10:00:00.000Z' },
  // Austin — a legacy row with NO status field at all (renders as active).
  { id: 'm-12', gymId: 'g-austin', userId: 'u-frank', status: '', role: 'member', verified: false, visible: true, joined: '2025-02-20T10:00:00.000Z' },
  { id: 'm-13', gymId: 'g-austin', userId: 'u-carol', status: 'active', role: 'coach', verified: true, visible: true, joined: '2025-03-21T10:00:00.000Z' },
  // California.
  { id: 'm-14', gymId: 'g-sd', userId: 'u-dev', status: 'active', role: 'member', verified: true, visible: true, joined: '2025-06-30T10:00:00.000Z' },
  { id: 'm-15', gymId: 'g-sd', userId: 'u-erin', status: 'inactive', role: 'member', verified: false, visible: true, joined: '2025-07-15T10:00:00.000Z' },
  // Stateless gym.
  { id: 'm-16', gymId: 'g-nostate', userId: 'u-alice', status: 'active', role: 'member', verified: false, visible: true, joined: '2025-05-14T10:00:00.000Z' },
  // Points at a gym that does not exist -> "Unknown gym (…)" under (No State).
  { id: 'm-17', gymId: 'g-deleted', userId: 'u-bob', status: 'active', role: 'member', verified: false, visible: true, joined: '2025-11-11T10:00:00.000Z' },
];

function toDoc(m: M): Doc {
  const doc: Doc = {
    _id: m.id, id: m.id, gymId: m.gymId, userId: m.userId,
    verifiedMember: m.verified, gymRole: m.role, isHome: false,
    visibleInRoster: m.visible, joinMethod: 'self',
    joinedAt: m.joined, createdAt: m.joined,
  };
  // An empty status means "legacy document written before the field existed",
  // so the key is omitted entirely rather than set to a falsy value.
  if (m.status.length > 0) doc['status'] = m.status;
  return doc;
}

async function seed(): Promise<void> {
  const { MongoClient } = await import('mongodb');
  const uri: string = process.env['MONGODB_URI'] as string;
  if (!uri.includes('localhost') && !uri.includes('127.0.0.1')) {
    throw new Error(`Refusing to seed a non-local database: ${uri}`);
  }
  const client = new MongoClient(uri);
  try {
    await client.connect();
    const db = client.db(DB_NAME);
    for (const name of ['users', 'gyms', 'gymMemberships', 'openMats']) {
      await db.collection(name).drop().catch(() => undefined);
    }
    await db.collection('users').insertMany(users as never);
    await db.collection('gyms').insertMany(gyms as never);
    await db.collection('gymMemberships').insertMany(memberships.map(toDoc) as never);
    console.log(`[shots] seeded ${DB_NAME}: ${users.length} users, ${gyms.length} gyms, ${memberships.length} memberships`);
  } finally {
    await client.close();
  }
}

await seed();

const apiDir: string = resolve(import.meta.dir, '../../api');
process.chdir(apiDir);

const api = Bun.spawn([process.execPath, 'src/index.mts'], {
  stdout: 'inherit',
  stderr: 'inherit',
  stdin: 'ignore',
  env: process.env as Record<string, string>,
});

const exitCode: number = await api.exited;
console.log(`[shots] API exited with code ${String(exitCode)}`);
process.exit(exitCode);
