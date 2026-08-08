export type MembershipStatus = 'pending' | 'active' | 'hidden' | 'inactive';

/**
 * The statuses an admin may assign. Mirrors `ManageableMembershipStatus` in the
 * contract: `pending` is owned by the join flow and the API rejects it with a
 * 400, so it is not a value any caller may send.
 */
export type SettableMembershipStatus = Exclude<MembershipStatus, 'pending'>;

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
