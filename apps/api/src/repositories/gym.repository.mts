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

  public async findNearby(lat: number, lng: number, radiusKm: number): Promise<Gym[]> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const docs = await col
      .aggregate<GymDoc & { distanceMeters: number }>([
        {
          $geoNear: {
            near: { type: "Point", coordinates: [lng, lat] },
            distanceField: "distanceMeters",
            maxDistance: radiusKm * 1000,
            spherical: true,
          },
        },
      ])
      .toArray();
    return docs.map((d) => fromDoc(d) as Gym);
  }
}
