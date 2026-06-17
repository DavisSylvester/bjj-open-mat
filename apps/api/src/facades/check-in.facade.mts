import type { CheckIn, ReviewRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { CheckInRepository } from "../repositories/check-in.repository.mts";

type IdFactory = () => string;
type Clock = () => Date;

const REVIEW_WINDOW_MS = 48 * 60 * 60 * 1000;

export class CheckInFacade {

  public constructor(
    private readonly checkins: Pick<CheckInRepository, "insert" | "findById" | "setReview" | "listByUser" | "listBySession">,
    private readonly newId: IdFactory,
    private readonly now: Clock = () => new Date(),
  ) {}

  public async checkIn(openMatId: string, userId: string, sessionDate: string): Promise<CheckIn> {
    return this.checkins.insert({
      id: this.newId(),
      openMatId,
      userId,
      sessionDate,
      checkedInAt: this.now().toISOString(),
      createdAt: this.now().toISOString(),
    });
  }

  public async review(checkInId: string, userId: string, req: ReviewRequest): Promise<CheckIn> {
    const checkIn = await this.checkins.findById(checkInId);
    if (!checkIn) throw new AppError("not_found", `Check-in ${checkInId} not found`);
    if (checkIn.userId !== userId) throw new AppError("forbidden", "Cannot review another user's check-in");

    const elapsed = this.now().getTime() - new Date(checkIn.checkedInAt).getTime();
    if (elapsed > REVIEW_WINDOW_MS) throw new AppError("conflict", "Review window (48h) has expired");

    const updated = await this.checkins.setReview(checkInId, {
      rating: req.rating,
      review: req.review,
      categoryRatings: req.categoryRatings,
    });
    return updated as CheckIn;
  }

  public async listForUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    return this.checkins.listByUser(userId, skip, limit);
  }

  public async listForSession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    return this.checkins.listBySession(openMatId, sessionDate);
  }
}
