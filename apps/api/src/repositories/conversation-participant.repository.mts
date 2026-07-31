import type { Db } from "mongodb";
import type { ConversationParticipant } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ParticipantDoc extends ConversationParticipant {
  _id: string;
}

export class ConversationParticipantRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants);
    await col.createIndex({ conversationId: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
  }

  public async insertMany(ps: ConversationParticipant[]): Promise<void> {
    if (ps.length === 0) return;
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .insertMany(ps.map((p) => ({ ...p, _id: p.id })));
  }

  public async find(conversationId: string, userId: string): Promise<ConversationParticipant | null> {
    return stripId<ConversationParticipant>(
      await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants).findOne({ conversationId, userId }),
    );
  }

  public async listByConversation(conversationId: string): Promise<ConversationParticipant[]> {
    const docs = await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants).find({ conversationId }).toArray();
    return docs.map((d) => stripId<ConversationParticipant>(d) as ConversationParticipant);
  }

  public async listActiveForUser(userId: string): Promise<ConversationParticipant[]> {
    const docs = await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .find({ userId, leftAt: { $exists: false } }).toArray();
    return docs.map((d) => stripId<ConversationParticipant>(d) as ConversationParticipant);
  }

  public async setLastReadAt(conversationId: string, userId: string, at: string): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { lastReadAt: at } });
  }

  public async setMuted(conversationId: string, userId: string, muted: boolean): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { muted } });
  }

  public async setLeftAt(conversationId: string, userId: string, at: string): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { leftAt: at } });
  }
}
