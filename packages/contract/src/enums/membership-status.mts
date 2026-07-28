import { type Static, Type as t } from "@sinclair/typebox";

export const MembershipStatus = t.Union(
  [t.Literal("pending"), t.Literal("active")],
  { $id: "MembershipStatus" },
);
export type MembershipStatus = Static<typeof MembershipStatus>;
