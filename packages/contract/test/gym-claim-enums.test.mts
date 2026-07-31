import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  GymClaimStatus,
  GymClaimKind,
  ClaimantRelationship,
  NotificationType,
} from "../src/index.mts";

describe("gym claim enums", () => {
  it("accepts valid status values and rejects others", () => {
    expect(Value.Check(GymClaimStatus, "pending")).toBe(true);
    expect(Value.Check(GymClaimStatus, "approved")).toBe(true);
    expect(Value.Check(GymClaimStatus, "rejected")).toBe(true);
    expect(Value.Check(GymClaimStatus, "cancelled")).toBe(true);
    expect(Value.Check(GymClaimStatus, "bogus")).toBe(false);
  });

  it("accepts valid kinds", () => {
    expect(Value.Check(GymClaimKind, "claim")).toBe(true);
    expect(Value.Check(GymClaimKind, "transfer")).toBe(true);
    expect(Value.Check(GymClaimKind, "steal")).toBe(false);
  });

  it("accepts valid relationships", () => {
    expect(Value.Check(ClaimantRelationship, "owner")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "head_coach")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "manager")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "janitor")).toBe(false);
  });

  it("notification type now includes gym_claim", () => {
    expect(Value.Check(NotificationType, "gym_claim")).toBe(true);
  });
});
