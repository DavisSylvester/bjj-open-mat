import type { Db } from "mongodb";
import type { UserBlock } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface BlockDoc extends UserBlock {
  _id: string;
}

export class UserBlockRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).createIndex({ blockerId: 1, blockedId: 1 }, { unique: true });
  }

  public async insert(b: UserBlock): Promise<UserBlock> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).insertOne({ ...b, _id: b.id });
    return b;
  }

  public async existsEitherWay(a: string, b: string): Promise<boolean> {
    const found = await this.collection<BlockDoc>(COLLECTIONS.userBlocks).findOne({
      $or: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }],
    });
    return found !== null;
  }

  public async listBlockedBy(userId: string): Promise<string[]> {
    const docs = await this.collection<BlockDoc>(COLLECTIONS.userBlocks).find({ blockerId: userId }).toArray();
    return docs.map((d) => d.blockedId);
  }

  public async deleteByBlocked(blockerId: string, blockedId: string): Promise<void> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).deleteOne({ blockerId, blockedId });
  }
}
