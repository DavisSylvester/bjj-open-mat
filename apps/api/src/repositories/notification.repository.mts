import type { Db, Filter } from "mongodb";
import type { Notification } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface NotificationDoc extends Notification {
  _id: string;
}

export class NotificationRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).createIndex({ userId: 1, read: 1, createdAt: -1 });
  }

  public async insert(n: Notification): Promise<Notification> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).insertOne({ ...n, _id: n.id });
    return n;
  }

  public async listByUser(
    userId: string,
    unreadOnly: boolean,
    skip: number,
    limit: number,
  ): Promise<{ items: Notification[]; total: number }> {
    const q: Filter<NotificationDoc> = unreadOnly ? { userId, read: false } : { userId };
    const col = this.collection<NotificationDoc>(COLLECTIONS.notifications);
    const total = await col.countDocuments(q);
    const docs = await col.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => stripId<Notification>(d) as Notification), total };
  }

  public async markRead(id: string, userId: string): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).updateOne({ _id: id, userId }, { $set: { read: true } });
  }

  public async markAllRead(userId: string): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).updateMany({ userId, read: false }, { $set: { read: true } });
  }
}
