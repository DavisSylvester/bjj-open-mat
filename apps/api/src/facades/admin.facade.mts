// apps/api/src/facades/admin.facade.mts
import type {
  AdminOpenMatsByState,
  AdminOverviewStats,
  Gym,
  GymMembership,
  UpdateMembershipRequest,
  User,
} from "@bjj/contract";
import type { AdminAnalyticsRepository } from "../repositories/admin-analytics.repository.mjs";
import type { UserRepository } from "../repositories/user.repository.mjs";
import type { GymFacade } from "./gym.facade.mjs";
import type { OpenMatFacade } from "./open-mat.facade.mjs";
import type { MembershipFacade } from "./membership.facade.mjs";
import type { EmailService } from "../services/email.service.mjs";

export class AdminFacade {

  public constructor(
    private readonly analytics: AdminAnalyticsRepository,
    private readonly users: UserRepository,
    private readonly gyms: GymFacade,
    private readonly openMats: OpenMatFacade,
    private readonly memberships: MembershipFacade,
    private readonly email: EmailService,
  ) {}

  public async overview(now: Date): Promise<AdminOverviewStats> {
    const [signups, totals] = await Promise.all([
      this.analytics.signupWindows(now),
      this.analytics.totals(),
    ]);
    return { signups, ...totals };
  }

  public async openMatsByState(limit: number): Promise<AdminOpenMatsByState> {
    const [topStates, totals] = await Promise.all([
      this.analytics.topStates(limit),
      this.analytics.totals(),
    ]);
    return { totalOpenMats: totals.totalOpenMats, topStates };
  }

  public async listUsers(skip: number, limit: number): Promise<{ items: User[]; total: number }> {
    return this.users.list(skip, limit);
  }

  public async listMemberships(skip: number, limit: number): Promise<{ items: GymMembership[]; total: number }> {
    return this.memberships.listAll(skip, limit);
  }

  /// Admin-scoped membership update. Passes 'admin' as the caller id and role,
  /// matching the convention adminRoutes already uses for open mats — the admin
  /// router carries no per-user identity.
  public async updateMembership(
    gymId: string,
    userId: string,
    req: UpdateMembershipRequest,
  ): Promise<GymMembership> {
    return this.memberships.updateMembership("admin", gymId, userId, req, "admin");
  }

  public async verifyGym(gymId: string, now: Date): Promise<Gym> {
    return this.gyms.adminUpdate(gymId, { isVerified: true, verifiedAt: now.toISOString() });
  }

  public async addOwner(gymId: string, userId: string): Promise<Gym> {
    const gym = await this.gyms.adminUpdate(gymId, { ownerId: userId });
    await this.users.update(userId, { role: "gym_owner" });
    return gym;
  }

  public async invite(gymId: string, emails: string[]): Promise<{ invited: number }> {
    const gym = await this.gyms.getById(gymId);
    for (const to of emails) {
      await this.email.sendGymMemberInvite(to, gym.name, gym.joinCode);
    }
    return { invited: emails.length };
  }
}
