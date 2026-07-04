import { describe, expect, it } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { FavoriteRepository } from "../src/repositories/favorite.repository.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { Gym } from "@bjj/contract";
import { fakeGeocoder, nullGeocoder } from "./fakes/geocoder.fake.mts";

type FakeGymRepo = Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "findNearby" | "ensureIndexes">;
type FakeFavRepo = Pick<FavoriteRepository, "add" | "remove" | "listGymIds" | "ensureIndexes">;

function repos(): { gymRepo: FakeGymRepo; favRepo: FakeFavRepo } {
  const gyms = new Map<string, Gym>();
  const favs: Array<{ userId: string; gymId: string }> = [];
  const gymRepo = {
    insert: async (g: Gym): Promise<Gym> => { gyms.set(g.id, g); return g; },
    findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null,
    update: async (id: string, patch: Partial<Gym>): Promise<Gym | null> => {
      const cur = gyms.get(id); if (!cur) return null;
      const next = { ...cur, ...patch }; gyms.set(id, next); return next;
    },
    list: async (): Promise<{ items: Gym[]; total: number }> => ({ items: [...gyms.values()], total: gyms.size }),
    listByOwner: async (ownerId: string): Promise<{ items: Gym[]; total: number }> => {
      const items = [...gyms.values()].filter((g) => g.ownerId === ownerId);
      return { items, total: items.length };
    },
    findNearby: async (): Promise<Gym[]> => [...gyms.values()],
    ensureIndexes: async (): Promise<void> => {},
  };
  const favRepo = {
    add: async (userId: string, gymId: string): Promise<void> => { favs.push({ userId, gymId }); },
    remove: async (userId: string, gymId: string): Promise<void> => {
      const i = favs.findIndex((f) => f.userId === userId && f.gymId === gymId);
      if (i >= 0) favs.splice(i, 1);
    },
    listGymIds: async (userId: string): Promise<string[]> => favs.filter((f) => f.userId === userId).map((f) => f.gymId),
    ensureIndexes: async (): Promise<void> => {},
  };
  return { gymRepo, favRepo };
}

describe("GymFacade", () => {
  it("create assigns ownerId and an id", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-generated", nullGeocoder);
    const gym = await facade.create("owner-1", { name: "Atos", address: "x" });
    expect(gym.id).toBe("gym-generated");
    expect(gym.ownerId).toBe("owner-1");
  });

  it("update rejects a non-owner", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "g-1", nullGeocoder);
    await facade.create("owner-1", { name: "Atos", address: "x" });
    await expect(facade.update("someone-else", "g-1", { name: "New" })).rejects.toMatchObject({ code: "forbidden" });
  });

  it("geocodes postalCode into location when no explicit location is provided", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-geo", fakeGeocoder);
    const gym = await facade.create("owner-1", { name: "Texas BJJ", address: "1 Main St", postalCode: "75495" });
    expect(gym.location).toEqual({ lat: 33.42, lng: -96.58 });
  });

  it("preserves explicit location over geocoded one", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-explicit", fakeGeocoder);
    const gym = await facade.create("owner-1", {
      name: "Texas BJJ",
      address: "1 Main St",
      postalCode: "75495",
      location: { lat: 10, lng: 20 },
    });
    expect(gym.location).toEqual({ lat: 10, lng: 20 });
  });
});
