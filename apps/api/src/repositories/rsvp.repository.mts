import type { Db } from "mongodb";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface RsvpDoc {
  openMatId: string;
  sessionDate: string;
  userId: string;
  rsvpAt: string;
}

export class RsvpRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).createIndex(
      { openMatId: 1, sessionDate: 1, userId: 1 },
      { unique: true },
    );
  }

  public async add(openMatId: string, sessionDate: string, userId: string): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).updateOne(
      { openMatId, sessionDate, userId },
      { $setOnInsert: { rsvpAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(openMatId: string, sessionDate: string, userId: string): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).deleteOne({ openMatId, sessionDate, userId });
  }

  public async count(openMatId: string, sessionDate: string): Promise<number> {
    return this.collection<RsvpDoc>(COLLECTIONS.rsvps).countDocuments({ openMatId, sessionDate });
  }

  public async userIds(openMatId: string, sessionDate: string): Promise<string[]> {
    const docs = await this.collection<RsvpDoc>(COLLECTIONS.rsvps).find({ openMatId, sessionDate }).toArray();
    return docs.map((d) => d.userId);
  }
}
