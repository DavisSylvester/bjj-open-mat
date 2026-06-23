import { type Static, Type as t } from "@sinclair/typebox";

// Stored on a session AND used as a search filter. Filter semantics (facade):
// gi -> matches gi|both; nogi -> matches nogi|both; omitted -> all.
export const GiType = t.Union(
  [t.Literal("gi"), t.Literal("nogi"), t.Literal("both")],
  { $id: "GiType" },
);
export type GiType = Static<typeof GiType>;
