import { type Static, Type as t } from "@sinclair/typebox";

export const ClassType = t.Union(
  [
    t.Literal("fundamentals"),
    t.Literal("all_levels"),
    t.Literal("advanced"),
    t.Literal("gi"),
    t.Literal("nogi"),
    t.Literal("kids"),
    t.Literal("womens"),
    t.Literal("competition"),
    t.Literal("private"),
    t.Literal("other"),
  ],
  { $id: "ClassType" },
);
export type ClassType = Static<typeof ClassType>;
