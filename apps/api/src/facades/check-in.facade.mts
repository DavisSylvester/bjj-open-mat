import type { CheckIn, CheckInLocationStatus, CreateCheckInRequest, ReviewRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { CheckInRepository } from "../repositories/check-in.repository.mts";
import type { OpenMatRepository } from "../repositories/open-mat.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

type IdFactory = () => string;
type Clock = () => Date;

const REVIEW_WINDOW_MS = 48 * 60 * 60 * 1000;
const VERIFY_RADIUS_M = 500;

export function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (d: number): number => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export class CheckInFacade {

  public constructor(
    private readonly checkins: Pick<CheckInRepository, "insert" | "findById" | "setReview" | "listByUser" | "listBySession">,
    private readonly openMats: Pick<OpenMatRepository, "findById">,
    private readonly users: Pick<UserRepository, "findById">,
    private readonly newId: IdFactory,
    private readonly now: Clock = () => new Date(),
  ) {}

  public async checkIn(openMatId: string, userId: string, req: CreateCheckInRequest): Promise<CheckIn> {
    const mat = await this.openMats.findById(openMatId);
    if (!mat) throw new AppError("not_found", `Open mat ${openMatId} not found`);
    const user = await this.users.findById(userId);

    let locationStatus: CheckInLocationStatus = "no_location";
    let distanceM: number | undefined;
    if (req.latitude != null && req.longitude != null && mat.latitude != null && mat.longitude != null) {
      distanceM = haversineMeters(req.latitude, req.longitude, mat.latitude, mat.longitude);
      locationStatus = distanceM <= VERIFY_RADIUS_M ? "verified" : "far";
    }

    const ts = this.now().toISOString();
    return this.checkins.insert({
      id: this.newId(),
      openMatId,
      userId,
      sessionDate: req.sessionDate,
      checkedInAt: ts,
      latitude: req.latitude,
      longitude: req.longitude,
      gpsAccuracyM: req.gpsAccuracyM,
      locationStatus,
      distanceM,
      gymId: mat.gymId,
      gymName: mat.gymName,
      gymCity: mat.city,
      gymState: mat.state,
      openMatTitle: mat.title,
      userName: user?.displayName,
      beltRank: req.beltRank ?? user?.beltRank,
      note: req.note,
      rounds: req.rounds,
      intensity: req.intensity,
      partners: req.partners,
      createdAt: ts,
    });
  }

  public async review(checkInId: string, userId: string, req: ReviewRequest): Promise<CheckIn> {
    const checkIn = await this.checkins.findById(checkInId);
    if (!checkIn) throw new AppError("not_found", `Check-in ${checkInId} not found`);
    if (checkIn.userId !== userId) throw new AppError("forbidden", "Cannot review another user's check-in");
    const elapsed = this.now().getTime() - new Date(checkIn.checkedInAt).getTime();
    if (elapsed > REVIEW_WINDOW_MS) throw new AppError("conflict", "Review window (48h) has expired");
    const updated = await this.checkins.setReview(checkInId, { rating: req.rating, review: req.review, categoryRatings: req.categoryRatings });
    return updated as CheckIn;
  }

  public async listForUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    return this.checkins.listByUser(userId, skip, limit);
  }

  public async listForSession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    return this.checkins.listBySession(openMatId, sessionDate);
  }
}
