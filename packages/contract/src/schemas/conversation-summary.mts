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
    // Other participants resolved to display names so clients never render a
    // raw user id (e.g. an Auth0 subject `google-oauth2|…`) as the title.
    otherParticipants: t.Optional(
      t.Array(t.Object({ userId: t.String(), displayName: t.String() })),
    ),
  },
  { $id: "ConversationSummary" },
);
export type ConversationSummary = Static<typeof ConversationSummary>;
