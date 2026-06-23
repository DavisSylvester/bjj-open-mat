import { type Static, Type as t } from "@sinclair/typebox";

export const SkillLevel = t.Union(
  [t.Literal("all"), t.Literal("beginner"), t.Literal("intermediate"), t.Literal("advanced")],
  { $id: "SkillLevel" },
);
export type SkillLevel = Static<typeof SkillLevel>;
