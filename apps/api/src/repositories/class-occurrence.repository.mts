import type { Db } from "mongodb";
import type { ClassOccurrence } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface OccurrenceDoc extends ClassOccurrence {
  _id: string;
}

export class ClassOccurrenceRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences);
    await col.createIndex({ classId: 1, date: 1 }, { unique: true });
    await col.createIndex({ gymId: 1, date: 1 });
  }

  public async upsert(o: ClassOccurrence): Promise<ClassOccurrence> {
    const { id, classId, date, ...rest } = o;
    await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences).updateOne(
      { classId, date },
      { $set: { classId, date, ...rest }, $setOnInsert: { _id: id, id } },
      { upsert: true },
    );
    return (await this.find(classId, date)) as ClassOccurrence;
  }

  public async find(classId: string, date: string): Promise<ClassOccurrence | null> {
    return stripId<ClassOccurrence>(
      await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences).findOne({ classId, date }),
    );
  }

  public async listByGymRange(gymId: string, from: string, to: string): Promise<ClassOccurrence[]> {
    const docs = await this.collection<OccurrenceDoc>(COLLECTIONS.classOccurrences)
      .find({ gymId, date: { $gte: from, $lte: to } }).toArray();
    return docs.map((d) => stripId<ClassOccurrence>(d) as ClassOccurrence);
  }
}
