import { type Static, Type as t } from "@sinclair/typebox";
import { ForumQuestion } from "./forum-question.mts";
import { ForumAnswer } from "./forum-answer.mts";

export const ForumQuestionDetail = t.Object(
  {
    question: ForumQuestion,
    answers: t.Array(ForumAnswer),
  },
  { $id: "ForumQuestionDetail" },
);
export type ForumQuestionDetail = Static<typeof ForumQuestionDetail>;
