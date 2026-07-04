import { describe, expect, it } from "bun:test";
import { haversineMeters } from "../src/facades/check-in.facade.mts";

describe("haversineMeters", () => {
  it("is ~0 for identical points", () => {
    expect(haversineMeters(32.9, -117.2, 32.9, -117.2)).toBeLessThan(1);
  });
  it("matches a known distance within tolerance", () => {
    // San Diego (32.7157,-117.1611) -> Los Angeles (34.0522,-118.2437) ≈ 179 km
    const d = haversineMeters(32.7157, -117.1611, 34.0522, -118.2437);
    expect(d).toBeGreaterThan(170000);
    expect(d).toBeLessThan(190000);
  });
});
