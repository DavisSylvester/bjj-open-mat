import { type Static, Type as t } from "@sinclair/typebox";

export const ForumAnswer = t.Object(
  {
    id: t.String(),
    questionId: t.String(),
    gymId: t.String(),
    authorId: t.String(),
    body: t.String({ minLength: 1 }),
    accepted: t.Boolean({ default: false }),
    createdAt: t.Optional(t.String()),
    updatedAt: t.Optional(t.String()),
  },
  { $id: "ForumAnswer" },
);
export type ForumAnswer = Static<typeof ForumAnswer>;
