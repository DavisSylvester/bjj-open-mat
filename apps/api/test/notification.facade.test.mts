import { describe, expect, it } from "bun:test";
import { NotificationFacade } from "../src/facades/notification.facade.mts";
import type { NotificationRepository } from "../src/repositories/notification.repository.mts";
import type { Notification } from "@bjj/contract";
import type { PushPayload } from "../src/push/push.types.mts";

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
    const facade = new NotificationFacade(r, { pushToUsers: async () => {} }, () => "n-1");
    await facade.create("u-1", "system", "Hi", "Body");
    const before = await facade.list("u-1", true, 0, 20);
    expect(before.total).toBe(1);
    await facade.markAllRead("u-1");
    const after = await facade.list("u-1", true, 0, 20);
    expect(after.total).toBe(0);
  });
});

function harness(): { f: NotificationFacade; pushes: { userIds: string[]; payload: PushPayload }[] } {
  const inserted: Notification[] = [];
  const notifRepo = {
    insert: async (n: Notification): Promise<Notification> => { inserted.push(n); return n; },
    listByUser: async (): Promise<{ items: Notification[]; total: number }> => ({ items: [], total: 0 }),
    markRead: async (): Promise<void> => {},
    markAllRead: async (): Promise<void> => {},
  };
  const pushes: { userIds: string[]; payload: PushPayload }[] = [];
  const push = { pushToUsers: async (userIds: string[], payload: PushPayload): Promise<void> => { pushes.push({ userIds, payload }); } };
  let n = 0;
  return { f: new NotificationFacade(notifRepo, push, () => `id-${n++}`), pushes };
}

describe("NotificationFacade.create push", () => {
  it("pushes to the notified user after persisting", async () => {
    const { f, pushes } = harness();
    await f.create("u9", "forum_answer", "New answer", "Someone answered");
    expect(pushes).toHaveLength(1);
    expect(pushes[0].userIds).toEqual(["u9"]);
    expect(pushes[0].payload.title).toBe("New answer");
    expect(pushes[0].payload.data.type).toBe("forum_answer");
  });
});
