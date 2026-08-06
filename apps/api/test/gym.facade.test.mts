import { describe, expect, it } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { FavoriteRepository } from "../src/repositories/favorite.repository.mts";
import type { GymRepository } from "../src/repositories/gym.repository.mts";
import type { Gym } from "@bjj/contract";
import { fakeGeocoder, nullGeocoder } from "./fakes/geocoder.fake.mts";
import { NullPlacesClient } from "../src/services/places-client.mts";

type FakeGymRepo = Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "searchNearby" | "ensureIndexes">;
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
    searchNearby: async (): Promise<{ items: Gym[]; total: number }> => ({ items: [...gyms.values()], total: gyms.size }),
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
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-generated", nullGeocoder, new NullPlacesClient());
    const gym = await facade.create("owner-1", { name: "Atos", address: "x" });
    expect(gym.id).toBe("gym-generated");
    expect(gym.ownerId).toBe("owner-1");
  });

  it("update rejects a non-owner", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "g-1", nullGeocoder, new NullPlacesClient());
    await facade.create("owner-1", { name: "Atos", address: "x" });
    await expect(facade.update("someone-else", "g-1", { name: "New" })).rejects.toMatchObject({ code: "forbidden" });
  });

  it("geocodes postalCode into location when no explicit location is provided", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-geo", fakeGeocoder, new NullPlacesClient());
    const gym = await facade.create("owner-1", { name: "Texas BJJ", address: "1 Main St", postalCode: "75495" });
    expect(gym.location).toEqual({ lat: 33.42, lng: -96.58 });
  });

  it("preserves explicit location over geocoded one", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-explicit", fakeGeocoder, new NullPlacesClient());
    const gym = await facade.create("owner-1", {
      name: "Texas BJJ",
      address: "1 Main St",
      postalCode: "75495",
      location: { lat: 10, lng: 20 },
    });
    expect(gym.location).toEqual({ lat: 10, lng: 20 });
  });
});

describe("GymFacade.searchNearby", () => {
  // Minimal stubs. `calls` records every radius the facade tried, in order —
  // that sequence IS the widening behaviour under test.
  function makeFacade(resultsByRadius: Record<number, string[]>): {
    facade: GymFacade;
    calls: number[];
  } {
    const calls: number[] = [];
    const gyms = {
      searchNearby: async (opts: { radiusKm: number; skip: number; limit: number }) => {
        calls.push(opts.radiusKm);
        const ids = resultsByRadius[opts.radiusKm] ?? [];
        return {
          items: ids.slice(opts.skip, opts.skip + opts.limit).map((id) => ({
            id, name: id, address: "a", amenities: [], isVerified: false,
          })),
          total: ids.length,
        };
      },
    };
    const geocoder = { lookupZip: (zip: string) => (zip === "75495" ? { lat: 33.4292, lng: -96.5486 } : null) };
    const facade = new GymFacade(
      gyms as never, {} as never, () => "id", geocoder as never, {} as never,
    );
    return { facade, calls };
  }

  it("resolves a zip to coordinates", async () => {
    const { facade } = makeFacade({ 40: ["g-1"] });
    const r = await facade.searchNearby({ zip: "75495", radiusKm: 40, page: 1, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(["g-1"]);
    expect(r.effectiveRadiusKm).toBe(40);
  });

  it("rejects a request with no origin", async () => {
    const { facade } = makeFacade({});
    await expect(facade.searchNearby({ radiusKm: 40, page: 1, limit: 20 })).rejects.toThrow("lat/lng or zip is required");
  });

  it("rejects an unresolvable zip", async () => {
    const { facade } = makeFacade({});
    await expect(facade.searchNearby({ zip: "00000", radiusKm: 40, page: 1, limit: 20 })).rejects.toThrow("Unknown ZIP code");
  });

  it("prefers explicit coordinates over zip", async () => {
    const { facade } = makeFacade({ 40: ["g-1"] });
    const r = await facade.searchNearby({ lat: 1, lng: 2, zip: "00000", radiusKm: 40, page: 1, limit: 20 });
    expect(r.items).toHaveLength(1);
  });

  it("widens the radius when page 1 is empty", async () => {
    const { facade, calls } = makeFacade({ 80: ["g-1"] });
    const r = await facade.searchNearby({ lat: 33.4292, lng: -96.5486, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40, 80]);
    expect(r.effectiveRadiusKm).toBe(80);
    expect(r.items.map((g) => g.id)).toEqual(["g-1"]);
  });

  it("stops widening at the 161 km cap after two steps", async () => {
    const { facade, calls } = makeFacade({});
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40, 80, 160]);
    expect(r.effectiveRadiusKm).toBe(160);
    expect(r.items).toHaveLength(0);
  });

  it("does not widen when page 1 has results", async () => {
    const { facade, calls } = makeFacade({ 40: ["g-1"], 80: ["g-1", "g-2"] });
    await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40]);
  });

  it("does not widen on page 2", async () => {
    const { facade, calls } = makeFacade({ 80: [] });
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 80, page: 2, limit: 20 });
    expect(calls).toEqual([80]);
    expect(r.effectiveRadiusKm).toBe(80);
  });

  it("derives sponsored from rankBoost", async () => {
    const gyms = {
      searchNearby: async () => ({
        items: [
          { id: "a", name: "a", address: "x", amenities: [], isVerified: false, rankBoost: 5 },
          { id: "b", name: "b", address: "x", amenities: [], isVerified: false },
        ],
        total: 2,
      }),
    };
    const facade = new GymFacade(gyms as never, {} as never, () => "id", {} as never, {} as never);
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(r.items[0]?.sponsored).toBe(true);
    expect(r.items[1]?.sponsored).toBe(false);
  });
});
