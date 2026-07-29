import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { Conversation, Message, ConversationParticipant, ChannelReadState, UserBlock, MessageReport, ConversationSummary } from "../src/index.mts";

describe("messaging schemas", () => {
  it("Conversation parses a direct convo with pairKey", () => {
    const c = Value.Parse(Conversation, { id: "c1", kind: "direct", pairKey: "u1|u2", createdBy: "u1" });
    expect(c.kind).toBe("direct");
    expect(c.pairKey).toBe("u1|u2");
  });
  it("Message requires non-empty body", () => {
    expect(Value.Check(Message, { id: "m1", conversationId: "c1", authorId: "u1", body: "hi" })).toBe(true);
    expect(Value.Check(Message, { id: "m1", conversationId: "c1", authorId: "u1", body: "" })).toBe(false);
  });
  it("ConversationParticipant defaults role member + not muted", () => {
    const p = Value.Parse(ConversationParticipant, { id: "p1", conversationId: "c1", userId: "u1" });
    expect(p.role).toBe("member");
    expect(p.muted).toBe(false);
  });
  it("ChannelReadState defaults muted false", () => {
    const s = Value.Parse(ChannelReadState, { id: "s1", channelId: "c1", userId: "u1" });
    expect(s.muted).toBe(false);
  });
  it("UserBlock + MessageReport + ConversationSummary check", () => {
    expect(Value.Check(UserBlock, { id: "b1", blockerId: "u1", blockedId: "u2" })).toBe(true);
    const r = Value.Parse(MessageReport, { id: "r1", reportedUserId: "u2", reporterId: "u1", gymId: "g1", reason: "spam" });
    expect(r.status).toBe("open");
    expect(Value.Check(ConversationSummary, {
      conversation: { id: "c1", kind: "group", gymId: "g1", title: "T", createdBy: "u1" },
      unreadCount: 2, muted: false, otherParticipantIds: ["u2"],
    })).toBe(true);
  });
});
