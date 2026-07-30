import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ForumQuestion, ForumAnswer, ForumQuestionDetail } from "../src/index.mts";

describe("ForumQuestion", () => {
  it("parses minimal with defaults", () => {
    const q = Value.Parse(ForumQuestion, {
      id: "q1", gymId: "g1", authorId: "u1", category: "technique", title: "Guard?", body: "How?",
    });
    expect(q.pinned).toBe(false);
    expect(q.locked).toBe(false);
    expect(q.answerCount).toBe(0);
  });
});

describe("ForumAnswer", () => {
  it("defaults accepted false", () => {
    const a = Value.Parse(ForumAnswer, { id: "a1", questionId: "q1", gymId: "g1", authorId: "u2", body: "Like this" });
    expect(a.accepted).toBe(false);
  });
});

describe("ForumQuestionDetail", () => {
  it("wraps a question + answers", () => {
    expect(Value.Check(ForumQuestionDetail, {
      question: { id: "q1", gymId: "g1", authorId: "u1", category: "general", title: "t", body: "b", pinned: false, locked: false, answerCount: 0 },
      answers: [],
    })).toBe(true);
  });
});
