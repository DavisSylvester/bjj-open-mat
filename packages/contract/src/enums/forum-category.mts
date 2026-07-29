import { type Static, Type as t } from "@sinclair/typebox";

export const ForumCategory = t.Union(
  [
    t.Literal("technique"),
    t.Literal("rules"),
    t.Literal("competition"),
    t.Literal("schedule"),
    t.Literal("gear"),
    t.Literal("general"),
  ],
  { $id: "ForumCategory" },
);
export type ForumCategory = Static<typeof ForumCategory>;
