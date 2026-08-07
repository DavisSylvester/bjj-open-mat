import type { MembershipStatus } from './gym-membership';

export interface GymSummary {
  id: string;
  name: string;
  city?: string;
  ownerId?: string;
  memberCount: number;
  pendingCount: number;
}

export interface StateGroup {
  state: string;
  gyms: GymSummary[];
}

export interface AdminMembersTree {
  states: StateGroup[];
  noState: GymSummary[];
  noGym: { userCount: number };
}

export interface AdminRosterRow {
  membershipId: string;
  gymId: string;
  userId: string;
  displayName: string;
  email: string;
  gymRole?: string;
  status: MembershipStatus;
  visibleInRoster: boolean;
  verifiedMember: boolean;
  joinedAt: string;
  unresolved?: boolean;
}

export interface NoGymUserRow {
  userId: string;
  displayName: string;
  email: string;
  createdAt: string;
}
