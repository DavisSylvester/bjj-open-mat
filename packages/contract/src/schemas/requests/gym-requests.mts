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
    logoUrl: t.Optional(t.String()),
    amenities: t.Optional(t.Array(t.String())),
  },
  { $id: "CreateGymRequest" },
);
export type CreateGymRequest = Static<typeof CreateGymRequest>;

export const UpdateGymRequest = t.Partial(CreateGymRequest, { $id: "UpdateGymRequest" });
export type UpdateGymRequest = Static<typeof UpdateGymRequest>;

// Request a presigned S3 PUT URL for a gym logo upload. The client uploads the
// bytes directly to S3, then submits the returned publicUrl as the gym logoUrl.
export const LogoContentType = t.Union(
  [t.Literal("image/png"), t.Literal("image/jpeg"), t.Literal("image/webp")],
  { $id: "LogoContentType" },
);
export type LogoContentType = Static<typeof LogoContentType>;

export const LogoUploadUrlRequest = t.Object(
  {
    contentType: LogoContentType,
  },
  { $id: "LogoUploadUrlRequest" },
);
export type LogoUploadUrlRequest = Static<typeof LogoUploadUrlRequest>;

export const LogoUploadUrlResponse = t.Object(
  {
    uploadUrl: t.String(),
    publicUrl: t.String(),
    key: t.String(),
  },
  { $id: "LogoUploadUrlResponse" },
);
export type LogoUploadUrlResponse = Static<typeof LogoUploadUrlResponse>;

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
