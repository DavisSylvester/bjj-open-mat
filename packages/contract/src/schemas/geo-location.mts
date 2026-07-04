import { type Static, Type as t } from "@sinclair/typebox";

export const GeoLocation = t.Object(
  { lat: t.Number({ minimum: -90, maximum: 90 }), lng: t.Number({ minimum: -180, maximum: 180 }) },
  { $id: "GeoLocation" },
);
export type GeoLocation = Static<typeof GeoLocation>;
