import type { Db } from "mongodb";
import type { ClassJournalEntry } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface JournalDoc extends ClassJournalEntry {
  _id: string;
}

export class ClassJournalRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<JournalDoc>(COLLECTIONS.classJournals);
    await col.createIndex({ classId: 1, date: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1, date: -1 });
    await col.createIndex({ classId: 1, date: 1, shared: 1 });
  }

  public async upsert(e: ClassJournalEntry): Promise<ClassJournalEntry> {
    const { id, classId, date, userId, createdAt, ...rest } = e;
    const now: string = new Date().toISOString();
    await this.collection<JournalDoc>(COLLECTIONS.classJournals).updateOne(
      { classId, date, userId },
      {
        $set: { classId, date, userId, ...rest, updatedAt: now },
        $setOnInsert: { _id: id, id, createdAt: createdAt ?? now },
      },
      { upsert: true },
    );
    return (await this.findMine(classId, date, userId)) as ClassJournalEntry;
  }

  public async findMine(
    classId: string,
    date: string,
    userId: string,
  ): Promise<ClassJournalEntry | null> {
    return stripId<ClassJournalEntry>(
      await this.collection<JournalDoc>(COLLECTIONS.classJournals).findOne({
        classId,
        date,
        userId,
      }),
    );
  }

  public async listByUserRange(
    userId: string,
    from: string,
    to: string,
  ): Promise<ClassJournalEntry[]> {
    const docs = await this.collection<JournalDoc>(COLLECTIONS.classJournals)
      .find({ userId, date: { $gte: from, $lte: to } })
      .sort({ date: -1 })
      .toArray();
    return docs.map((d) => stripId<ClassJournalEntry>(d) as ClassJournalEntry);
  }

  public async listSharedForOccurrence(classId: string, date: string): Promise<ClassJournalEntry[]> {
    const docs = await this.collection<JournalDoc>(COLLECTIONS.classJournals)
      .find({ classId, date, shared: true })
      .toArray();
    return docs.map((d) => stripId<ClassJournalEntry>(d) as ClassJournalEntry);
  }
}
