import { describe, expect, it } from "bun:test";
import { ZipcodesGeocoder } from "../src/services/geocoder.mts";

describe("ZipcodesGeocoder.reverse", () => {
  const geo = new ZipcodesGeocoder();

  it("resolves Austin, TX coordinates to state TX", () => {
    const r = geo.reverse(30.2672, -97.7431);
    expect(r).not.toBeNull();
    expect(r!.state).toBe("TX");
    expect(r!.city.length).toBeGreaterThan(0);
  });

  it("returns a value for valid coordinates", () => {
    const r = geo.reverse(34.0522, -118.2437); // Los Angeles
    expect(r!.state).toBe("CA");
  });
});
