import type { Db } from "mongodb";
import type { DeviceToken } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface DeviceTokenDoc extends DeviceToken {
  _id: string;
}

export class DeviceTokenRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens);
    await col.createIndex({ token: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
  }

  public async upsertByToken(d: DeviceToken): Promise<DeviceToken> {
    const col = this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens);
    await col.updateOne(
      { token: d.token },
      { $set: { userId: d.userId, platform: d.platform, lastSeenAt: d.createdAt }, $setOnInsert: { _id: d.id, token: d.token, createdAt: d.createdAt } },
      { upsert: true },
    );
    return d;
  }

  public async listByUser(userId: string): Promise<DeviceToken[]> {
    const docs = await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).find({ userId }).toArray();
    return docs.map((d) => stripId<DeviceToken>(d) as DeviceToken);
  }

  public async deleteByTokenAndUser(token: string, userId: string): Promise<void> {
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteOne({ token, userId });
  }

  public async pruneTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteMany({ token: { $in: tokens } });
  }

  public async deleteByUserId(userId: string): Promise<void> {
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteMany({ userId });
  }
}
