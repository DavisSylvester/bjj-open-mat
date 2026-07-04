import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { OpenMatListQuery, NewGymInput } from "@bjj/contract";

describe("contract: search query", () => {
  it("OpenMatListQuery accepts the new search/filter fields", () => {
    const ok = Value.Check(OpenMatListQuery, {
      q: "atos", free: true, startDate: "2026-07-04", endDate: "2026-07-05",
      lat: 33.1, lng: -96.6, radiusKm: 25, zip: "75495",
    });
    expect(ok).toBe(true);
  });

  it("radiusKm is bounded 1..500", () => {
    expect(Value.Check(OpenMatListQuery, { radiusKm: 0 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { radiusKm: 600 })).toBe(false);
  });

  it("NewGymInput accepts optional coordinates", () => {
    expect(Value.Check(NewGymInput, { name: "G", address: "1 A St", latitude: 33.1, longitude: -96.6, postalCode: "75495" })).toBe(true);
  });

  it("lat/lng are bounded to valid coordinate ranges", () => {
    expect(Value.Check(OpenMatListQuery, { lat: 91 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { lat: -91 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { lng: 181 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { lng: -181 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { lat: 33.1, lng: -96.6 })).toBe(true);
    expect(Value.Check(NewGymInput, { name: "G", address: "1 A St", latitude: 91 })).toBe(false);
  });
});
