import type { Db, Document } from "mongodb";
import type { Gym } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface GeoPoint {
  type: "Point";
  coordinates: [number, number];
}

/**
 * Stored shape of a gym. The identifier lives in `_id`; `id` is not stored.
 *
 * Historically [insert] also persisted a redundant `id` alongside `_id`, so a
 * handful of API-created gyms carry both. Scraper-created gyms have only `_id`,
 * which is why the mapper must derive `id` from `_id` rather than relying on
 * the field surviving a spread.
 */
export interface GymDoc extends Omit<Gym, "id" | "location" | "distanceKm"> {
  _id: string;
  geo?: GeoPoint;
  /** Legacy duplicate of `_id` on older API-created documents. `_id` wins. */
  id?: string;
}

function toGeo(loc: Gym["location"]): GeoPoint | undefined {
  return loc ? { type: "Point", coordinates: [loc.lng, loc.lat] } : undefined;
}

export function fromDoc(doc: (GymDoc & { distanceMeters?: number }) | null): Gym | null {
  if (!doc) return null;
  // `id` is pulled out of `rest` and re-derived from `_id`: the stored copy is
  // absent on scraper-created gyms and could be stale where it does exist.
  const { _id, geo, distanceMeters, id: _legacyId, ...rest } = doc;
  const gym: Gym = { ...(rest as unknown as Omit<Gym, "id">), id: _id };
  if (geo) gym.location = { lng: geo.coordinates[0], lat: geo.coordinates[1] };
  if (typeof distanceMeters === "number") gym.distanceKm = distanceMeters / 1000;
  return gym;
}

/**
 * Escape regex metacharacters so user text is matched literally. Without this a
 * gym named "Alliance (North)" is unsearchable (the parens become a group) and
 * a crafted `q` is a ReDoS vector.
 */
function escapeRegex(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export interface GymSearchOptions {
  lat: number;
  lng: number;
  radiusKm: number;
  q?: string;
  skip: number;
  limit: number;
}

interface FacetResult {
  total: { n: number }[];
  items: (GymDoc & { distanceMeters: number })[];
}

export class GymRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    await col.createIndex({ geo: "2dsphere" });
    await col.createIndex({ ownerId: 1 });
  }

  public async insert(gym: Gym): Promise<Gym> {
    const { location, distanceKm, ...rest } = gym;
    const doc: GymDoc = { ...(rest as unknown as GymDoc), _id: gym.id, geo: toGeo(location) };
    await this.collection<GymDoc>(COLLECTIONS.gyms).insertOne(doc);
    return gym;
  }

  public async findById(id: string): Promise<Gym | null> {
    return fromDoc(await this.collection<GymDoc>(COLLECTIONS.gyms).findOne({ _id: id }));
  }

  public async listByOwner(ownerId: string, skip: number, limit: number): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const total = await col.countDocuments({ ownerId });
    const docs = await col.find({ ownerId }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => fromDoc(d) as Gym), total };
  }

  public async list(skip: number, limit: number): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const total = await col.countDocuments({});
    const docs = await col.find({}).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => fromDoc(d) as Gym), total };
  }

  public async update(id: string, patch: Partial<Gym>): Promise<Gym | null> {
    const { location, distanceKm, ...rest } = patch;
    const set: Document = { ...rest };
    if (location !== undefined) set["geo"] = toGeo(location);
    await this.collection<GymDoc>(COLLECTIONS.gyms).updateOne({ _id: id }, { $set: set });
    return this.findById(id);
  }

  public async searchNearby(opts: GymSearchOptions): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const q = opts.q?.trim();

    const pipeline: Document[] = [
      {
        // $geoNear must be the first stage in the pipeline. It both filters by
        // maxDistance and emits distanceMeters for the sort below.
        $geoNear: {
          near: { type: "Point", coordinates: [opts.lng, opts.lat] },
          distanceField: "distanceMeters",
          maxDistance: opts.radiusKm * 1000,
          spherical: true,
        },
      },
    ];

    if (q) {
      const rx = { $regex: escapeRegex(q), $options: "i" };
      pipeline.push({ $match: { $or: [{ name: rx }, { city: rx }] } });
    }

    // Normalize the missing field to 0 before sorting: no document carries
    // rankBoost today, and sorting on a missing field orders by BSON
    // null-vs-integer rules rather than by distance.
    pipeline.push({ $addFields: { rankBoost: { $ifNull: ["$rankBoost", 0] } } });

    // joinCode is a gym's roster-join secret and this endpoint is public.
    // ownerId is not the caller's business either. getById is unaffected.
    pipeline.push({ $project: { joinCode: 0, ownerId: 0 } });

    pipeline.push({
      $facet: {
        total: [{ $count: "n" }],
        items: [{ $sort: { rankBoost: -1, distanceMeters: 1 } }, { $skip: opts.skip }, { $limit: opts.limit }],
      },
    });

    const [res] = await col.aggregate<FacetResult>(pipeline).toArray();
    return {
      items: (res?.items ?? []).map((d) => fromDoc(d) as Gym),
      total: res?.total[0]?.n ?? 0,
    };
  }
}
