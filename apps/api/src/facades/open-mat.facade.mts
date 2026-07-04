import type {
  CreateOpenMatRequest,
  Gym,
  OpenMat,
  OpenMatDetail,
  UpdateOpenMatRequest,
  UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { OpenMatFilter, OpenMatRepository } from "../repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../repositories/rsvp.repository.mts";
import type { Geocoder } from "../services/geocoder.mts";

type IdFactory = () => string;

export interface RsvpResult {
  ok: true;
  attendeeCount: number;
  attending: boolean;
}

export class OpenMatFacade {

  public constructor(
    private readonly mats: Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount">,
    private readonly gyms: Pick<GymRepository, "findById" | "insert">,
    private readonly rsvps: Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">,
    private readonly newId: IdFactory,
    private readonly geocoder: Pick<Geocoder, "lookupZip">,
  ) {}

  public async create(submitterId: string, role: UserRole, req: CreateOpenMatRequest): Promise<OpenMatDetail> {
    let gym: Gym;
    if (req.gymId) {
      const found = await this.gyms.findById(req.gymId);
      if (!found) throw new AppError("not_found", `Gym ${req.gymId} not found`);
      gym = found;
    } else if (req.newGym) {
      const loc =
        req.newGym.latitude !== undefined && req.newGym.longitude !== undefined
          ? { lat: req.newGym.latitude, lng: req.newGym.longitude }
          : req.newGym.postalCode
            ? (this.geocoder.lookupZip(req.newGym.postalCode) ?? undefined)
            : undefined;
      gym = await this.gyms.insert({
        id: this.newId(),
        name: req.newGym.name,
        address: req.newGym.address,
        city: req.newGym.city,
        state: req.newGym.state,
        postalCode: req.newGym.postalCode,
        country: req.newGym.country,
        location: loc,
        amenities: [],
        isVerified: false,
        createdAt: new Date().toISOString(),
      });
    } else {
      throw new AppError("bad_request", "Provide gymId or newGym");
    }

    const verified: boolean = role === "admin" || (gym.ownerId !== undefined && gym.ownerId === submitterId);
    const detail: OpenMatDetail = {
      id: this.newId(),
      gymId: gym.id,
      hostId: submitterId,
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
      verified,
      status: "live",
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

  public async assertOwnerOrAdmin(callerId: string, role: UserRole, openMatId: string): Promise<OpenMatDetail> {
    const mat = await this.mats.findById(openMatId);
    if (!mat) throw new AppError("not_found", `Open mat ${openMatId} not found`);
    if (role === "admin") return mat;
    const gym = await this.gyms.findById(mat.gymId);
    if (!gym || gym.ownerId !== callerId) throw new AppError("forbidden", "Not the gym owner or an admin");
    return mat;
  }

  public async verify(callerId: string, role: UserRole, id: string): Promise<OpenMatDetail> {
    await this.assertOwnerOrAdmin(callerId, role, id);
    return (await this.mats.update(id, { verified: true })) as OpenMatDetail;
  }

  public async setHidden(callerId: string, role: UserRole, id: string, hidden: boolean): Promise<OpenMatDetail> {
    await this.assertOwnerOrAdmin(callerId, role, id);
    return (await this.mats.update(id, { status: hidden ? "hidden" : "live" })) as OpenMatDetail;
  }

  public async update(callerId: string, role: UserRole, id: string, patch: UpdateOpenMatRequest): Promise<OpenMatDetail> {
    const current = await this.detail(id);
    if (role !== "admin") {
      const gym = await this.gyms.findById(current.gymId);
      if (!gym || gym.ownerId !== callerId) throw new AppError("forbidden", "Not the gym owner or an admin");
    }
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
