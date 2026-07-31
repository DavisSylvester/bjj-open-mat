import { type Static, Type as t } from "@sinclair/typebox";
import { ConversationKind } from "../enums/conversation-kind.mts";

export const Conversation = t.Object(
  {
    id: t.String(),
    kind: ConversationKind,
    gymId: t.Optional(t.String()),
    title: t.Optional(t.String()),
    pairKey: t.Optional(t.String()),
    createdBy: t.String(),
    createdAt: t.Optional(t.String()),
    lastMessageAt: t.Optional(t.String()),
    lastMessagePreview: t.Optional(t.String()),
  },
  { $id: "Conversation" },
);
export type Conversation = Static<typeof Conversation>;
