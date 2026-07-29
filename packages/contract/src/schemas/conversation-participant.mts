import { type Static, Type as t } from "@sinclair/typebox";
import { ParticipantRole } from "../enums/participant-role.mts";

export const ConversationParticipant = t.Object(
  {
    id: t.String(),
    conversationId: t.String(),
    userId: t.String(),
    role: t.Union([ParticipantRole], { default: "member" }),
    lastReadAt: t.Optional(t.String()),
    muted: t.Boolean({ default: false }),
    leftAt: t.Optional(t.String()),
  },
  { $id: "ConversationParticipant" },
);
export type ConversationParticipant = Static<typeof ConversationParticipant>;
