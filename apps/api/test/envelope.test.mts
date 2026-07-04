import { describe, expect, it } from "bun:test";
import { data, list } from "../src/http/envelope.mts";

describe("envelope", () => {
  it("wraps a single item under data", () => {
    expect(data({ id: "x" })).toEqual({ data: { id: "x" } });
  });

  it("wraps a list with meta", () => {
    expect(list([{ id: "x" }], { page: 1, limit: 20, total: 1 })).toEqual({
      data: [{ id: "x" }],
      meta: { page: 1, limit: 20, total: 1 },
    });
  });
});
