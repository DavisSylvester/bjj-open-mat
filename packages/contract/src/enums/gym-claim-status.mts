import { type Static, Type as t } from "@sinclair/typebox";

export const GymClaimStatus = t.Union(
  [t.Literal("pending"), t.Literal("approved"), t.Literal("rejected"), t.Literal("cancelled")],
  { $id: "GymClaimStatus" },
);
export type GymClaimStatus = Static<typeof GymClaimStatus>;
