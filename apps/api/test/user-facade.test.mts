import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { NewUser, UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";

type FakeRepo = Pick<UserRepository, "findById" | "insert" | "update" | "upsertByAuth0Id"> & {
  store: Map<string, User>;
};

function fakeRepo(): FakeRepo {
  const store = new Map<string, User>();
  return {
    store,
    findById: async (id: string): Promise<User | null> => store.get(id) ?? null,
    insert: async (u: User): Promise<User> => { store.set(u.id, u); return u; },
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = store.get(id); if (!cur) return null;
      const next = { ...cur, ...patch }; store.set(id, next); return next;
    },
    upsertByAuth0Id: async (auth0Id: string, user: NewUser): Promise<User> => {
      const existing = store.get(auth0Id);
      const next = { ...existing, ...user, id: auth0Id } as User;
      store.set(auth0Id, next);
      return next;
    },
  };
}

describe("UserFacade identity", () => {
  it("does NOT seed displayName from the Auth0 sub on creation", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const u = await f.getOrCreate({ userId: "auth0|6a36dd6a90830c3d8fb430aa", role: "practitioner", email: "", viaBypass: false });
    expect(u.displayName).toBe("");
    expect(u.displayName).not.toContain("auth0");
  });

  it("applies provider name/email on sync for a database (auth0|) user", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const id = { userId: "auth0|6a36dd6a90830c3d8fb430aa", role: "practitioner", email: "", viaBypass: false } as const;
    await f.getOrCreate(id);
    const synced = await f.syncFromProvider(id, { displayName: "Danaher", email: "john@example.com" });
    expect(synced.displayName).toBe("Danaher");
    expect(synced.email).toBe("john@example.com");
  });

  it("does not overwrite an existing user-set name on sync", async () => {
    const repo = fakeRepo();
    const f = new UserFacade(repo);
    const id = { userId: "auth0|abc", role: "practitioner", email: "", viaBypass: false } as const;
    await f.getOrCreate(id);
    await f.updateProfile("auth0|abc", { displayName: "My Name" });
    const synced = await f.syncFromProvider(id, { displayName: "Provider Name" });
    expect(synced.displayName).toBe("My Name");
  });
});
