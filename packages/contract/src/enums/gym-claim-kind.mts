import { type Static, Type as t } from "@sinclair/typebox";

export const GymClaimKind = t.Union(
  [t.Literal("claim"), t.Literal("transfer")],
  { $id: "GymClaimKind" },
);
export type GymClaimKind = Static<typeof GymClaimKind>;
