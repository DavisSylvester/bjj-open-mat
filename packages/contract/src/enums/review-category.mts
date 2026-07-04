import { type Static, Type as t } from "@sinclair/typebox";

export const ReviewCategory = t.Union(
  [
    t.Literal("instruction"),
    t.Literal("cleanliness"),
    t.Literal("variety"),
    t.Literal("worth_returning"),
    t.Literal("overall"),
  ],
  { $id: "ReviewCategory" },
);
export type ReviewCategory = Static<typeof ReviewCategory>;
