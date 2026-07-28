import { type Static, Type as t } from "@sinclair/typebox";

export const JoinMethod = t.Union(
  [t.Literal("self"), t.Literal("code"), t.Literal("invite")],
  { $id: "JoinMethod" },
);
export type JoinMethod = Static<typeof JoinMethod>;
