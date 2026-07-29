import { type Static, Type as t } from "@sinclair/typebox";
import { Conversation } from "./conversation.mts";
import { Message } from "./message.mts";

export const ConversationSummary = t.Object(
  {
    conversation: Conversation,
    unreadCount: t.Integer({ minimum: 0, default: 0 }),
    muted: t.Boolean({ default: false }),
    lastMessage: t.Optional(Message),
    otherParticipantIds: t.Array(t.String()),
  },
  { $id: "ConversationSummary" },
);
export type ConversationSummary = Static<typeof ConversationSummary>;
