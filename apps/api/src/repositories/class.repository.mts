import type { Db } from "mongodb";
import type { GymClass } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ClassDoc extends GymClass {
  _id: string;
}

export class ClassRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ClassDoc>(COLLECTIONS.gymClasses);
    await col.createIndex({ gymId: 1, status: 1 });
    await col.createIndex({ gymId: 1, dayOfWeek: 1 });
  }

  public async insert(c: GymClass): Promise<GymClass> {
    await this.collection<ClassDoc>(COLLECTIONS.gymClasses).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<GymClass | null> {
    return stripId<GymClass>(await this.collection<ClassDoc>(COLLECTIONS.gymClasses).findOne({ _id: id }));
  }

  public async listActiveByGym(gymId: string): Promise<GymClass[]> {
    const docs = await this.collection<ClassDoc>(COLLECTIONS.gymClasses)
      .find({ gymId, status: { $ne: "archived" } }).toArray();
    return docs.map((d) => stripId<GymClass>(d) as GymClass);
  }

  public async update(id: string, patch: Partial<GymClass>): Promise<GymClass | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<ClassDoc>(COLLECTIONS.gymClasses).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
