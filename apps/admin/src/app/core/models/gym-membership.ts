export type MembershipStatus = 'pending' | 'active' | 'hidden' | 'inactive';

export interface GymMembership {
  id: string;
  gymId: string;
  userId: string;
  status?: MembershipStatus;
  verifiedMember: boolean;
  gymRole?: string;
  isHome: boolean;
  visibleInRoster: boolean;
  joinMethod?: string;
  joinedAt: string;
  createdAt?: string;
  statusUpdatedAt?: string;
  statusUpdatedBy?: string;
}
