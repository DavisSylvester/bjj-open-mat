import { type Static, Type as t } from "@sinclair/typebox";
import { GeoLocation } from "./geo-location.mts";

export const Gym = t.Object(
  {
    id: t.String(),
    ownerId: t.Optional(t.String()),
    name: t.String(),
    description: t.Optional(t.String()),
    address: t.String(),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    country: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    location: t.Optional(GeoLocation),
    googlePlaceId: t.Optional(t.String()),
    googleReviewUri: t.Optional(t.String()),
    phone: t.Optional(t.String()),
    website: t.Optional(t.String()),
    logoUrl: t.Optional(t.String()),
    joinCode: t.Optional(t.String()),
    amenities: t.Array(t.String(), { default: [] }),
    isVerified: t.Boolean({ default: false }),
    verifiedAt: t.Optional(t.String()),
    rating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    ratingCount: t.Optional(t.Integer({ minimum: 0 })),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    // Ranking seam for future paid placement. Nothing writes rankBoost today;
    // the search sort reads it so that selling placement later is a write path
    // plus a badge, not a contract change. `sponsored` is derived at read time
    // as rankBoost > 0 and is never persisted.
    rankBoost: t.Optional(t.Integer({ default: 0 })),
    sponsored: t.Optional(t.Boolean({ default: false })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "Gym" },
);
export type Gym = Static<typeof Gym>;
