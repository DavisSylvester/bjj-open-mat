import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { UpdateUserRequest } from "../src/schemas/requests/user-requests.mts";

describe("UpdateUserRequest new fields", () => {
  it("accepts city, state, gender, weightValue, weightUnit, weightDivision, weightDivisionContext", () => {
    const patch = {
      city: "Austin",
      state: "TX",
      gender: "male",
      weightValue: 172,
      weightUnit: "lb",
      weightDivision: "light",
      weightDivisionContext: "nogi",
    };
    expect(Value.Check(UpdateUserRequest, patch)).toBe(true);
  });

  it("rejects an invalid weightUnit", () => {
    expect(Value.Check(UpdateUserRequest, { weightUnit: "stone" })).toBe(false);
  });
});
