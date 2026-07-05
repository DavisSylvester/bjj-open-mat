import { type Static, Type as t } from "@sinclair/typebox";

export const WeightDivision = t.Union(
  [
    t.Literal("rooster"),
    t.Literal("light_feather"),
    t.Literal("feather"),
    t.Literal("light"),
    t.Literal("middle"),
    t.Literal("medium_heavy"),
    t.Literal("heavy"),
    t.Literal("super_heavy"),
    t.Literal("ultra_heavy"),
  ],
  { $id: "WeightDivision" },
);
export type WeightDivision = Static<typeof WeightDivision>;
