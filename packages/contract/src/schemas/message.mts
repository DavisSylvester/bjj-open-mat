import { type Static, Type as t } from "@sinclair/typebox";

export const Message = t.Object(
  {
    id: t.String(),
    conversationId: t.String(),
    authorId: t.String(),
    body: t.String({ minLength: 1 }),
    createdAt: t.Optional(t.String()),
    editedAt: t.Optional(t.String()),
    deletedAt: t.Optional(t.String()),
  },
  { $id: "Message" },
);
export type Message = Static<typeof Message>;
