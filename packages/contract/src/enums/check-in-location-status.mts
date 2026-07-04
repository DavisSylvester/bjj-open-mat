import { type Static, Type as t } from "@sinclair/typebox";

export const CheckInLocationStatus = t.Union(
  [t.Literal("verified"), t.Literal("far"), t.Literal("no_location")],
  { $id: "CheckInLocationStatus" },
);
export type CheckInLocationStatus = Static<typeof CheckInLocationStatus>;
