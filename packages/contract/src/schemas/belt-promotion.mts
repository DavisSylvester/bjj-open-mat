import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mjs";

export const BeltPromotion = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    gymId: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    promotedByUserId: t.String(),
    promotedAt: t.String(),
    note: t.Optional(t.String()),
  },
  { $id: "BeltPromotion" },
);
export type BeltPromotion = Static<typeof BeltPromotion>;
