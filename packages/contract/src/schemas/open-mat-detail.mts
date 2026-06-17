import { type Static, Type as t } from "@sinclair/typebox";
import { OpenMat } from "./open-mat.mts";

export const OpenMatDetail = t.Composite(
  [
    OpenMat,
    t.Object({
      latitude: t.Optional(t.Number()),
      longitude: t.Optional(t.Number()),
      address: t.String(),
      city: t.String(),
      state: t.String(),
      postalCode: t.Optional(t.String()),
      gymRating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    }),
  ],
  { $id: "OpenMatDetail" },
);
export type OpenMatDetail = Static<typeof OpenMatDetail>;
