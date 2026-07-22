import type { UserRepository } from "../repositories/user.repository.mts";
import type { CheckInRepository } from "../repositories/check-in.repository.mts";
import type { FavoriteRepository } from "../repositories/favorite.repository.mts";
import type { RsvpRepository } from "../repositories/rsvp.repository.mts";
import type { NotificationRepository } from "../repositories/notification.repository.mts";
import type { Auth0ManagementService } from "./auth0-management.service.mts";

export interface AccountDeletionService {
  deleteAccount(userId: string): Promise<void>;
}

// Orchestrates account deletion (Guideline 5.1.1(v)): removes all data owned
// by the user, then their Auth0 identity, then the user record itself. The
// user record is removed last so a failed Auth0 delete leaves the account
// intact (and retryable) rather than orphaned.
export class AccountDeletionOrchestrator implements AccountDeletionService {

  public constructor(
    private readonly users: Pick<UserRepository, "remove">,
    private readonly checkins: Pick<CheckInRepository, "deleteByUserId">,
    private readonly favorites: Pick<FavoriteRepository, "deleteByUserId">,
    private readonly rsvps: Pick<RsvpRepository, "deleteByUserId">,
    private readonly notifications: Pick<NotificationRepository, "deleteByUserId">,
    private readonly auth0: Auth0ManagementService,
  ) {}

  public async deleteAccount(userId: string): Promise<void> {
    await Promise.all([
      this.checkins.deleteByUserId(userId),
      this.favorites.deleteByUserId(userId),
      this.rsvps.deleteByUserId(userId),
      this.notifications.deleteByUserId(userId),
    ]);
    await this.auth0.deleteUser(userId);
    await this.users.remove(userId);
  }
}
