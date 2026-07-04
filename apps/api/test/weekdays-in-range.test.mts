import { describe, expect, it } from "bun:test";
import { weekdaysInRange } from "../src/repositories/open-mat.repository.mts";

describe("weekdaysInRange", () => {
  it("a single Saturday yields [6]", () => {
    expect(weekdaysInRange("2026-07-04", "2026-07-04")).toEqual([6]); // 2026-07-04 is a Saturday
  });
  it("a weekend yields Sat+Sun", () => {
    expect(new Set(weekdaysInRange("2026-07-04", "2026-07-05"))).toEqual(new Set([6, 0]));
  });
  it("a full month yields all 7 and caps", () => {
    expect(weekdaysInRange("2026-07-01", "2026-07-31").length).toBe(7);
  });
  it("a single Wednesday excludes Saturday", () => {
    expect(weekdaysInRange("2026-07-08", "2026-07-08")).toEqual([3]); // Wed
  });
  it("returns an empty array when endDate is before startDate", () => {
    expect(weekdaysInRange("2026-07-05", "2026-07-04")).toEqual([]);
  });
});
