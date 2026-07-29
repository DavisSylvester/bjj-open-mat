import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CreateQuestionRequest, UpdateQuestionRequest, CreateAnswerRequest, AcceptAnswerRequest } from "../src/index.mts";

describe("forum requests", () => {
  it("CreateQuestionRequest requires category+title+body", () => {
    expect(Value.Check(CreateQuestionRequest, { category: "technique", title: "T", body: "B" })).toBe(true);
    expect(Value.Check(CreateQuestionRequest, { category: "technique", title: "" , body: "B" })).toBe(false);
    expect(Value.Check(CreateQuestionRequest, { title: "T", body: "B" })).toBe(false);
  });
  it("UpdateQuestionRequest all-optional (incl moderation fields)", () => {
    expect(Value.Check(UpdateQuestionRequest, {})).toBe(true);
    expect(Value.Check(UpdateQuestionRequest, { pinned: true })).toBe(true);
    expect(Value.Check(UpdateQuestionRequest, { locked: true, title: "x" })).toBe(true);
  });
  it("CreateAnswerRequest requires non-empty body", () => {
    expect(Value.Check(CreateAnswerRequest, { body: "hi" })).toBe(true);
    expect(Value.Check(CreateAnswerRequest, { body: "" })).toBe(false);
  });
  it("AcceptAnswerRequest requires answerId", () => {
    expect(Value.Check(AcceptAnswerRequest, { answerId: "a1" })).toBe(true);
    expect(Value.Check(AcceptAnswerRequest, {})).toBe(false);
  });
});
