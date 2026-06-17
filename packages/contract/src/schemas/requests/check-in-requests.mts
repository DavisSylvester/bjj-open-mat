import { type Static, Type as t } from "@sinclair/typebox";
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

export const PageQuery = t.Object(
  {
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "PageQuery" },
);
export type PageQuery = Static<typeof PageQuery>;
