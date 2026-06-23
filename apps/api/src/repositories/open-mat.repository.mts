import type { Db, Document, Filter } from "mongodb";
import type { GiType, OpenMat, OpenMatDetail, SkillLevel } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface OpenMatDoc extends OpenMatDetail {
  _id: string;
  gymOwnerId?: string;
  geo?: { type: "Point"; coordinates: [number, number] };
}

export interface OpenMatFilter {
  dayOfWeek?: number;
  giType?: GiType;
  skillLevel?: SkillLevel;
  gymOwnerId?: string;
  gymId?: string;
  hostId?: string;
  verified?: boolean;
  status?: "live" | "hidden";
}

function toListItem(doc: OpenMatDoc): OpenMat {
  const { _id, geo, gymOwnerId, latitude, longitude, address, city, state, postalCode, gymRating, ...item } = doc;
  return item as unknown as OpenMat;
}

function toDetail(doc: OpenMatDoc | null): OpenMatDetail | null {
  if (!doc) return null;
  const { _id, geo, gymOwnerId, ...rest } = doc;
  return rest as unknown as OpenMatDetail;
}

export class OpenMatRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<OpenMatDoc>(COLLECTIONS.openMats);
    await col.createIndex({ gymId: 1, dayOfWeek: 1 });
    await col.createIndex({ geo: "2dsphere" });
  }

  public async insert(detail: OpenMatDetail, gymOwnerId: string | undefined): Promise<OpenMatDetail> {
    const doc: OpenMatDoc = { ...detail, _id: detail.id, gymOwnerId };
    if (detail.latitude !== undefined && detail.longitude !== undefined) {
      doc.geo = { type: "Point", coordinates: [detail.longitude, detail.latitude] };
    }
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).insertOne(doc);
    return detail;
  }

  public async findById(id: string): Promise<OpenMatDetail | null> {
    return toDetail(await this.collection<OpenMatDoc>(COLLECTIONS.openMats).findOne({ _id: id }));
  }

  public async list(filter: OpenMatFilter, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    const q: Filter<OpenMatDoc> = {};
    if (filter.dayOfWeek !== undefined) q.dayOfWeek = filter.dayOfWeek;
    if (filter.skillLevel) q.skillLevel = filter.skillLevel;
    if (filter.giType === "gi") q.giType = { $in: ["gi", "both"] };
    else if (filter.giType === "nogi") q.giType = { $in: ["nogi", "both"] };
    if (filter.gymOwnerId) q.gymOwnerId = filter.gymOwnerId;
    if (filter.gymId) q.gymId = filter.gymId;
    if (filter.hostId) q.hostId = filter.hostId;
    if (filter.verified !== undefined) q.verified = filter.verified;
    if (filter.status) q.status = filter.status;
    else q.status = { $ne: "hidden" } as Filter<OpenMatDoc>["status"];

    const col = this.collection<OpenMatDoc>(COLLECTIONS.openMats);
    const total = await col.countDocuments(q);
    const docs = await col.find(q).sort({ startTime: 1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map(toListItem), total };
  }

  public async findNearby(lat: number, lng: number, radiusKm: number): Promise<OpenMat[]> {
    const docs = await this.collection<OpenMatDoc>(COLLECTIONS.openMats)
      .aggregate<OpenMatDoc & { distanceMeters: number }>([
        {
          $geoNear: {
            near: { type: "Point", coordinates: [lng, lat] },
            distanceField: "distanceMeters",
            maxDistance: radiusKm * 1000,
            spherical: true,
          },
        },
        { $match: { status: { $ne: "hidden" } } },
      ])
      .toArray();
    return docs.map((d) => ({ ...toListItem(d), distanceKm: d.distanceMeters / 1000 }));
  }

  public async update(id: string, patch: Partial<OpenMatDetail>): Promise<OpenMatDetail | null> {
    const set: Document = { ...patch };
    if (patch.latitude !== undefined && patch.longitude !== undefined) {
      set["geo"] = { type: "Point", coordinates: [patch.longitude, patch.latitude] };
    }
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).updateOne({ _id: id }, { $set: set });
    return this.findById(id);
  }

  public async setAttendeeCount(id: string, count: number): Promise<void> {
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).updateOne({ _id: id }, { $set: { attendeeCount: count } });
  }
}
