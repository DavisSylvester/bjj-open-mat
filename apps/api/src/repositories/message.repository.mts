import type { Db } from "mongodb";
import type { Message } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface MessageDoc extends Message {
  _id: string;
}

export class MessageRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).createIndex({ conversationId: 1, createdAt: -1 });
  }

  public async insert(m: Message): Promise<Message> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).insertOne({ ...m, _id: m.id });
    return m;
  }

  public async findById(id: string): Promise<Message | null> {
    return stripId<Message>(await this.collection<MessageDoc>(COLLECTIONS.messages).findOne({ _id: id }));
  }

  public async listByConversation(conversationId: string, before: string | undefined, limit: number): Promise<Message[]> {
    const filter: Record<string, unknown> = { conversationId };
    if (before !== undefined) filter["createdAt"] = { $lt: before };
    const docs = await this.collection<MessageDoc>(COLLECTIONS.messages)
      .find(filter).sort({ createdAt: -1 }).limit(limit).toArray();
    return docs.map((d) => stripId<Message>(d) as Message);
  }

  public async latestForConversation(conversationId: string): Promise<Message | null> {
    const docs = await this.collection<MessageDoc>(COLLECTIONS.messages)
      .find({ conversationId }).sort({ createdAt: -1 }).limit(1).toArray();
    return docs.length > 0 ? (stripId<Message>(docs[0]) as Message) : null;
  }

  public async countAfter(conversationId: string, afterIso: string | undefined): Promise<number> {
    const filter: Record<string, unknown> = { conversationId, deletedAt: { $exists: false } };
    if (afterIso !== undefined) filter["createdAt"] = { $gt: afterIso };
    return this.collection<MessageDoc>(COLLECTIONS.messages).countDocuments(filter);
  }

  public async softDelete(id: string, at: string): Promise<void> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).updateOne({ _id: id }, { $set: { deletedAt: at, body: "" } });
  }

  public async update(id: string, patch: Partial<Message>): Promise<Message | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<MessageDoc>(COLLECTIONS.messages).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
