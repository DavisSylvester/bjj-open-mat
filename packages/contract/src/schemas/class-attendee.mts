import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";

export const ClassAttendee = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    isMember: t.Boolean(),
    beltRank: t.Optional(BeltRank),
    avatarUrl: t.Optional(t.String()),
    // False when the user doc could not be resolved — clients must not deep-link.
    hasProfile: t.Boolean(),
  },
  { $id: "ClassAttendee" },
);
export type ClassAttendee = Static<typeof ClassAttendee>;
