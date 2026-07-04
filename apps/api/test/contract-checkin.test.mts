import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CheckIn, CheckInLocationStatus, CreateCheckInRequest } from "@bjj/contract";

describe("contract: check-in form", () => {
  it("CheckInLocationStatus accepts the three states", () => {
    for (const s of ["verified", "far", "no_location"]) {
      expect(Value.Check(CheckInLocationStatus, s)).toBe(true);
    }
    expect(Value.Check(CheckInLocationStatus, "nope")).toBe(false);
  });
  it("CheckIn accepts gps + flag + log fields", () => {
    const full = {
      id: "c", openMatId: "o", userId: "u", sessionDate: "2026-06-22", checkedInAt: "t",
      latitude: 32.9, longitude: -117.2, gpsAccuracyM: 8, locationStatus: "verified", distanceM: 120,
      gymId: "g", gymCity: "San Diego", gymState: "CA", note: "n", rounds: 5, intensity: 4, partners: 2,
    };
    expect(Value.Check(CheckIn, full)).toBe(true);
    // rejects out-of-range intensity
    expect(Value.Check(CheckIn, { ...full, intensity: 9 })).toBe(false);
  });
  it("CreateCheckInRequest requires sessionDate and accepts the log fields", () => {
    expect(Value.Check(CreateCheckInRequest, { sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2, gpsAccuracyM: 8, note: "good rounds", rounds: 5, intensity: 4, partners: 3 })).toBe(true);
    expect(Value.Check(CreateCheckInRequest, {})).toBe(false);
    expect(Value.Check(CreateCheckInRequest, { sessionDate: "x", intensity: 9 })).toBe(false);
  });
});
