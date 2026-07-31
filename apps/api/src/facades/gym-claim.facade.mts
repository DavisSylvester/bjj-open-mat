import type {
  Gym,
  GymClaim,
  GymClaimStatus,
  Notification,
  SubmitGymClaimRequest,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { GymClaimRepository } from "../repositories/gym-claim.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { NotificationRepository } from "../repositories/notification.repository.mts";

type IdFactory = () => string;

type ClaimRepo = Pick<
  GymClaimRepository,
  | "insert"
  | "findById"
  | "findPendingByGymAndClaimant"
  | "findLatestByGymAndClaimant"
  | "listByStatus"
  | "listByClaimant"
  | "listPendingByGym"
  | "updateStatus"
>;
type GymRepo = Pick<GymRepository, "findById" | "update">;
type UserRepo = Pick<UserRepository, "findById" | "update">;
type MemberRepo = Pick<MembershipRepository, "find" | "update" | "upsertJoin">;
type NotifRepo = Pick<NotificationRepository, "insert">;

export class GymClaimFacade {

  public constructor(
    private readonly claims: ClaimRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly memberships: MemberRepo,
    private readonly notifications: NotifRepo,
    private readonly newId: IdFactory,
  ) {}

  private async notify(
    userId: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const n: Notification = {
      id: this.newId(),
      userId,
      type: "gym_claim",
      title,
      body,
      read: false,
      data,
      createdAt: new Date().toISOString(),
    };
    await this.notifications.insert(n);
  }

  private async getClaimOr404(id: string): Promise<GymClaim> {
    const c = await this.claims.findById(id);
    if (!c) throw new AppError("not_found", `Claim ${id} not found`);
    return c;
  }

  public async submit(callerId: string, gymId: string, req: SubmitGymClaimRequest): Promise<GymClaim> {
    const gym: Gym | null = await this.gyms.findById(gymId);
    if (!gym) throw new AppError("not_found", `Gym ${gymId} not found`);
    if (gym.ownerId === callerId) throw new AppError("conflict", "You already own this gym");
    const dupe = await this.claims.findPendingByGymAndClaimant(gymId, callerId);
    if (dupe) throw new AppError("conflict", "You already have a pending claim for this gym");

    const kind = gym.ownerId ? "transfer" : "claim";
    const claim: GymClaim = {
      id: this.newId(),
      gymId,
      claimantId: callerId,
      kind,
      relationship: req.relationship,
      contact: req.contact,
      message: req.message,
      status: "pending",
      createdAt: new Date().toISOString(),
    };
    const saved = await this.claims.insert(claim);
    if (kind === "transfer" && gym.ownerId) {
      await this.notify(
        gym.ownerId,
        "Ownership requested",
        `Someone requested ownership of ${gym.name}`,
        { gymId, claimId: saved.id, kind: "transfer" },
      );
    }
    return saved;
  }

  public async listMyClaims(callerId: string): Promise<GymClaim[]> {
    return this.claims.listByClaimant(callerId);
  }

  public async getMyClaimForGym(callerId: string, gymId: string): Promise<GymClaim | null> {
    return this.claims.findLatestByGymAndClaimant(gymId, callerId);
  }

  public async cancel(callerId: string, gymId: string): Promise<void> {
    const pending = await this.claims.findPendingByGymAndClaimant(gymId, callerId);
    if (!pending) throw new AppError("not_found", "No pending claim to withdraw");
    await this.claims.updateStatus(pending.id, { status: "cancelled", decidedAt: new Date().toISOString() });
  }

  public async reject(adminId: string, claimId: string, note: string | undefined): Promise<GymClaim> {
    const claim = await this.getClaimOr404(claimId);
    if (claim.status !== "pending") throw new AppError("conflict", "Claim is not pending");
    const patch: Partial<GymClaim> = {
      status: "rejected",
      decidedAt: new Date().toISOString(),
      decidedBy: adminId,
    };
    if (note !== undefined) patch.decisionNote = note;
    const updated = await this.claims.updateStatus(claimId, patch);
    if (!updated) throw new AppError("not_found", `Claim ${claimId} not found`);
    await this.notify(
      claim.claimantId,
      "Claim not approved",
      note && note.length > 0
        ? `Your claim was not approved: ${note}`
        : "Your gym claim was not approved",
      { gymId: claim.gymId, claimId, outcome: "rejected" },
    );
    return updated;
  }

  public async listForAdmin(status: GymClaimStatus): Promise<GymClaim[]> {
    return this.claims.listByStatus(status);
  }
}
