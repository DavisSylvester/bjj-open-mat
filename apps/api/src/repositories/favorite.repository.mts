import type { Db } from "mongodb";
import type { Favorite } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class FavoriteRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).createIndex({ userId: 1, gymId: 1 }, { unique: true });
  }

  public async add(userId: string, gymId: string): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).updateOne(
      { userId, gymId },
      { $setOnInsert: { createdAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(userId: string, gymId: string): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).deleteOne({ userId, gymId });
  }

  public async listGymIds(userId: string): Promise<string[]> {
    const docs = await this.collection<Favorite>(COLLECTIONS.favorites).find({ userId }).toArray();
    return docs.map((d) => d.gymId);
  }

  public async deleteByUserId(userId: string): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).deleteMany({ userId });
  }
}
