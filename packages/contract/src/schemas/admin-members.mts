import { type Static, Type as t } from "@sinclair/typebox";
import { GymRole } from "../enums/gym-role.mjs";
import { MembershipStatus } from "../enums/membership-status.mjs";

/// A gym as it appears in the admin members tree: identity plus counts only.
/// The tree must always be complete for grouping and totals to be truthful,
/// so it deliberately carries no member rows.
export const GymSummary = t.Object(
  {
    id: t.String(),
    name: t.String(),
    city: t.Optional(t.String()),
    /// Present so the status switcher can pre-disable hidden/inactive on the
    /// owner's row instead of round-tripping to discover the server guard rail.
    ownerId: t.Optional(t.String()),
    /// Every membership regardless of status, including `pending` and legacy
    /// rows with no `status` field (treated as `active`).
    memberCount: t.Integer({ minimum: 0 }),
    pendingCount: t.Integer({ minimum: 0 }),
  },
  { $id: "GymSummary" },
);
export type GymSummary = Static<typeof GymSummary>;

export const StateGroup = t.Object(
  { state: t.String(), gyms: t.Array(GymSummary) },
  { $id: "StateGroup" },
);
export type StateGroup = Static<typeof StateGroup>;

export const AdminMembersTree = t.Object(
  {
    states: t.Array(StateGroup),
    /// `gym.state` is optional in the Gym schema, so stateless gyms are real
    /// data and need their own group rather than being dropped.
    noState: t.Array(GymSummary),
    noGym: t.Object({ userCount: t.Integer({ minimum: 0 }) }),
  },
  { $id: "AdminMembersTree" },
);
export type AdminMembersTree = Static<typeof AdminMembersTree>;

/// A roster row for the admin view: the membership joined to its user, so the
/// client never has to resolve ObjectIds itself.
export const AdminRosterRow = t.Object(
  {
    membershipId: t.String(),
    gymId: t.String(),
    userId: t.String(),
    displayName: t.String(),
    email: t.String(),
    gymRole: t.Optional(GymRole),
    status: MembershipStatus,
    /// Member-controlled self-hide. Distinct from an admin setting `hidden`,
    /// and never merged into the status badge.
    visibleInRoster: t.Boolean(),
    verifiedMember: t.Boolean(),
    joinedAt: t.String(),
    /// True when the user record could not be resolved; the UI marks the row
    /// rather than dropping it silently.
    unresolved: t.Optional(t.Boolean()),
  },
  { $id: "AdminRosterRow" },
);
export type AdminRosterRow = Static<typeof AdminRosterRow>;

/// A user with no membership anywhere. Carries no status, because there is no
/// membership to carry one.
export const NoGymUserRow = t.Object(
  {
    userId: t.String(),
    displayName: t.String(),
    email: t.String(),
    createdAt: t.String(),
  },
  { $id: "NoGymUserRow" },
);
export type NoGymUserRow = Static<typeof NoGymUserRow>;
