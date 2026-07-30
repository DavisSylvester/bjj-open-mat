import { type Static, Type as t } from "@sinclair/typebox";
import { ForumCategory } from "../enums/forum-category.mts";

export const ForumQuestion = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    authorId: t.String(),
    category: ForumCategory,
    title: t.String({ minLength: 1 }),
    body: t.String({ minLength: 1 }),
    pinned: t.Boolean({ default: false }),
    locked: t.Boolean({ default: false }),
    acceptedAnswerId: t.Optional(t.String()),
    answerCount: t.Integer({ minimum: 0, default: 0 }),
    createdAt: t.Optional(t.String()),
    updatedAt: t.Optional(t.String()),
  },
  { $id: "ForumQuestion" },
);
export type ForumQuestion = Static<typeof ForumQuestion>;
