import type { CreateGymRequest, Gym, UpdateGymRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { FavoriteRepository } from "../repositories/favorite.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { Geocoder } from "../services/geocoder.mts";
import type { PlacesClient } from "../services/places-client.mts";

type IdFactory = () => string;

export interface DirectionsPayload {
  latitude: number;
  longitude: number;
  address: string;
  mapsUrl: string;
}

/** 100 miles. Widening never exceeds this. */
const WIDEN_CAP_KM = 161;
/** Number of doublings attempted after the requested radius. */
const WIDEN_STEPS = 2;

export interface GymSearchRequest {
  lat?: number;
  lng?: number;
  zip?: string;
  q?: string;
  radiusKm: number;
  page: number;
  limit: number;
}

/**
 * [requested, requested*2, requested*4], each clamped to WIDEN_CAP_KM, with
 * duplicates dropped so a request already at the cap yields a single attempt.
 */
function buildRadiusLadder(requestedKm: number): number[] {
  const ladder: number[] = [Math.min(requestedKm, WIDEN_CAP_KM)];
  for (let i = 0; i < WIDEN_STEPS; i += 1) {
    const next = Math.min((ladder[ladder.length - 1] as number) * 2, WIDEN_CAP_KM);
    if (next > (ladder[ladder.length - 1] as number)) ladder.push(next);
  }
  return ladder;
}

export class GymFacade {

  public constructor(
    private readonly gyms: Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "searchNearby">,
    private readonly favorites: Pick<FavoriteRepository, "add" | "remove" | "listGymIds">,
    private readonly newId: IdFactory,
    private readonly geocoder: Pick<Geocoder, "lookupZip">,
    private readonly places: PlacesClient,
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

  public async adminUpdate(id: string, patch: Partial<Gym>): Promise<Gym> {
    await this.getById(id); // existence check (throws not_found)
    const updated = await this.gyms.update(id, patch);
    return updated as Gym;
  }

  public async list(opts: { ownerId?: string; skip: number; limit: number }): Promise<{ items: Gym[]; total: number }> {
    return opts.ownerId
      ? this.gyms.listByOwner(opts.ownerId, opts.skip, opts.limit)
      : this.gyms.list(opts.skip, opts.limit);
  }

  /**
   * Geo gym search. Resolves the origin (coords win over zip), then walks a
   * widening radius ladder until something is found.
   *
   * Widening is a product policy, not a query concern, which is why it lives
   * here and not in the repository: an empty first page in a rural area should
   * quietly reach further rather than show the user nothing. It applies ONLY to
   * an empty page 1 — a partial page is a real answer, and widening mid-paging
   * would shuffle the result set under the user. Clients page through the
   * returned effectiveRadiusKm to stay on one stable set.
   */
  public async searchNearby(
    req: GymSearchRequest,
  ): Promise<{ items: Gym[]; total: number; effectiveRadiusKm: number }> {
    const origin = this.resolveOrigin(req);
    const skip = (req.page - 1) * req.limit;
    const ladder = req.page === 1 ? buildRadiusLadder(req.radiusKm) : [req.radiusKm];

    let last = { items: [] as Gym[], total: 0 };
    let effectiveRadiusKm = req.radiusKm;

    for (const radiusKm of ladder) {
      effectiveRadiusKm = radiusKm;
      last = await this.gyms.searchNearby({ ...origin, radiusKm, q: req.q, skip, limit: req.limit });
      if (last.items.length > 0) break;
    }

    return {
      items: last.items.map((gym) => ({ ...gym, sponsored: (gym.rankBoost ?? 0) > 0 })),
      total: last.total,
      effectiveRadiusKm,
    };
  }

  private resolveOrigin(req: GymSearchRequest): { lat: number; lng: number } {
    if (typeof req.lat === "number" && typeof req.lng === "number") {
      return { lat: req.lat, lng: req.lng };
    }
    if (req.zip) {
      const resolved = this.geocoder.lookupZip(req.zip);
      if (!resolved) throw new AppError("bad_request", "Unknown ZIP code");
      return { lat: resolved.lat, lng: resolved.lng };
    }
    throw new AppError("bad_request", "lat/lng or zip is required");
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

  /// Returns the Google Maps "write a review" link for a gym, or null when the
  /// gym has no Google place or Places yields nothing. Null is a normal result,
  /// not an error — the client simply omits the Google hand-off.
  public async reviewLink(id: string): Promise<{ writeAReviewUri: string | null }> {
    const gym = await this.getById(id);
    // A cached value is a hit either way: a non-empty string is the link
    // itself, and "" is the sentinel for a definitive "no link" result — both
    // skip Places. Only the absence of `googleReviewUri` triggers a lookup.
    if (gym.googleReviewUri !== undefined) {
      return { writeAReviewUri: gym.googleReviewUri || null };
    }
    if (!gym.googlePlaceId) return { writeAReviewUri: null };

    let uri: string | null = null;
    try {
      uri = await this.places.writeAReviewUri(gym.googlePlaceId);
    } catch {
      // Transient outage — do not cache, so the next request retries Places.
      return { writeAReviewUri: null };
    }

    // These links are stable, so cache to keep this one Places call per gym.
    // A definitive null is cached too (as "") to avoid re-hitting the paid,
    // unauthenticated Places API on every request for a gym with no review link.
    await this.gyms.update(id, { googleReviewUri: uri ?? "" });
    return { writeAReviewUri: uri };
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
