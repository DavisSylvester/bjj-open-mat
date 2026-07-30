import { describe, expect, test } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { PlacesClient } from "../src/services/places-client.mts";

interface StubGym {
  readonly id: string;
  readonly googlePlaceId?: string;
  readonly googleReviewUri?: string;
}

function makeFacade(
  gym: StubGym | null,
  places: PlacesClient,
): { facade: GymFacade; updates: Record<string, unknown>[] } {
  const updates: Record<string, unknown>[] = [];
  const gyms = {
    findById: async (): Promise<StubGym | null> => gym,
    update: async (_id: string, patch: Record<string, unknown>): Promise<StubGym | null> => {
      updates.push(patch);
      return gym;
    },
    insert: async (): Promise<never> => { throw new Error("unused"); },
    list: async (): Promise<never> => { throw new Error("unused"); },
    listByOwner: async (): Promise<never> => { throw new Error("unused"); },
    findNearby: async (): Promise<never> => { throw new Error("unused"); },
  };
  const favorites = {
    add: async (): Promise<void> => {},
    remove: async (): Promise<void> => {},
    listGymIds: async (): Promise<string[]> => [],
  };
  const geocoder = { lookupZip: (): null => null };

  const facade = new GymFacade(gyms, favorites, (): string => "id", geocoder, places);
  return { facade, updates };
}

describe("GymFacade.reviewLink", () => {
  test("returns the cached uri without calling Places", async () => {
    let called = false;
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        called = true;
        return "https://should-not-be-used";
      },
    };
    const { facade } = makeFacade(
      { id: "g1", googlePlaceId: "p1", googleReviewUri: "https://cached" },
      places,
    );

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: "https://cached" });
    expect(called).toBe(false);
  });

  test("fetches and persists on cache miss", async () => {
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => "https://fetched",
    };
    const { facade, updates } = makeFacade({ id: "g1", googlePlaceId: "p1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: "https://fetched" });
    expect(updates).toEqual([{ googleReviewUri: "https://fetched" }]);
  });

  test("returns null when the gym has no place id", async () => {
    let called = false;
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        called = true;
        return "x";
      },
    };
    const { facade } = makeFacade({ id: "g1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: null });
    expect(called).toBe(false);
  });

  test("returns null rather than throwing when Places fails", async () => {
    const places: PlacesClient = {
      writeAReviewUri: async (): Promise<string | null> => {
        throw new Error("places down");
      },
    };
    const { facade } = makeFacade({ id: "g1", googlePlaceId: "p1" }, places);

    expect(await facade.reviewLink("g1")).toEqual({ writeAReviewUri: null });
  });
});
