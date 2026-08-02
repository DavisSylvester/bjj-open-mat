export interface GymMembership {
  id: string;
  gymId: string;
  userId: string;
  status?: string;
  verifiedMember: boolean;
  gymRole?: string;
  isHome: boolean;
  visibleInRoster: boolean;
  joinMethod?: string;
  joinedAt: string;
  createdAt?: string;
}
