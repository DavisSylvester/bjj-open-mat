import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { Gender } from "../src/enums/gender.mts";
import { WeightDivision } from "../src/enums/weight-division.mts";

describe("Gender enum", () => {
  it("accepts male and female", () => {
    expect(Value.Check(Gender, "male")).toBe(true);
    expect(Value.Check(Gender, "female")).toBe(true);
  });
  it("rejects other values", () => {
    expect(Value.Check(Gender, "other")).toBe(false);
  });
});

describe("WeightDivision enum", () => {
  it("accepts feather and ultra_heavy", () => {
    expect(Value.Check(WeightDivision, "feather")).toBe(true);
    expect(Value.Check(WeightDivision, "ultra_heavy")).toBe(true);
  });
  it("rejects unknown division", () => {
    expect(Value.Check(WeightDivision, "cruiserweight")).toBe(false);
  });
});
