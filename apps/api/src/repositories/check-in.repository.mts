import type { Db, Filter } from "mongodb";
import type { CategoryRatings, CheckIn } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface CheckInDoc extends CheckIn {
  _id: string;
}

export class CheckInRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<CheckInDoc>(COLLECTIONS.checkins);
    await col.createIndex({ userId: 1 });
    await col.createIndex({ openMatId: 1, sessionDate: 1 });
  }

  public async insert(checkIn: CheckIn): Promise<CheckIn> {
    await this.collection<CheckInDoc>(COLLECTIONS.checkins).insertOne({ ...checkIn, _id: checkIn.id });
    return checkIn;
  }

  public async findById(id: string): Promise<CheckIn | null> {
    return stripId<CheckIn>(await this.collection<CheckInDoc>(COLLECTIONS.checkins).findOne({ _id: id }));
  }

  public async setReview(
    id: string,
    review: { rating: number; review?: string; categoryRatings: CategoryRatings; reviewedAt: string },
  ): Promise<CheckIn | null> {
    await this.collection<CheckInDoc>(COLLECTIONS.checkins).updateOne({ _id: id }, { $set: review });
    return this.findById(id);
  }

  /// Average overall rating + count across all reviewed check-ins for a gym.
  public async ratingStatsForGym(gymId: string): Promise<{ avg: number; count: number }> {
    const rows = await this.collection<CheckInDoc>(COLLECTIONS.checkins)
      .aggregate<{ avg: number; count: number }>([
        { $match: { gymId, rating: { $ne: null } } },
        { $group: { _id: null, avg: { $avg: "$rating" }, count: { $sum: 1 } } },
      ])
      .toArray();
    return rows.length ? { avg: rows[0].avg, count: rows[0].count } : { avg: 0, count: 0 };
  }

  /// Reviewed check-ins for a target (gym or open mat), newest review first.
  public async listReviews(
    by: { gymId: string } | { openMatId: string },
    skip: number,
    limit: number,
  ): Promise<{ items: CheckIn[]; total: number }> {
    const col = this.collection<CheckInDoc>(COLLECTIONS.checkins);
    const q = { ...by, rating: { $ne: null } } as unknown as Filter<CheckInDoc>;
    const total = await col.countDocuments(q);
    const docs = await col.find(q).sort({ reviewedAt: -1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => stripId<CheckIn>(d) as CheckIn), total };
  }

  public async listByUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    const col = this.collection<CheckInDoc>(COLLECTIONS.checkins);
    const total = await col.countDocuments({ userId });
    const docs = await col.find({ userId }).sort({ checkedInAt: -1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => stripId<CheckIn>(d) as CheckIn), total };
  }

  public async listBySession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    const q = sessionDate ? { openMatId, sessionDate } : { openMatId };
    const docs = await this.collection<CheckInDoc>(COLLECTIONS.checkins).find(q).toArray();
    return docs.map((d) => stripId<CheckIn>(d) as CheckIn);
  }
}
