import type { Notification, NotificationType } from "@bjj/contract";
import type { NotificationRepository } from "../repositories/notification.repository.mts";
import type { PushNotifier } from "../push/push.types.mts";

type IdFactory = () => string;

export class NotificationFacade {

  public constructor(
    private readonly notifications: Pick<NotificationRepository, "insert" | "listByUser" | "markRead" | "markAllRead">,
    private readonly push: PushNotifier,
    private readonly newId: IdFactory,
  ) {}

  public async create(userId: string, type: NotificationType, title: string, body: string): Promise<Notification> {
    const n = await this.notifications.insert({
      id: this.newId(),
      userId,
      type,
      title,
      body,
      read: false,
      createdAt: new Date().toISOString(),
    });
    await this.push.pushToUsers([userId], { title, body, data: { type } });
    return n;
  }

  public async list(userId: string, unread: boolean, skip: number, limit: number): Promise<{ items: Notification[]; total: number }> {
    return this.notifications.listByUser(userId, unread, skip, limit);
  }

  public async markRead(id: string, userId: string): Promise<void> {
    await this.notifications.markRead(id, userId);
  }

  public async markAllRead(userId: string): Promise<void> {
    await this.notifications.markAllRead(userId);
  }
}
