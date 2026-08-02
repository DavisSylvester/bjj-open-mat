import { describe, expect, it } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";

describe("GymFacade.adminUpdate", () => {
  it("updates a gym without an owner-match check", async () => {
    const store: Record<string, { id: string; ownerId?: string; name: string; isVerified: boolean }> = {
      "g-1": { id: "g-1", ownerId: "someone-else", name: "G", isVerified: false },
    };
    const gyms = {
      findById: async (id: string) => store[id] ?? null,
      update: async (id: string, patch: Record<string, unknown>) => { store[id] = { ...store[id], ...patch }; return store[id]; },
    };
    const facade = new GymFacade(gyms as never, {} as never, () => "id", {} as never, {} as never);
    const result = await facade.adminUpdate("g-1", { isVerified: true } as never);
    expect(result.isVerified).toBe(true);        // caller is not the owner, yet it updated
    expect(store["g-1"].ownerId).toBe("someone-else");
  });
});
