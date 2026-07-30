import { describe, expect, test } from "bun:test";
import { fromDoc, type GymDoc } from "../src/repositories/gym.repository.mts";

/**
 * The gyms collection stores the identifier as Mongo's `_id`. Only a handful of
 * documents (those inserted through the API) also carry a redundant `id` field,
 * so a mapper that relies on `id` surviving the spread loses the identifier for
 * every scraper-created gym — 842 of 847 in production.
 */
function doc(overrides: Partial<GymDoc> = {}): GymDoc {
  return {
    _id: "gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE",
    name: "RM Elite Brazilian Jiu Jitsu",
    address: "203 Bear Rd Bldg 11",
    amenities: [],
    isVerified: false,
    ...overrides,
  } as GymDoc;
}

describe("fromDoc", () => {
  test("maps _id to id", () => {
    const gym = fromDoc(doc());
    expect(gym?.id).toBe("gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE");
  });

  test("maps _id even when the document has no redundant id field", () => {
    const d = doc();
    expect("id" in d).toBe(false);
    expect(fromDoc(d)?.id).toBe("gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE");
  });

  test("_id wins over a stale redundant id field", () => {
    const gym = fromDoc(doc({ id: "stale-value" } as Partial<GymDoc>));
    expect(gym?.id).toBe("gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE");
  });

  test("never leaks _id into the API shape", () => {
    const gym = fromDoc(doc());
    expect(gym).not.toHaveProperty("_id");
  });

  test("preserves googlePlaceId alongside the mapped id", () => {
    const gym = fromDoc(doc({ googlePlaceId: "ChIJQ6RbfKRlTIYRqwLvhXoHGEE" }));
    expect(gym?.id).toBe("gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE");
    expect(gym?.googlePlaceId).toBe("ChIJQ6RbfKRlTIYRqwLvhXoHGEE");
  });

  test("still maps geo to location", () => {
    const gym = fromDoc(doc({ geo: { type: "Point", coordinates: [-96.6059241, 33.4455918] } }));
    expect(gym?.location).toEqual({ lng: -96.6059241, lat: 33.4455918 });
  });

  test("converts distanceMeters to distanceKm", () => {
    const gym = fromDoc({ ...doc(), distanceMeters: 2500 });
    expect(gym?.distanceKm).toBe(2.5);
  });

  test("returns null for a null document", () => {
    expect(fromDoc(null)).toBeNull();
  });
});
