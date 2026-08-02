import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  AdminOverviewStats,
  AdminOpenMatsByState,
  AddGymOwnerRequest,
  GymMemberInviteRequest,
  Gym,
} from "../src/index.mts";

describe("admin contract schemas", () => {
  it("AdminOverviewStats accepts all six signup windows + totals", () => {
    const v = {
      signups: { today: 1, last3Days: 2, last7Days: 3, last14Days: 4, monthToDate: 5, yearToDate: 6 },
      totalUsers: 10, totalGyms: 4, totalOpenMats: 7,
    };
    expect(Value.Check(AdminOverviewStats, v)).toBe(true);
  });

  it("AdminOpenMatsByState holds total + a top-states array", () => {
    const v = { totalOpenMats: 12, topStates: [{ state: "TX", count: 5 }, { state: "CA", count: 3 }] };
    expect(Value.Check(AdminOpenMatsByState, v)).toBe(true);
  });

  it("AddGymOwnerRequest requires a userId", () => {
    expect(Value.Check(AddGymOwnerRequest, { userId: "u-1" })).toBe(true);
    expect(Value.Check(AddGymOwnerRequest, {})).toBe(false);
  });

  it("GymMemberInviteRequest requires at least one email", () => {
    expect(Value.Check(GymMemberInviteRequest, { emails: ["a@b.dev"] })).toBe(true);
    expect(Value.Check(GymMemberInviteRequest, { emails: [] })).toBe(false);
  });

  it("Gym allows optional verifiedAt", () => {
    const base = { id: "g1", name: "G", address: "A", amenities: [], isVerified: true, verifiedAt: "2026-08-01T00:00:00.000Z" };
    expect(Value.Check(Gym, base)).toBe(true);
  });
});
