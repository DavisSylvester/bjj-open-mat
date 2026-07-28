import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ClassType } from "../src/enums/class-type.mts";

describe("ClassType enum", () => {
  it("accepts known types", () => {
    expect(Value.Check(ClassType, "fundamentals")).toBe(true);
    expect(Value.Check(ClassType, "nogi")).toBe(true);
    expect(Value.Check(ClassType, "other")).toBe(true);
  });
  it("rejects unknown types", () => {
    expect(Value.Check(ClassType, "sparring")).toBe(false);
  });
});
