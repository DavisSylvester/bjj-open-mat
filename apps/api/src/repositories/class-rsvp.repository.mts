import type { Db } from "mongodb";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface ClassRsvpDoc {
  classId: string;
  date: string;
  userId: string;
  rsvpAt: string;
  isMember: boolean;
}

export class ClassRsvpRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps);
    await col.createIndex({ classId: 1, date: 1, userId: 1 }, { unique: true });
    await col.createIndex({ classId: 1, date: 1 });
  }

  public async add(classId: string, date: string, userId: string, isMember: boolean): Promise<void> {
    await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).updateOne(
      { classId, date, userId },
      { $set: { isMember }, $setOnInsert: { rsvpAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(classId: string, date: string, userId: string): Promise<void> {
    await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).deleteOne({ classId, date, userId });
  }

  public async count(classId: string, date: string): Promise<number> {
    return this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).countDocuments({ classId, date });
  }

  public async countsForClassDates(classId: string, dates: string[]): Promise<Record<string, number>> {
    const rows = await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps).aggregate<{ _id: string; n: number }>([
      { $match: { classId, date: { $in: dates } } },
      { $group: { _id: "$date", n: { $sum: 1 } } },
    ]).toArray();
    const out: Record<string, number> = {};
    for (const r of rows) out[r._id] = r.n;
    return out;
  }

  public async list(classId: string, date: string): Promise<Array<{ userId: string; isMember: boolean; rsvpAt: string }>> {
    const docs = await this.collection<ClassRsvpDoc>(COLLECTIONS.classRsvps)
      .find({ classId, date }).sort({ rsvpAt: 1, userId: 1 }).toArray();
    return docs.map((d) => ({ userId: d.userId, isMember: d.isMember, rsvpAt: d.rsvpAt }));
  }
}
