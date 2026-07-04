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
    phone: t.Optional(t.String()),
    website: t.Optional(t.String()),
    amenities: t.Array(t.String(), { default: [] }),
    isVerified: t.Boolean({ default: false }),
    rating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "Gym" },
);
export type Gym = Static<typeof Gym>;
