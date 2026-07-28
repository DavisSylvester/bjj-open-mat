import type { Db } from "mongodb";
import type { InstructorRating } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface RatingDoc extends InstructorRating {
  _id: string;
}

export class InstructorRatingRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<RatingDoc>(COLLECTIONS.instructorRatings);
    await col.createIndex({ classId: 1, date: 1, ratedByUserId: 1 }, { unique: true });
    await col.createIndex({ instructorUserId: 1 });
    await col.createIndex({ gymId: 1, instructorUserId: 1, date: 1 });
  }

  public async upsert(r: InstructorRating): Promise<InstructorRating> {
    const { id, classId, date, ratedByUserId, createdAt, ...rest } = r;
    const now: string = new Date().toISOString();
    await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).updateOne(
      { classId, date, ratedByUserId },
      { $set: { classId, date, ratedByUserId, ...rest }, $setOnInsert: { _id: id, id, createdAt: createdAt ?? now } },
      { upsert: true },
    );
    const doc = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).findOne({ classId, date, ratedByUserId });
    return stripId<InstructorRating>(doc) as InstructorRating;
  }

  public async summaryForInstructor(instructorUserId: string): Promise<{ avg: number; count: number }> {
    const rows = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).aggregate<{ avg: number; count: number }>([
      { $match: { instructorUserId } },
      { $group: { _id: "$instructorUserId", avg: { $avg: "$stars" }, count: { $sum: 1 } } },
    ]).toArray();
    if (rows.length === 0) return { avg: 0, count: 0 };
    return { avg: Math.round((rows[0]!.avg) * 10) / 10, count: rows[0]!.count };
  }

  public async listForGymInstructor(
    gymId: string, instructorUserId?: string, from?: string, to?: string,
  ): Promise<InstructorRating[]> {
    const filter: Record<string, unknown> = { gymId };
    if (instructorUserId !== undefined) filter["instructorUserId"] = instructorUserId;
    if (from !== undefined || to !== undefined) {
      const range: Record<string, string> = {};
      if (from !== undefined) range["$gte"] = from;
      if (to !== undefined) range["$lte"] = to;
      filter["date"] = range;
    }
    const docs = await this.collection<RatingDoc>(COLLECTIONS.instructorRatings).find(filter).sort({ date: -1 }).toArray();
    return docs.map((d) => stripId<InstructorRating>(d) as InstructorRating);
  }
}
