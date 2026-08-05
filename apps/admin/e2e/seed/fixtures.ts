/**
 * E2E seed fixtures for the bjj_admin_e2e database.
 *
 * Documents follow the repository storage convention: `_id` equals the domain
 * `id` so the stripId helper in BaseRepository returns the correct shape.
 */

// ---------------------------------------------------------------------------
// Interfaces
// ---------------------------------------------------------------------------

export interface SeedUser {
  _id: string;
  id: string;
  email: string;
  displayName: string;
  role: 'practitioner' | 'gym_owner' | 'admin';
  city?: string;
  state?: string;
  createdAt: string;
}

export interface SeedGym {
  _id: string;
  id: string;
  name: string;
  address: string;
  city?: string;
  state: string;
  amenities: string[];
  isVerified: boolean;
  createdAt: string;
}

export interface SeedOpenMat {
  _id: string;
  id: string;
  gymId: string;
  title: string;
  startTime: string;
  endTime: string;
  isRecurring: boolean;
  skillLevel: 'all' | 'beginner' | 'intermediate' | 'advanced';
  giType: 'gi' | 'nogi' | 'both';
  isCancelled: boolean;
  verified: boolean;
  status: 'live' | 'hidden';
  createdAt: string;
}

export interface SeedMembership {
  _id: string;
  id: string;
  gymId: string;
  userId: string;
  status: 'pending' | 'active' | 'hidden' | 'inactive';
  verifiedMember: boolean;
  gymRole: 'member' | 'coach' | 'owner';
  isHome: boolean;
  visibleInRoster: boolean;
  joinMethod: 'self' | 'code' | 'invite';
  joinedAt: string;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Static timestamps — everything except the one "today" user
// ---------------------------------------------------------------------------

const PAST_2025_01: string = '2025-01-15T10:00:00.000Z';
const PAST_2025_03: string = '2025-03-22T08:30:00.000Z';
const PAST_2025_06: string = '2025-06-10T14:00:00.000Z';
const PAST_2025_09: string = '2025-09-05T09:00:00.000Z';
const PAST_2026_01: string = '2026-01-20T11:00:00.000Z';

// ---------------------------------------------------------------------------
// Gyms — 4 total, two in TX so top-states aggregation is meaningful
// ---------------------------------------------------------------------------

export const gyms: SeedGym[] = [
  {
    _id: 'gym-e2e-001',
    id: 'gym-e2e-001',
    name: 'Austin BJJ Academy',
    address: '1200 Congress Ave, Austin, TX 78701',
    city: 'Austin',
    state: 'TX',
    amenities: ['showers', 'parking', 'locker_room'],
    isVerified: true,
    createdAt: PAST_2025_01,
  },
  {
    _id: 'gym-e2e-002',
    id: 'gym-e2e-002',
    name: 'Dallas Submission House',
    address: '4500 Commerce St, Dallas, TX 75226',
    city: 'Dallas',
    state: 'TX',
    amenities: ['parking', 'locker_room'],
    isVerified: true,
    createdAt: PAST_2025_03,
  },
  {
    _id: 'gym-e2e-003',
    id: 'gym-e2e-003',
    name: 'San Diego Grappling Lab',
    address: '800 Kettner Blvd, San Diego, CA 92101',
    city: 'San Diego',
    state: 'CA',
    amenities: ['showers', 'parking'],
    isVerified: false,
    createdAt: PAST_2025_06,
  },
  {
    _id: 'gym-e2e-004',
    id: 'gym-e2e-004',
    name: 'Houston Guard Pullers',
    address: '3300 Main St, Houston, TX 77002',
    city: 'Houston',
    state: 'TX',
    amenities: ['parking'],
    isVerified: false,
    createdAt: PAST_2026_01,
  },
];

// ---------------------------------------------------------------------------
// Open mats — 5 total, spread across gyms so TX (3 gyms) dominates top-states
// ---------------------------------------------------------------------------

export const openMats: SeedOpenMat[] = [
  {
    _id: 'om-e2e-001',
    id: 'om-e2e-001',
    gymId: 'gym-e2e-001',
    title: 'Saturday All-Levels Open Mat',
    startTime: '10:00',
    endTime: '12:00',
    isRecurring: true,
    skillLevel: 'all',
    giType: 'gi',
    isCancelled: false,
    verified: true,
    status: 'live',
    createdAt: PAST_2025_01,
  },
  {
    _id: 'om-e2e-002',
    id: 'om-e2e-002',
    gymId: 'gym-e2e-001',
    title: 'Wednesday No-Gi Grind',
    startTime: '18:30',
    endTime: '20:00',
    isRecurring: true,
    skillLevel: 'intermediate',
    giType: 'nogi',
    isCancelled: false,
    verified: true,
    status: 'live',
    createdAt: PAST_2025_03,
  },
  {
    _id: 'om-e2e-003',
    id: 'om-e2e-003',
    gymId: 'gym-e2e-002',
    title: 'Sunday Submission Sunday',
    startTime: '09:00',
    endTime: '11:00',
    isRecurring: true,
    skillLevel: 'advanced',
    giType: 'both',
    isCancelled: false,
    verified: false,
    status: 'live',
    createdAt: PAST_2025_06,
  },
  {
    _id: 'om-e2e-004',
    id: 'om-e2e-004',
    gymId: 'gym-e2e-003',
    title: 'San Diego Beach Session',
    startTime: '07:00',
    endTime: '09:00',
    isRecurring: false,
    skillLevel: 'beginner',
    giType: 'nogi',
    isCancelled: false,
    verified: true,
    status: 'live',
    createdAt: PAST_2025_09,
  },
  {
    _id: 'om-e2e-005',
    id: 'om-e2e-005',
    gymId: 'gym-e2e-004',
    title: 'Houston Friday Night Rolls',
    startTime: '20:00',
    endTime: '22:00',
    isRecurring: true,
    skillLevel: 'all',
    giType: 'both',
    isCancelled: false,
    verified: false,
    status: 'live',
    createdAt: PAST_2026_01,
  },
];

// ---------------------------------------------------------------------------
// Users — 4 total. buildUsers() stamps ONE user with today's timestamp at
// runtime so signup KPI windows (today / last-N-days) are always non-zero.
// ---------------------------------------------------------------------------

const STATIC_USERS: SeedUser[] = [
  {
    _id: 'user-e2e-002',
    id: 'user-e2e-002',
    email: 'alice.grappler@e2e.test',
    displayName: 'Alice Grappler',
    role: 'practitioner',
    city: 'Austin',
    state: 'TX',
    createdAt: PAST_2025_03,
  },
  {
    _id: 'user-e2e-003',
    id: 'user-e2e-003',
    email: 'bob.nolife@e2e.test',
    displayName: 'Bob NoGi',
    role: 'gym_owner',
    city: 'Dallas',
    state: 'TX',
    createdAt: PAST_2025_06,
  },
  {
    _id: 'user-e2e-004',
    id: 'user-e2e-004',
    email: 'carol.sweep@e2e.test',
    displayName: 'Carol Sweep',
    role: 'practitioner',
    city: 'San Diego',
    state: 'CA',
    createdAt: PAST_2026_01,
  },
];

/**
 * Returns the full user list. The first user (user-e2e-001) is stamped with
 * the current UTC timestamp so at least one signup falls in every KPI window.
 */
export function buildUsers(): SeedUser[] {
  const todayUser: SeedUser = {
    _id: 'user-e2e-001',
    id: 'user-e2e-001',
    email: 'admin.seed@e2e.test',
    displayName: 'Seed Admin',
    role: 'admin',
    city: 'Austin',
    state: 'TX',
    createdAt: new Date().toISOString(),
  };
  return [todayUser, ...STATIC_USERS];
}

// ---------------------------------------------------------------------------
// Memberships — one per status so the admin grid exercises every badge
// ---------------------------------------------------------------------------

export const gymMemberships: SeedMembership[] = [
  {
    _id: 'mem-e2e-001', id: 'mem-e2e-001',
    gymId: 'gym-e2e-001', userId: 'user-e2e-001',
    status: 'active', verifiedMember: true, gymRole: 'member',
    isHome: true, visibleInRoster: true, joinMethod: 'self',
    joinedAt: PAST_2025_01, createdAt: PAST_2025_01,
  },
  {
    _id: 'mem-e2e-002', id: 'mem-e2e-002',
    gymId: 'gym-e2e-001', userId: 'user-e2e-002',
    status: 'hidden', verifiedMember: false, gymRole: 'member',
    isHome: false, visibleInRoster: true, joinMethod: 'code',
    joinedAt: PAST_2025_03, createdAt: PAST_2025_03,
  },
  {
    _id: 'mem-e2e-003', id: 'mem-e2e-003',
    gymId: 'gym-e2e-001', userId: 'user-e2e-003',
    status: 'inactive', verifiedMember: false, gymRole: 'member',
    isHome: false, visibleInRoster: true, joinMethod: 'invite',
    joinedAt: PAST_2025_06, createdAt: PAST_2025_06,
  },
  {
    _id: 'mem-e2e-004', id: 'mem-e2e-004',
    gymId: 'gym-e2e-001', userId: 'user-e2e-004',
    status: 'active', verifiedMember: true, gymRole: 'coach',
    isHome: false, visibleInRoster: false, joinMethod: 'self',
    joinedAt: PAST_2025_09, createdAt: PAST_2025_09,
  },
];
