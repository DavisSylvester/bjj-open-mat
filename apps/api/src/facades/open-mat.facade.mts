import type {
  CreateOpenMatRequest,
  OpenMat,
  OpenMatDetail,
  UpdateOpenMatRequest,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { OpenMatFilter, OpenMatRepository } from "../repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../repositories/rsvp.repository.mts";

type IdFactory = () => string;

export interface RsvpResult {
  ok: true;
  attendeeCount: number;
  attending: boolean;
}

export class OpenMatFacade {

  public constructor(
    private readonly mats: Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount">,
    private readonly gyms: Pick<GymRepository, "findById">,
    private readonly rsvps: Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">,
    private readonly newId: IdFactory,
  ) {}

  public async create(ownerId: string, req: CreateOpenMatRequest): Promise<OpenMatDetail> {
    const gym = await this.gyms.findById(req.gymId);
    if (!gym) throw new AppError("not_found", `Gym ${req.gymId} not found`);
    if (gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");

    const detail: OpenMatDetail = {
      id: this.newId(),
      gymId: req.gymId,
      hostId: req.hostId,
      title: req.title,
      description: req.description,
      dayOfWeek: req.dayOfWeek,
      startTime: req.startTime,
      endTime: req.endTime,
      isRecurring: req.isRecurring ?? true,
      specificDate: req.specificDate,
      maxParticipants: req.maxParticipants,
      skillLevel: req.skillLevel ?? "all",
      giType: req.giType ?? "both",
      isCancelled: false,
      feeCents: req.feeCents,
      attendeeCount: 0,
      gymName: gym.name,
      latitude: gym.location?.lat,
      longitude: gym.location?.lng,
      address: gym.address,
      city: gym.city ?? "",
      state: gym.state ?? "",
      postalCode: gym.postalCode,
      gymRating: gym.rating,
      createdAt: new Date().toISOString(),
    };
    return this.mats.insert(detail, gym.ownerId);
  }

  public async detail(id: string): Promise<OpenMatDetail> {
    const found = await this.mats.findById(id);
    if (!found) throw new AppError("not_found", `Open mat ${id} not found`);
    return found;
  }

  public async assertOwner(ownerId: string, openMatId: string): Promise<void> {
    const mat = await this.mats.findById(openMatId);
    if (!mat) throw new AppError("not_found", `Open mat ${openMatId} not found`);
    const gym = await this.gyms.findById(mat.gymId);
    if (!gym || gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
  }

  public async update(ownerId: string, id: string, patch: UpdateOpenMatRequest): Promise<OpenMatDetail> {
    const current = await this.detail(id);
    const gym = await this.gyms.findById(current.gymId);
    if (!gym || gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
    return (await this.mats.update(id, patch)) as OpenMatDetail;
  }

  public async list(filter: OpenMatFilter, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    return this.mats.list(filter, skip, limit);
  }

  public async nearby(lat: number, lng: number, radiusKm: number): Promise<OpenMat[]> {
    return this.mats.findNearby(lat, lng, radiusKm);
  }

  public async rsvp(id: string, sessionDate: string, userId: string): Promise<RsvpResult> {
    await this.detail(id);
    await this.rsvps.add(id, sessionDate, userId);
    const count = await this.rsvps.count(id, sessionDate);
    await this.mats.setAttendeeCount(id, count);
    return { ok: true, attendeeCount: count, attending: true };
  }

  public async cancelRsvp(id: string, sessionDate: string, userId: string): Promise<RsvpResult> {
    await this.rsvps.remove(id, sessionDate, userId);
    const count = await this.rsvps.count(id, sessionDate);
    await this.mats.setAttendeeCount(id, count);
    return { ok: true, attendeeCount: count, attending: false };
  }

  public async attendeeUserIds(id: string, sessionDate: string): Promise<string[]> {
    return this.rsvps.userIds(id, sessionDate);
  }
}
