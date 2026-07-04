import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { CheckInLocationStatus } from "../enums/check-in-location-status.mts";
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
    latitude: t.Optional(t.Number()),
    longitude: t.Optional(t.Number()),
    gpsAccuracyM: t.Optional(t.Number()),
    locationStatus: t.Optional(CheckInLocationStatus),
    distanceM: t.Optional(t.Number()),
    gymId: t.Optional(t.String()),
    gymCity: t.Optional(t.String()),
    gymState: t.Optional(t.String()),
    note: t.Optional(t.String()),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
    gymName: t.Optional(t.String()),
    openMatTitle: t.Optional(t.String()),
    userName: t.Optional(t.String()),
    beltRank: t.Optional(BeltRank),
    createdAt: t.Optional(t.String()),
  },
  { $id: "CheckIn" },
);
export type CheckIn = Static<typeof CheckIn>;
