import { describe, expect, test } from "bun:test";
import type { User } from "@bjj/contract";
import { UserFacade } from "../src/facades/user.facade.mts";
import { AppError } from "../src/http/errors.mts";

function makeFacade(opts: { current?: string | null; ensureHomeThrows?: boolean }): {
  facade: UserFacade;
  ensureHomeCalls: { userId: string; gymId: string }[];
  updates: Record<string, unknown>[];
} {
  const ensureHomeCalls: { userId: string; gymId: string }[] = [];
  const updates: Record<string, unknown>[] = [];

  const users = {
    findById: async (): Promise<User> =>
      ({ id: "u1", email: "u@x.test", homeGymId: opts.current ?? undefined }) as User,
    update: async (_id: string, patch: Record<string, unknown>): Promise<User> => {
      updates.push(patch);
      return { id: "u1", email: "u@x.test", ...patch } as User;
    },
    upsertByAuth0Id: async (): Promise<never> => { throw new Error("unused"); },
    insert: async (): Promise<never> => { throw new Error("unused"); },
  };

  const memberships = {
    ensureHome: async (userId: string, gymId: string): Promise<void> => {
      if (opts.ensureHomeThrows === true) throw new AppError("not_found", `Gym ${gymId} not found`);
      ensureHomeCalls.push({ userId, gymId });
    },
  };

  const facade = new UserFacade(
    users as unknown as ConstructorParameters<typeof UserFacade>[0],
    memberships,
  );
  return { facade, ensureHomeCalls, updates };
}

describe("UserFacade.updateProfile home gym sync", () => {
  test("joins the gym when homeGymId changes", async () => {
    const { facade, ensureHomeCalls } = makeFacade({ current: null });
    await facade.updateProfile("u1", { homeGymId: "g1" });
    expect(ensureHomeCalls).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("does nothing extra when homeGymId is unchanged", async () => {
    const { facade, ensureHomeCalls } = makeFacade({ current: "g1" });
    await facade.updateProfile("u1", { homeGymId: "g1" });
    expect(ensureHomeCalls).toHaveLength(0);
  });

  test("does nothing extra when the patch omits homeGymId", async () => {
    const { facade, ensureHomeCalls, updates } = makeFacade({ current: "g1" });
    await facade.updateProfile("u1", { bio: "hello" });
    expect(ensureHomeCalls).toHaveLength(0);
    expect(updates[0]).toEqual({ bio: "hello" });
  });

  test("rejects the whole update when the gym does not exist", async () => {
    const { facade, updates } = makeFacade({ current: null, ensureHomeThrows: true });
    await expect(facade.updateProfile("u1", { homeGymId: "missing" })).rejects.toThrow(AppError);
    expect(updates).toHaveLength(0);
  });
});
