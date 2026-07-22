import { describe, expect, it } from "bun:test";
import { AccountDeletionOrchestrator } from "../src/services/account-deletion.service.mts";

function trackedRepo(): { deleteByUserId: (id: string) => Promise<void>; calls: string[] } {
  const calls: string[] = [];
  return { calls, deleteByUserId: async (id: string): Promise<void> => { calls.push(id); } };
}

describe("AccountDeletionOrchestrator", () => {
  it("cascades deletion across owned-data repos, Auth0, then removes the user", async () => {
    const checkins = trackedRepo();
    const favorites = trackedRepo();
    const rsvps = trackedRepo();
    const notifications = trackedRepo();
    const order: string[] = [];
    const users = {
      remove: async (id: string): Promise<void> => { order.push(`users:${id}`); },
    };
    const auth0 = {
      deleteUser: async (id: string): Promise<void> => { order.push(`auth0:${id}`); },
    };

    const orchestrator = new AccountDeletionOrchestrator(users, checkins, favorites, rsvps, notifications, auth0);
    await orchestrator.deleteAccount("u-1");

    expect(checkins.calls).toEqual(["u-1"]);
    expect(favorites.calls).toEqual(["u-1"]);
    expect(rsvps.calls).toEqual(["u-1"]);
    expect(notifications.calls).toEqual(["u-1"]);
    // The user record must not be removed until the Auth0 identity delete has
    // succeeded -- otherwise a failed Auth0 call would orphan app data deleted
    // above while leaving a Mongo user pointing at a still-live Auth0 account.
    expect(order).toEqual(["auth0:u-1", "users:u-1"]);
  });

  it("does not remove the user record when Auth0 deletion fails", async () => {
    const checkins = trackedRepo();
    const favorites = trackedRepo();
    const rsvps = trackedRepo();
    const notifications = trackedRepo();
    let userRemoved = false;
    const users = { remove: async (): Promise<void> => { userRemoved = true; } };
    const auth0 = { deleteUser: async (): Promise<void> => { throw new Error("auth0 down"); } };

    const orchestrator = new AccountDeletionOrchestrator(users, checkins, favorites, rsvps, notifications, auth0);
    await expect(orchestrator.deleteAccount("u-2")).rejects.toThrow("auth0 down");
    expect(userRemoved).toBe(false);
  });
});
