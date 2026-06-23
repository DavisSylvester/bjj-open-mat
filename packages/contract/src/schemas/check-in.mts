import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { CategoryRatings } from "./review.mts";

export const CheckIn = t.Object(
  {
    id: t.String(),
    openMatId: t.String(),
    userId: t.String(),
    sessionDate: t.String(),
    checkedInAt: t.String(),
    rating: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    review: t.Optional(t.String()),
    categoryRatings: t.Optional(CategoryRatings),
    gymName: t.Optional(t.String()),
    openMatTitle: t.Optional(t.String()),
    userName: t.Optional(t.String()),
    beltRank: t.Optional(BeltRank),
    createdAt: t.Optional(t.String()),
  },
  { $id: "CheckIn" },
);
export type CheckIn = Static<typeof CheckIn>;
