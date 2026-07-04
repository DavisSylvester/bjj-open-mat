import { describe, expect, it } from "bun:test";
import { NotificationFacade } from "../src/facades/notification.facade.mts";
import type { NotificationRepository } from "../src/repositories/notification.repository.mts";
import type { Notification } from "@bjj/contract";

type FakeNotificationRepo = Pick<NotificationRepository, "insert" | "listByUser" | "markRead" | "markAllRead" | "ensureIndexes">;

function repo(): FakeNotificationRepo {
  const map = new Map<string, Notification>();
  return {
    insert: async (n: Notification): Promise<Notification> => { map.set(n.id, n); return n; },
    listByUser: async (userId: string, unread: boolean): Promise<{ items: Notification[]; total: number }> => {
      const items = [...map.values()].filter((n) => n.userId === userId && (!unread || !n.read));
      return { items, total: items.length };
    },
    markRead: async (id: string): Promise<void> => { const n = map.get(id); if (n) map.set(id, { ...n, read: true }); },
    markAllRead: async (userId: string): Promise<void> => { for (const [k, n] of map) if (n.userId === userId) map.set(k, { ...n, read: true }); },
    ensureIndexes: async (): Promise<void> => {},
  };
}

describe("NotificationFacade", () => {
  it("lists then marks all read", async () => {
    const r = repo();
    const facade = new NotificationFacade(r, () => "n-1");
    await facade.create("u-1", "system", "Hi", "Body");
    const before = await facade.list("u-1", true, 0, 20);
    expect(before.total).toBe(1);
    await facade.markAllRead("u-1");
    const after = await facade.list("u-1", true, 0, 20);
    expect(after.total).toBe(0);
  });
});
