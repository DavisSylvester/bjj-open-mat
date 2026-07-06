import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { CategoryRatings } from "../review.mts";

export const ReviewRequest = t.Object(
  {
    rating: t.Integer({ minimum: 1, maximum: 5 }),
    review: t.Optional(t.String()),
    categoryRatings: CategoryRatings,
  },
  { $id: "ReviewRequest" },
);
export type ReviewRequest = Static<typeof ReviewRequest>;

export const SessionDateQuery = t.Object(
  { sessionDate: t.Optional(t.String()), date: t.Optional(t.String()) },
  { $id: "SessionDateQuery" },
);
export type SessionDateQuery = Static<typeof SessionDateQuery>;

export const AttendeesQuery = t.Object(
  {
    sessionDate: t.Optional(t.String()),
    date: t.Optional(t.String()),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 12 })),
  },
  { $id: "AttendeesQuery" },
);
export type AttendeesQuery = Static<typeof AttendeesQuery>;

export const PageQuery = t.Object(
  {
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "PageQuery" },
);
export type PageQuery = Static<typeof PageQuery>;

export const CreateCheckInRequest = t.Object(
  {
    sessionDate: t.String(),
    latitude: t.Optional(t.Number()),
    longitude: t.Optional(t.Number()),
    gpsAccuracyM: t.Optional(t.Number()),
    note: t.Optional(t.String()),
    beltRank: t.Optional(BeltRank),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateCheckInRequest" },
);
export type CreateCheckInRequest = Static<typeof CreateCheckInRequest>;
