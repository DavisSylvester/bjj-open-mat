import { describe, expect, it } from "bun:test";
import { haversineKm, nameOverlap, bestGymMatch } from "../lib/geo-match.mjs";

describe("haversineKm", () => {
  it("computes ~0 for same point and a known distance", () => {
    expect(haversineKm(32.5, -96.9, 32.5, -96.9)).toBeCloseTo(0, 3);
    // ~1.11 km per 0.01 deg latitude
    expect(haversineKm(32.5, -96.9, 32.51, -96.9)).toBeCloseTo(1.11, 1);
  });
});

describe("nameOverlap", () => {
  it("is 1 for identical, and >=0.5 for strong overlap", () => {
    expect(nameOverlap("Atos Jiu Jitsu", "Atos Jiu Jitsu")).toBeCloseTo(1, 3);
    expect(nameOverlap("Atos Jiu Jitsu HQ", "Atos Jiu-Jitsu")).toBeGreaterThanOrEqual(0.5);
    expect(nameOverlap("Gracie Barra", "Zenith BJJ")).toBeLessThan(0.5);
  });
});

describe("bestGymMatch", () => {
  const gyms = [
    { id: "g1", name: "Atos Jiu Jitsu", location: { lat: 32.50, lng: -96.90 } },
    { id: "g2", name: "Gracie Barra Frisco", location: { lat: 33.10, lng: -96.80 } },
  ];
  it("matches on >=50% name overlap within 3km", () => {
    const m = bestGymMatch({ gymName: "Atos Jiu-Jitsu", lat: 32.505, lng: -96.90 }, gyms);
    expect(m?.id).toBe("g1");
  });
  it("returns null when nearest name overlap is too low", () => {
    const m = bestGymMatch({ gymName: "Zenith BJJ", lat: 32.50, lng: -96.90 }, gyms);
    expect(m).toBeNull();
  });
  it("returns null when name matches but distance > 3km", () => {
    const m = bestGymMatch({ gymName: "Atos Jiu Jitsu", lat: 32.60, lng: -96.90 }, gyms);
    expect(m).toBeNull();
  });
});
