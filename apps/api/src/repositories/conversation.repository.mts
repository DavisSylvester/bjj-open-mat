import type { Db } from "mongodb";
import type { Conversation } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ConversationDoc extends Conversation {
  _id: string;
}

export class ConversationRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ConversationDoc>(COLLECTIONS.conversations);
    await col.createIndex({ pairKey: 1 }, { unique: true, sparse: true });
    await col.createIndex({ kind: 1, gymId: 1 });
    await col.createIndex({ lastMessageAt: -1 });
  }

  public async insert(c: Conversation): Promise<Conversation> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<Conversation | null> {
    return stripId<Conversation>(await this.collection<ConversationDoc>(COLLECTIONS.conversations).findOne({ _id: id }));
  }

  public async findDirectByPairKey(pairKey: string): Promise<Conversation | null> {
    return stripId<Conversation>(await this.collection<ConversationDoc>(COLLECTIONS.conversations).findOne({ pairKey }));
  }

  public async listChannelsByGym(gymId: string): Promise<Conversation[]> {
    const docs = await this.collection<ConversationDoc>(COLLECTIONS.conversations)
      .find({ kind: "gym_channel", gymId }).sort({ lastMessageAt: -1, createdAt: 1 }).toArray();
    return docs.map((d) => stripId<Conversation>(d) as Conversation);
  }

  public async updateLastMessage(id: string, at: string, preview: string): Promise<void> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations)
      .updateOne({ _id: id }, { $set: { lastMessageAt: at, lastMessagePreview: preview } });
  }

  public async update(id: string, patch: Partial<Conversation>): Promise<Conversation | null> {
    const set: Record<string, unknown> = {};
    const unset: Record<string, ""> = {};
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined) unset[k] = ""; else set[k] = v;
    }
    const ops: Record<string, unknown> = {};
    if (Object.keys(set).length > 0) ops["$set"] = set;
    if (Object.keys(unset).length > 0) ops["$unset"] = unset;
    if (Object.keys(ops).length === 0) return this.findById(id);
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).updateOne({ _id: id }, ops);
    return this.findById(id);
  }

  public async delete(id: string): Promise<void> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).deleteOne({ _id: id });
  }
}
