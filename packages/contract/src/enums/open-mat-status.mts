import { type Static, Type as t } from "@sinclair/typebox";

export const OpenMatStatus = t.Union(
  [t.Literal("live"), t.Literal("hidden")],
  { $id: "OpenMatStatus" },
);
export type OpenMatStatus = Static<typeof OpenMatStatus>;
