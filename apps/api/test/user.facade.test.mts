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
});
