import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { GymRole } from "../enums/gym-role.mts";
import { SkillLevel } from "../enums/skill-level.mts";
import { MembershipStatus } from "../enums/membership-status.mts";

export const RosterMember = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    beltRank: t.Optional(BeltRank),
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    verifiedBeltRank: t.Optional(BeltRank),
    verifiedBeltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    skillLevel: t.Optional(SkillLevel),
    avatarUrl: t.Optional(t.String()),
    gymRole: GymRole,
    verifiedMember: t.Boolean(),
    // Public responses only ever contain 'active'; managers also see
    // 'hidden' and 'inactive'.
    status: MembershipStatus,
    // False when the user doc could not be resolved — clients must not deep-link.
    hasProfile: t.Boolean(),
    // Populated only on manager rosters (includeHidden = true), so a manager can
    // tell an owner/admin-hidden member (status) from a self-hidden one
    // (visibleInRoster). Absent — not `false` — on the public roster.
    visibleInRoster: t.Optional(t.Boolean()),
  },
  { $id: "RosterMember" },
);
export type RosterMember = Static<typeof RosterMember>;
