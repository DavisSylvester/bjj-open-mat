import { type Static, Type as t } from "@sinclair/typebox";

export const MembershipStatus = t.Union(
  [t.Literal("pending"), t.Literal("active"), t.Literal("hidden"), t.Literal("inactive")],
  { $id: "MembershipStatus" },
);
export type MembershipStatus = Static<typeof MembershipStatus>;

/// The statuses a gym owner, coach, or admin may assign. `pending` is owned by
/// the join flow and is deliberately not settable through the manage endpoints.
export const ManageableMembershipStatus = t.Union(
  [t.Literal("active"), t.Literal("hidden"), t.Literal("inactive")],
  { $id: "ManageableMembershipStatus" },
);
export type ManageableMembershipStatus = Static<typeof ManageableMembershipStatus>;

/// True when a membership grants gym-member privileges (forum access, DMs,
/// member-only content).
///
/// `hidden` keeps privileges — it only removes the member from rosters and
/// member-facing pickers. `inactive` revokes them. `undefined` is treated as
/// `active` because the schema default is `active` and legacy documents predate
/// the field.
export function hasMemberPrivileges(status: MembershipStatus | undefined): boolean {
  return status === undefined || status === "active" || status === "hidden";
}
