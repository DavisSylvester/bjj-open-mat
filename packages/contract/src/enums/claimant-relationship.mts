import { type Static, Type as t } from "@sinclair/typebox";

export const ClaimantRelationship = t.Union(
  [t.Literal("owner"), t.Literal("head_coach"), t.Literal("manager")],
  { $id: "ClaimantRelationship" },
);
export type ClaimantRelationship = Static<typeof ClaimantRelationship>;
