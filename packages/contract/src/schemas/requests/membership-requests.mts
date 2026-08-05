import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { GymRole } from "../../enums/gym-role.mts";
import { ManageableMembershipStatus } from "../../enums/membership-status.mts";

export const UpdateMembershipRequest = t.Object(
  {
    verifiedMember: t.Optional(t.Boolean()),
    gymRole: t.Optional(GymRole),
    status: t.Optional(ManageableMembershipStatus),
  },
  { $id: "UpdateMembershipRequest" },
);
export type UpdateMembershipRequest = Static<typeof UpdateMembershipRequest>;

export const UpdateMyMembershipRequest = t.Object(
  {
    visibleInRoster: t.Optional(t.Boolean()),
    isHome: t.Optional(t.Boolean()),
  },
  { $id: "UpdateMyMembershipRequest" },
);
export type UpdateMyMembershipRequest = Static<typeof UpdateMyMembershipRequest>;

export const PromoteBeltRequest = t.Object(
  {
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    note: t.Optional(t.String()),
  },
  { $id: "PromoteBeltRequest" },
);
export type PromoteBeltRequest = Static<typeof PromoteBeltRequest>;
