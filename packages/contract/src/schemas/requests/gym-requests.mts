import { type Static, Type as t } from "@sinclair/typebox";
import { GeoLocation } from "../geo-location.mts";

export const CreateGymRequest = t.Object(
  {
    name: t.String({ minLength: 1 }),
    description: t.Optional(t.String()),
    address: t.String({ minLength: 1 }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    country: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    location: t.Optional(GeoLocation),
    googlePlaceId: t.Optional(t.String()),
    phone: t.Optional(t.String()),
    website: t.Optional(t.String()),
    amenities: t.Optional(t.Array(t.String())),
  },
  { $id: "CreateGymRequest" },
);
export type CreateGymRequest = Static<typeof CreateGymRequest>;

export const UpdateGymRequest = t.Partial(CreateGymRequest, { $id: "UpdateGymRequest" });
export type UpdateGymRequest = Static<typeof UpdateGymRequest>;

export const NearbyQuery = t.Object(
  {
    lat: t.Number(),
    lng: t.Number(),
    radiusKm: t.Optional(t.Number({ minimum: 1, maximum: 500, default: 25 })),
  },
  { $id: "NearbyQuery" },
);
export type NearbyQuery = Static<typeof NearbyQuery>;

export const GymListQuery = t.Object(
  {
    mine: t.Optional(t.Boolean()),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "GymListQuery" },
);
export type GymListQuery = Static<typeof GymListQuery>;
