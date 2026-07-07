import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";

type FakeUserRepo = Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert" | "ensureIndexes">;

function fakeRepo(seed: User[]): FakeUserRepo {
  const users = new Map(seed.map((u) => [u.id, u]));
  return {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    upsertByAuth0Id: async (_a: string, u: { id: string; email: string; displayName: string; role: User["role"] }): Promise<User> => {
      const created: User = { ...u };
      users.set(created.id, created);
      return created;
    },
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      users.set(id, next);
      return next;
    },
    insert: async (u: User): Promise<User> => { users.set(u.id, u); return u; },
    ensureIndexes: async (): Promise<void> => {},
  };
}

describe("UserFacade", () => {
  it("getOrCreate returns existing user", async () => {
    const repo = fakeRepo([{ id: "u-1", email: "a@b.dev", displayName: "A", role: "practitioner" }]);
    const facade = new UserFacade(repo);
    const u = await facade.getOrCreate({ userId: "u-1", role: "practitioner", email: "a@b.dev", viaBypass: true });
    expect(u.id).toBe("u-1");
  });

  it("updateProfile applies a patch", async () => {
    const repo = fakeRepo([{ id: "u-1", email: "a@b.dev", displayName: "A", role: "practitioner" }]);
    const facade = new UserFacade(repo);
    const u = await facade.updateProfile("u-1", { displayName: "B" });
    expect(u.displayName).toBe("B");
  });

  it("getOrCreate synthesizes a valid email when the token carries none", async () => {
    const repo = fakeRepo([]);
    const facade = new UserFacade(repo);
    // Social access tokens don't include the `email` claim, so identity.email is "".
    const u = await facade.getOrCreate({ userId: "google-oauth2|123", role: "practitioner", email: "", viaBypass: false });
    expect(u.email).not.toBe("");
    expect(u.email).toContain("@");
  });

  it("getOrCreate does not collide on the unique email index for two email-less users", async () => {
    // Reproduces the production 500: a unique index on `email` rejects a second
    // user inserted with the same empty email (E11000 duplicate key).
    const emails = new Set<string>();
    const uniqueEmailRepo: FakeUserRepo = {
      ...fakeRepo([]),
      insert: async (u: User): Promise<User> => {
        if (emails.has(u.email)) throw new Error("E11000 duplicate key error: email");
        emails.add(u.email);
        return u;
      },
      findById: async (): Promise<User | null> => null,
    };
    const facade = new UserFacade(uniqueEmailRepo);
    const a = await facade.getOrCreate({ userId: "google-oauth2|111", role: "practitioner", email: "", viaBypass: false });
    const b = await facade.getOrCreate({ userId: "google-oauth2|222", role: "practitioner", email: "", viaBypass: false });
    expect(a.email).not.toBe(b.email);
  });
});
