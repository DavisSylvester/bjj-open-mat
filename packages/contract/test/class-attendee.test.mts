import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ClassAttendee } from "../src/index.mjs";

describe("ClassAttendee schema", () => {
  it("accepts a valid attendee without optional fields", () => {
    expect(Value.Check(ClassAttendee, {
      userId: "u1",
      name: "A",
      isMember: true,
      hasProfile: true,
    })).toBe(true);
  });

  it("accepts a valid attendee with all optional fields", () => {
    expect(Value.Check(ClassAttendee, {
      userId: "u2",
      name: "Bob",
      isMember: false,
      beltRank: "blue",
      avatarUrl: "https://example.com/avatar.png",
      hasProfile: true,
    })).toBe(true);
  });

  it("rejects an object missing required fields", () => {
    expect(Value.Check(ClassAttendee, { userId: "u1" })).toBe(false);
  });

  it("rejects an invalid beltRank", () => {
    expect(Value.Check(ClassAttendee, {
      userId: "u3",
      name: "C",
      isMember: false,
      beltRank: "rainbow",
      hasProfile: true,
    })).toBe(false);
  });
});
