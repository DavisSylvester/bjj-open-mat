import { type Static, Type as t } from "@sinclair/typebox";

export const GymRole = t.Union(
  [t.Literal("member"), t.Literal("coach"), t.Literal("owner")],
  { $id: "GymRole" },
);
export type GymRole = Static<typeof GymRole>;
