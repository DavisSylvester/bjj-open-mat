import { type Static, Type as t } from "@sinclair/typebox";

export const BeltRank = t.Union(
  [t.Literal("white"), t.Literal("blue"), t.Literal("purple"), t.Literal("brown"), t.Literal("black")],
  { $id: "BeltRank" },
);
export type BeltRank = Static<typeof BeltRank>;
