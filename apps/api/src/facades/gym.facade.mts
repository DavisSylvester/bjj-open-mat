import type { CreateGymRequest, Gym, UpdateGymRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { FavoriteRepository } from "../repositories/favorite.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { Geocoder } from "../services/geocoder.mts";

type IdFactory = () => string;

export interface DirectionsPayload {
  latitude: number;
  longitude: number;
  address: string;
  mapsUrl: string;
}

export class GymFacade {

  public constructor(
    private readonly gyms: Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "findNearby">,
    private readonly favorites: Pick<FavoriteRepository, "add" | "remove" | "listGymIds">,
    private readonly newId: IdFactory,
    private readonly geocoder: Pick<Geocoder, "lookupZip">,
  ) {}

  public async create(ownerId: string, req: CreateGymRequest): Promise<Gym> {
    const location = req.location ?? (req.postalCode ? (this.geocoder.lookupZip(req.postalCode) ?? undefined) : undefined);
    const gym: Gym = {
      id: this.newId(),
      ownerId,
      name: req.name,
      description: req.description,
      address: req.address,
      city: req.city,
      state: req.state,
      country: req.country,
      postalCode: req.postalCode,
      location,
      googlePlaceId: req.googlePlaceId,
      phone: req.phone,
      website: req.website,
      logoUrl: req.logoUrl,
      amenities: req.amenities ?? [],
      isVerified: false,
      createdAt: new Date().toISOString(),
    };
    return this.gyms.insert(gym);
  }

  public async getById(id: string): Promise<Gym> {
    const gym = await this.gyms.findById(id);
    if (!gym) throw new AppError("not_found", `Gym ${id} not found`);
    return gym;
  }

  public async update(ownerId: string, id: string, patch: UpdateGymRequest): Promise<Gym> {
    const gym = await this.getById(id);
    if (gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
    const updated = await this.gyms.update(id, patch);
    return updated as Gym;
  }

  public async list(opts: { ownerId?: string; skip: number; limit: number }): Promise<{ items: Gym[]; total: number }> {
    return opts.ownerId
      ? this.gyms.listByOwner(opts.ownerId, opts.skip, opts.limit)
      : this.gyms.list(opts.skip, opts.limit);
  }

  public async nearby(lat: number, lng: number, radiusKm: number): Promise<Gym[]> {
    return this.gyms.findNearby(lat, lng, radiusKm);
  }

  public async directions(id: string): Promise<DirectionsPayload> {
    const gym = await this.getById(id);
    if (!gym.location) throw new AppError("not_found", "Gym has no location");
    const { lat, lng } = gym.location;
    return {
      latitude: lat,
      longitude: lng,
      address: gym.address,
      mapsUrl: `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`,
    };
  }

  public async favorite(userId: string, gymId: string): Promise<void> {
    await this.getById(gymId);
    await this.favorites.add(userId, gymId);
  }

  public async unfavorite(userId: string, gymId: string): Promise<void> {
    await this.favorites.remove(userId, gymId);
  }

  public async listFavorites(userId: string): Promise<Gym[]> {
    const ids = await this.favorites.listGymIds(userId);
    const gyms = await Promise.all(ids.map((id) => this.gyms.findById(id)));
    return gyms.filter((g): g is Gym => g !== null);
  }
}
