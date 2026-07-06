import { describe, expect, it } from "bun:test";
import type { User } from "@bjj/contract";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";

type FakeUserRepo = Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert">;

function fakeRepo(seed: User[]): FakeUserRepo {
  const users = new Map(seed.map((u) => [u.id, u]));
  return {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    upsertByAuth0Id: async (
      _a: string,
      u: { id: string; email: string; displayName: string; role: User["role"] },
    ): Promise<User> => {
      const created: User = { ...u };
      users.set(created.id, created);
      return created;
    },
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id);
      if (!cur) return null;
      const next: User = { ...cur, ...patch };
      users.set(id, next);
      return next;
    },
    insert: async (u: User): Promise<User> => {
      users.set(u.id, u);
      return u;
    },
  };
}

describe("UserFacade preferences", () => {
  it("persists search preferences through update and read-back", async () => {
    const repo = fakeRepo([{ id: "u-1", email: "a@b.dev", displayName: "A", role: "practitioner" }]);
    const facade = new UserFacade(repo);

    const updated = await facade.updateProfile("u-1", {
      preferences: { defaultWhen: "this_week", defaultWithinMi: 25 },
    });
    expect(updated.preferences?.defaultWhen).toBe("this_week");
    expect(updated.preferences?.defaultWithinMi).toBe(25);

    const readBack = await facade.getById("u-1");
    expect(readBack.preferences?.defaultWhen).toBe("this_week");
    expect(readBack.preferences?.defaultWithinMi).toBe(25);
  });
});
