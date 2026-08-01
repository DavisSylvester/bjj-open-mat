// apps/api/test/admin-facade.test.mts
import { describe, expect, it } from "bun:test";
import { AdminFacade } from "../src/facades/admin.facade.mts";

const NOW = new Date("2026-08-01T00:00:00.000Z");

function makeFacade(overrides: Partial<Record<string, unknown>> = {}) {
  const gymStore: Record<string, unknown> = { "g-1": { id: "g-1", name: "G", address: "A", amenities: [], isVerified: false } };
  const userRoles: Record<string, string> = {};
  const sent: string[] = [];
  const analytics = {
    signupWindows: async () => ({ today: 1, last3Days: 1, last7Days: 1, last14Days: 1, monthToDate: 1, yearToDate: 1 }),
    totals: async () => ({ totalUsers: 3, totalGyms: 1, totalOpenMats: 2 }),
    topStates: async () => [{ state: "TX", count: 2 }],
  };
  const userRepo = {
    list: async () => ({ items: [{ id: "u-1", email: "a@b.dev", displayName: "A" }], total: 1 }),
    update: async (id: string, patch: Record<string, unknown>) => { userRoles[id] = patch["role"] as string; return { id, ...patch }; },
  };
  const gymFacade = {
    getById: async (id: string) => gymStore[id],
    adminUpdate: async (id: string, patch: Record<string, unknown>) => { gymStore[id] = { ...(gymStore[id] as object), ...patch }; return gymStore[id]; },
  };
  const email = { sendGymMemberInvite: async (to: string) => { sent.push(to); } };
  const facade = new AdminFacade(analytics as never, userRepo as never, gymFacade as never, {} as never, {} as never, email as never);
  void overrides;
  return { facade, gymStore, userRoles, sent };
}

describe("AdminFacade", () => {
  it("overview merges signup windows + totals", async () => {
    const { facade } = makeFacade();
    const o = await facade.overview(NOW);
    expect(o.totalUsers).toBe(3);
    expect(o.signups.today).toBe(1);
  });

  it("verifyGym sets isVerified + verifiedAt", async () => {
    const { facade, gymStore } = makeFacade();
    await facade.verifyGym("g-1", NOW);
    expect((gymStore["g-1"] as Record<string, unknown>)["isVerified"]).toBe(true);
    expect((gymStore["g-1"] as Record<string, unknown>)["verifiedAt"]).toBe(NOW.toISOString());
  });

  it("addOwner sets ownerId and promotes user role", async () => {
    const { facade, gymStore, userRoles } = makeFacade();
    await facade.addOwner("g-1", "u-9");
    expect((gymStore["g-1"] as Record<string, unknown>)["ownerId"]).toBe("u-9");
    expect(userRoles["u-9"]).toBe("gym_owner");
  });

  it("invite sends one email per address", async () => {
    const { facade, sent } = makeFacade();
    const r = await facade.invite("g-1", ["x@y.dev", "z@y.dev"]);
    expect(r.invited).toBe(2);
    expect(sent).toEqual(["x@y.dev", "z@y.dev"]);
  });
});
