import { describe, expect, it } from "bun:test";
import { escapeRegex } from "../src/repositories/open-mat.repository.mts";

describe("escapeRegex", () => {
  it("escapes regex metacharacters so text matches literally", () => {
    expect(escapeRegex("10th Planet (Rosemead)")).toBe("10th Planet \\(Rosemead\\)");
    expect(escapeRegex("a+b*c")).toBe("a\\+b\\*c");
    expect(escapeRegex("plain")).toBe("plain");
  });
});
