import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  StartDirectRequest,
  CreateGroupRequest,
  CreateChannelRequest,
  SendMessageRequest,
  EditMessageRequest,
  AddParticipantsRequest,
  SetMutedRequest,
  BlockUserRequest,
  ReportMessageRequest,
  ResolveReportRequest,
  ConversationListQuery,
  MessageListQuery,
} from "../src/index.mts";

describe("messaging requests", () => {
  it("StartDirectRequest requires recipientId", () => {
    expect(Value.Check(StartDirectRequest, { recipientId: "u2" })).toBe(true);
    expect(Value.Check(StartDirectRequest, {})).toBe(false);
  });
  it("CreateGroupRequest requires gym+title+≥1 participant", () => {
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "Squad", participantIds: ["u2"] })).toBe(true);
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "Squad", participantIds: [] })).toBe(false);
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "", participantIds: ["u2"] })).toBe(false);
  });
  it("CreateChannelRequest requires non-empty title", () => {
    expect(Value.Check(CreateChannelRequest, { title: "General" })).toBe(true);
    expect(Value.Check(CreateChannelRequest, { title: "" })).toBe(false);
  });
  it("SendMessageRequest requires non-empty body", () => {
    expect(Value.Check(SendMessageRequest, { body: "Hello" })).toBe(true);
    expect(Value.Check(SendMessageRequest, { body: "" })).toBe(false);
  });
  it("EditMessageRequest accepts non-empty body, rejects empty", () => {
    expect(Value.Check(EditMessageRequest, { body: "x" })).toBe(true);
    expect(Value.Check(EditMessageRequest, { body: "" })).toBe(false);
  });
  it("AddParticipantsRequest needs ≥1 user", () => {
    expect(Value.Check(AddParticipantsRequest, { userIds: ["u3"] })).toBe(true);
    expect(Value.Check(AddParticipantsRequest, { userIds: [] })).toBe(false);
  });
  it("SetMutedRequest requires muted boolean, rejects missing or wrong type", () => {
    expect(Value.Check(SetMutedRequest, { muted: true })).toBe(true);
    expect(Value.Check(SetMutedRequest, { muted: false })).toBe(true);
    expect(Value.Check(SetMutedRequest, {})).toBe(false);
    expect(Value.Check(SetMutedRequest, { muted: "yes" })).toBe(false);
  });
  it("BlockUserRequest requires userId", () => {
    expect(Value.Check(BlockUserRequest, { userId: "u1" })).toBe(true);
    expect(Value.Check(BlockUserRequest, {})).toBe(false);
  });
  it("ReportMessageRequest requires reportedUserId+reason, rejects invalid status", () => {
    expect(Value.Check(ReportMessageRequest, { reportedUserId: "u2", reason: "spam" })).toBe(true);
    expect(Value.Check(ReportMessageRequest, { reason: "spam" })).toBe(false);
    expect(Value.Check(ReportMessageRequest, { reportedUserId: "u2", reason: "bogus" })).toBe(false);
  });
  it("ResolveReportRequest requires valid status", () => {
    expect(Value.Check(ResolveReportRequest, { status: "reviewed" })).toBe(true);
    expect(Value.Check(ResolveReportRequest, { status: "open" })).toBe(true);
    expect(Value.Check(ResolveReportRequest, { status: "closed" })).toBe(false);
  });
  it("ConversationListQuery accepts empty, applies defaults on parse, rejects out-of-range", () => {
    expect(Value.Check(ConversationListQuery, {})).toBe(true);
    const parsed = Value.Parse(ConversationListQuery, {});
    expect(parsed.page).toBe(1);
    expect(parsed.limit).toBe(20);
    expect(Value.Check(ConversationListQuery, { page: 0 })).toBe(false);
    expect(Value.Check(ConversationListQuery, { limit: 101 })).toBe(false);
  });
  it("MessageListQuery accepts empty, applies limit default on parse, rejects invalid limit", () => {
    expect(Value.Check(MessageListQuery, {})).toBe(true);
    const parsed = Value.Parse(MessageListQuery, {});
    expect(parsed.limit).toBe(30);
    expect(Value.Check(MessageListQuery, { before: "2026-01-01T00:00:00.000Z" })).toBe(true);
    expect(Value.Check(MessageListQuery, { limit: 0 })).toBe(false);
  });
});
