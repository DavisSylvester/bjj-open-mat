import type { Db } from "mongodb";
import type { ChannelReadState } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ReadStateDoc extends ChannelReadState {
  _id: string;
}

export class ChannelReadStateRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates)
      .createIndex({ channelId: 1, userId: 1 }, { unique: true });
  }

  public async find(channelId: string, userId: string): Promise<ChannelReadState | null> {
    return stripId<ChannelReadState>(
      await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).findOne({ channelId, userId }),
    );
  }

  public async upsertLastReadAt(channelId: string, userId: string, at: string, newId: string): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).updateOne(
      { channelId, userId },
      { $set: { lastReadAt: at }, $setOnInsert: { _id: newId, id: newId, channelId, userId, muted: false } },
      { upsert: true },
    );
  }

  public async upsertMuted(channelId: string, userId: string, muted: boolean, newId: string): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).updateOne(
      { channelId, userId },
      { $set: { muted }, $setOnInsert: { _id: newId, id: newId, channelId, userId } },
      { upsert: true },
    );
  }
}
