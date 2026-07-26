import { describe, expect, it } from "bun:test";
import { isUsState, isUsZip, isUsCandidate } from "../lib/us-filter.mjs";

describe("us-filter", () => {
  it("accepts valid 2-letter US states (any case)", () => {
    expect(isUsState("TX")).toBe(true);
    expect(isUsState("ca")).toBe(true);
    expect(isUsState("DC")).toBe(true);
  });
  it("rejects non-US / invalid states", () => {
    expect(isUsState("ON")).toBe(false); // Ontario
    expect(isUsState("XX")).toBe(false);
    expect(isUsState("")).toBe(false);
  });
  it("accepts 5-digit zips and rejects others", () => {
    expect(isUsZip("75495")).toBe(true);
    expect(isUsZip("7549")).toBe(false);
    expect(isUsZip("K1A0B1")).toBe(false);
  });
  it("treats a candidate as US when it has a US state or US zip", () => {
    expect(isUsCandidate({ state: "TX" })).toBe(true);
    expect(isUsCandidate({ postalCode: "75495" })).toBe(true);
    expect(isUsCandidate({ state: "ON" })).toBe(false);
    expect(isUsCandidate({})).toBe(false);
  });
});
