import { type Static, Type as t } from "@sinclair/typebox";
import { GymRole } from "../enums/gym-role.mjs";
import { MembershipStatus } from "../enums/membership-status.mjs";
import { JoinMethod } from "../enums/join-method.mjs";

export const GymMembership = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    userId: t.String(),
    status: t.Optional(t.Union([MembershipStatus], { default: "active" })),
    verifiedMember: t.Boolean({ default: false }),
    gymRole: t.Optional(t.Union([GymRole], { default: "member" })),
    isHome: t.Boolean({ default: false }),
    visibleInRoster: t.Boolean({ default: true }),
    joinMethod: t.Optional(t.Union([JoinMethod], { default: "self" })),
    joinedAt: t.String(),
    createdAt: t.Optional(t.String()),
    // Set whenever an owner/coach/admin changes `status`.
    statusUpdatedAt: t.Optional(t.String()),
    statusUpdatedBy: t.Optional(t.String()),
  },
  { $id: "GymMembership" },
);
export type GymMembership = Static<typeof GymMembership>;
