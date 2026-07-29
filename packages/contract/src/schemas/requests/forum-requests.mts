import { type Static, Type as t } from "@sinclair/typebox";
import { ForumCategory } from "../../enums/forum-category.mts";

export const CreateQuestionRequest = t.Object(
  { category: ForumCategory, title: t.String({ minLength: 1 }), body: t.String({ minLength: 1 }) },
  { $id: "CreateQuestionRequest" },
);
export type CreateQuestionRequest = Static<typeof CreateQuestionRequest>;

export const UpdateQuestionRequest = t.Object(
  {
    title: t.Optional(t.String({ minLength: 1 })),
    body: t.Optional(t.String({ minLength: 1 })),
    category: t.Optional(ForumCategory),
    pinned: t.Optional(t.Boolean()),
    locked: t.Optional(t.Boolean()),
  },
  { $id: "UpdateQuestionRequest" },
);
export type UpdateQuestionRequest = Static<typeof UpdateQuestionRequest>;

export const CreateAnswerRequest = t.Object(
  { body: t.String({ minLength: 1 }) },
  { $id: "CreateAnswerRequest" },
);
export type CreateAnswerRequest = Static<typeof CreateAnswerRequest>;

export const UpdateAnswerRequest = t.Object(
  { body: t.String({ minLength: 1 }) },
  { $id: "UpdateAnswerRequest" },
);
export type UpdateAnswerRequest = Static<typeof UpdateAnswerRequest>;

export const AcceptAnswerRequest = t.Object(
  { answerId: t.String() },
  { $id: "AcceptAnswerRequest" },
);
export type AcceptAnswerRequest = Static<typeof AcceptAnswerRequest>;

export const ForumListQuery = t.Object(
  {
    category: t.Optional(ForumCategory),
    page: t.Optional(t.Integer({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Integer({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "ForumListQuery" },
);
export type ForumListQuery = Static<typeof ForumListQuery>;
