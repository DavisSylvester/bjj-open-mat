import { describe, expect, it } from "bun:test";
import type { UpdateUserRequest, User } from "@bjj/contract";
import { UserFacade } from "../src/facades/user.facade.mts";

function stubUsers(stored: User) {
  let lastPatch: Partial<User> | null = null;
  const repo = {
    findById: async (_id: string): Promise<User | null> => ({ ...stored, ...lastPatch }),
    upsertByAuth0Id: async (): Promise<User> => stored,
    insert: async (u: User): Promise<User> => u,
    update: async (_id: string, patch: Partial<User>): Promise<User | null> => {
      lastPatch = patch;
      return { ...stored, ...patch };
    },
  };
  return { repo, getPatch: (): Partial<User> | null => lastPatch };
}

describe("UserFacade.updateProfile", () => {
  it("forwards city/state/gender/weight fields to the repository", async () => {
    const base: User = { id: "u1", email: "a@b.co", displayName: "A" };
    const { repo, getPatch } = stubUsers(base);
    const facade = new UserFacade(repo);
    const patch: UpdateUserRequest = {
      city: "Austin",
      state: "TX",
      gender: "male",
      weightValue: 172,
      weightUnit: "lb",
      weightDivision: "light",
      weightDivisionContext: "nogi",
    };
    const result = await facade.updateProfile("u1", patch);
    expect(getPatch()).toMatchObject(patch);
    expect(result.city).toBe("Austin");
    expect(result.weightDivision).toBe("light");
  });
});
