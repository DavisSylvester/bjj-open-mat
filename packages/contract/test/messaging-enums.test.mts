import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ConversationKind, ParticipantRole, MessageReportReason, MessageReportStatus } from "../src/index.mts";

describe("messaging enums", () => {
  it("ConversationKind", () => {
    expect(Value.Check(ConversationKind, "direct")).toBe(true);
    expect(Value.Check(ConversationKind, "gym_channel")).toBe(true);
    expect(Value.Check(ConversationKind, "nope")).toBe(false);
  });
  it("ParticipantRole", () => {
    expect(Value.Check(ParticipantRole, "admin")).toBe(true);
    expect(Value.Check(ParticipantRole, "owner")).toBe(false);
  });
  it("report reason + status", () => {
    expect(Value.Check(MessageReportReason, "harassment")).toBe(true);
    expect(Value.Check(MessageReportReason, "other")).toBe(true);
    expect(Value.Check(MessageReportStatus, "open")).toBe(true);
    expect(Value.Check(MessageReportStatus, "closed")).toBe(false);
  });
});
