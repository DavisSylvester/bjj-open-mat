import { describe, expect, it } from "bun:test";
import { IBJJF_WEIGHT_CLASSES, divisionsFor } from "../src/reference/ibjjf-weight-classes.mts";

describe("IBJJF weight classes", () => {
  it("male gi feather upper limit is 70 kg", () => {
    const row = IBJJF_WEIGHT_CLASSES.male.gi.find((r) => r.division === "feather");
    expect(row?.maxKg).toBe(70);
  });

  it("female nogi rooster upper limit is 46.5 kg", () => {
    const row = IBJJF_WEIGHT_CLASSES.female.nogi.find((r) => r.division === "rooster");
    expect(row?.maxKg).toBe(46.5);
  });

  it("ultra_heavy has no upper limit (null)", () => {
    const row = IBJJF_WEIGHT_CLASSES.male.gi.find((r) => r.division === "ultra_heavy");
    expect(row?.maxKg).toBeNull();
  });

  it("divisionsFor(female, gi) excludes ultra_heavy (7 divisions, super_heavy is open)", () => {
    const list = divisionsFor("female", "gi");
    expect(list.map((r) => r.division)).not.toContain("ultra_heavy");
    expect(list.length).toBe(7);
  });
});
