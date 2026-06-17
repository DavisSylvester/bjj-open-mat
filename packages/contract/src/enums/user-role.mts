import { type Static, Type as t } from "@sinclair/typebox";

export const UserRole = t.Union(
  [t.Literal("practitioner"), t.Literal("gym_owner")],
  { $id: "UserRole" },
);
export type UserRole = Static<typeof UserRole>;
