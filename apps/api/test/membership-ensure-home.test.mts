import { describe, expect, test } from "bun:test";
import type { GymMembership } from "@bjj/contract";
import { MembershipFacade } from "../src/facades/membership.facade.mts";
import { AppError } from "../src/http/errors.mts";

interface Calls {
  readonly upserts: GymMembership[];
  readonly setHomes: { userId: string; gymId: string }[];
}

function makeFacade(opts: { existing?: GymMembership | null; gymExists?: boolean }): {
  facade: MembershipFacade;
  calls: Calls;
} {
  const calls: Calls = { upserts: [], setHomes: [] };
  const memberships = {
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      calls.upserts.push(m);
      return m;
    },
    find: async (): Promise<GymMembership | null> => opts.existing ?? null,
    setHome: async (userId: string, gymId: string): Promise<void> => {
      calls.setHomes.push({ userId, gymId });
    },
    remove: async (): Promise<void> => {},
    listByGym: async (): Promise<GymMembership[]> => [],
    listByUser: async (): Promise<GymMembership[]> => [],
    update: async (): Promise<GymMembership | null> => null,
  };
  const promotions = { insert: async (): Promise<never> => { throw new Error("unused"); }, listByUser: async (): Promise<[]> => [] };
  const gyms = {
    findById: async (): Promise<{ id: string; name: string } | null> =>
      opts.gymExists === false ? null : { id: "g1", name: "Test Gym" },
  };
  const users = { findById: async (): Promise<null> => null, update: async (): Promise<null> => null };

  const facade = new MembershipFacade(
    memberships as unknown as ConstructorParameters<typeof MembershipFacade>[0],
    promotions as unknown as ConstructorParameters<typeof MembershipFacade>[1],
    gyms as unknown as ConstructorParameters<typeof MembershipFacade>[2],
    users as unknown as ConstructorParameters<typeof MembershipFacade>[3],
    (): string => "generated-id",
  );
  return { facade, calls };
}

function membership(overrides: Partial<GymMembership> = {}): GymMembership {
  return {
    id: "m1",
    gymId: "g1",
    userId: "u1",
    status: "active",
    verifiedMember: false,
    gymRole: "member",
    isHome: false,
    visibleInRoster: true,
    joinMethod: "self",
    joinedAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("MembershipFacade.ensureHome", () => {
  test("joins then marks home when no membership exists", async () => {
    const { facade, calls } = makeFacade({ existing: null });
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(1);
    expect(calls.upserts[0]?.userId).toBe("u1");
    expect(calls.upserts[0]?.gymId).toBe("g1");
    expect(calls.setHomes).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("marks home without a second join when already a member", async () => {
    const { facade, calls } = makeFacade({ existing: membership() });
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("propagates not_found for an unknown gym and writes nothing", async () => {
    const { facade, calls } = makeFacade({ existing: null, gymExists: false });
    await expect(facade.ensureHome("u1", "missing")).rejects.toThrow(AppError);
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toHaveLength(0);
  });

  test("is idempotent across repeated calls", async () => {
    const { facade, calls } = makeFacade({ existing: membership({ isHome: true }) });
    await facade.ensureHome("u1", "g1");
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toHaveLength(2);
  });
});
