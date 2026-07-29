import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { StartDirectRequest, CreateGroupRequest, CreateChannelRequest, SendMessageRequest, AddParticipantsRequest, ReportMessageRequest, ResolveReportRequest } from "../src/index.mts";

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
  it("CreateChannelRequest + SendMessageRequest need non-empty strings", () => {
    expect(Value.Check(CreateChannelRequest, { title: "General" })).toBe(true);
    expect(Value.Check(SendMessageRequest, { body: "" })).toBe(false);
  });
  it("AddParticipantsRequest needs ≥1 user", () => {
    expect(Value.Check(AddParticipantsRequest, { userIds: ["u3"] })).toBe(true);
    expect(Value.Check(AddParticipantsRequest, { userIds: [] })).toBe(false);
  });
  it("ReportMessageRequest requires reportedUserId+reason; ResolveReportRequest requires status", () => {
    expect(Value.Check(ReportMessageRequest, { reportedUserId: "u2", reason: "spam" })).toBe(true);
    expect(Value.Check(ReportMessageRequest, { reason: "spam" })).toBe(false);
    expect(Value.Check(ResolveReportRequest, { status: "reviewed" })).toBe(true);
    expect(Value.Check(ResolveReportRequest, { status: "open" })).toBe(true);
  });
});
