// apps/api/src/facades/membership.facade.mts
import type {
  BeltPromotion,
  Gym,
  GymMembership,
  PromoteBeltRequest,
  RosterMember,
  UpdateMembershipRequest,
  UpdateMyMembershipRequest,
  User,
  UserRole,
} from '@bjj/contract';
import { AppError } from '../http/errors.mts';
import { assertCanManageGym } from './gym-authz.mts';
import type { MembershipRepository } from '../repositories/membership.repository.mts';
import type { PromotionRepository } from '../repositories/promotion.repository.mts';
import type { GymRepository } from '../repositories/gym.repository.mts';
import type { UserRepository } from '../repositories/user.repository.mts';

type IdFactory = () => string;

type MembershipRepo = Pick<
  MembershipRepository,
  'upsertJoin' | 'find' | 'remove' | 'listByGym' | 'listByUser' | 'update' | 'setHome' | 'listAll'
>;
type PromotionRepo = Pick<PromotionRepository, 'insert' | 'listByUser'>;
type GymRepo = Pick<GymRepository, 'findById'>;
type UserRepo = Pick<UserRepository, 'findById' | 'update'>;

export class MembershipFacade {

  public constructor(
    private readonly memberships: MembershipRepo,
    private readonly promotions: PromotionRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  public async join(userId: string, gymId: string): Promise<GymMembership> {
    const gym: Gym | null = await this.gyms.findById(gymId);
    if (!gym) throw new AppError('not_found', `Gym ${gymId} not found`);
    const now: string = new Date().toISOString();
    const membership: GymMembership = {
      id: this.newId(),
      gymId,
      userId,
      status: 'active',
      verifiedMember: false,
      gymRole: 'member',
      isHome: false,
      visibleInRoster: true,
      joinMethod: 'self',
      joinedAt: now,
      createdAt: now,
    };
    return this.memberships.upsertJoin(membership);
  }

  /// Guarantees the user is a member of [gymId] and that it is their home gym.
  ///
  /// Composed from the existing paths rather than reimplementing them: [join]
  /// already rejects an unknown gym and already upserts, so this is safe to
  /// call repeatedly. Deliberately does NOT call `setMine`, which would write
  /// `users.homeGymId` a second time — the caller owns that field.
  public async ensureHome(userId: string, gymId: string): Promise<void> {
    const existing: GymMembership | null = await this.memberships.find(gymId, userId);
    if (!existing) {
      await this.join(userId, gymId);
    }
    await this.memberships.setHome(userId, gymId);
  }

  public async leave(userId: string, gymId: string): Promise<void> {
    await this.memberships.remove(gymId, userId);
  }

  public async roster(gymId: string): Promise<RosterMember[]> {
    const rows: GymMembership[] = await this.memberships.listByGym(gymId, false);
    const built: RosterMember[] = await Promise.all(
      rows.map(async (m): Promise<RosterMember> => {
        const u: User | null = await this.users.findById(m.userId);
        return {
          userId: m.userId,
          name: u?.displayName ?? 'Member',
          beltRank: u?.beltRank,
          beltStripes: u?.beltStripes,
          verifiedBeltRank: u?.verifiedBeltRank,
          verifiedBeltStripes: u?.verifiedBeltStripes,
          avatarUrl: u?.avatarUrl,
          gymRole: m.gymRole ?? 'member',
          verifiedMember: m.verifiedMember,
          hasProfile: u !== null,
        };
      }),
    );
    return built;
  }

  public async updateMyMembership(
    userId: string,
    gymId: string,
    req: UpdateMyMembershipRequest,
  ): Promise<GymMembership> {
    const existing: GymMembership | null = await this.memberships.find(gymId, userId);
    if (!existing) throw new AppError('not_found', 'Not a member of this gym');
    const patch: Partial<GymMembership> = {};
    if (req.visibleInRoster !== undefined) patch.visibleInRoster = req.visibleInRoster;
    if (req.isHome === true) {
      await this.memberships.setHome(userId, gymId);
      await this.users.update(userId, { homeGymId: gymId });
    }
    const updated: GymMembership = (await this.memberships.update(gymId, userId, patch)) ?? existing;
    return req.isHome === true ? { ...updated, isHome: true } : updated;
  }

  public async updateMembership(
    callerId: string,
    gymId: string,
    targetUserId: string,
    req: UpdateMembershipRequest,
    callerRole: UserRole,
  ): Promise<GymMembership> {
    await this.assertCanManage(callerId, gymId, callerRole);
    const target: GymMembership | null = await this.memberships.find(gymId, targetUserId);
    if (!target) throw new AppError('not_found', 'Target is not a member of this gym');
    const patch: Partial<GymMembership> = {};
    if (req.verifiedMember !== undefined) patch.verifiedMember = req.verifiedMember;
    if (req.gymRole !== undefined) patch.gymRole = req.gymRole;
    return (await this.memberships.update(gymId, targetUserId, patch)) ?? target;
  }

  public async promote(
    callerId: string,
    gymId: string,
    targetUserId: string,
    req: PromoteBeltRequest,
    callerRole: UserRole,
  ): Promise<BeltPromotion> {
    if (callerId === targetUserId) throw new AppError('forbidden', 'Cannot promote yourself');
    await this.assertCanManage(callerId, gymId, callerRole);
    const target: GymMembership | null = await this.memberships.find(gymId, targetUserId);
    if (!target) throw new AppError('not_found', 'Target is not a member of this gym');
    const now: string = new Date().toISOString();
    const promotion: BeltPromotion = {
      id: this.newId(),
      userId: targetUserId,
      gymId,
      beltRank: req.beltRank,
      beltStripes: req.beltStripes,
      promotedByUserId: callerId,
      promotedAt: now,
      note: req.note,
    };
    const saved: BeltPromotion = await this.promotions.insert(promotion);
    await this.users.update(targetUserId, {
      verifiedBeltRank: req.beltRank,
      verifiedBeltStripes: req.beltStripes,
      verifiedByGymId: gymId,
      verifiedAt: now,
    });
    return saved;
  }

  public async listPromotions(userId: string): Promise<BeltPromotion[]> {
    return this.promotions.listByUser(userId);
  }

  public async listMyMemberships(userId: string): Promise<GymMembership[]> {
    return this.memberships.listByUser(userId);
  }

  public async listAll(skip: number, limit: number): Promise<{ items: GymMembership[]; total: number }> {
    return this.memberships.listAll(skip, limit);
  }

  private async assertCanManage(callerId: string, gymId: string, callerRole: UserRole): Promise<void> {
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, gymId, callerRole);
  }
}
