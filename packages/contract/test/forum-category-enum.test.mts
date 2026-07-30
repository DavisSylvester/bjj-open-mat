import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ForumCategory, NotificationType } from "../src/index.mts";

describe("ForumCategory", () => {
  it("accepts known categories, rejects unknown", () => {
    expect(Value.Check(ForumCategory, "technique")).toBe(true);
    expect(Value.Check(ForumCategory, "general")).toBe(true);
    expect(Value.Check(ForumCategory, "random")).toBe(false);
  });
});

describe("NotificationType forum additions", () => {
  it("accepts forum notification types", () => {
    expect(Value.Check(NotificationType, "forum_answer")).toBe(true);
    expect(Value.Check(NotificationType, "forum_accepted")).toBe(true);
  });
});
