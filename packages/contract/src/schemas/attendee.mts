import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const Attendee = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    skillLevel: SkillLevel,
    avatarUrl: t.Optional(t.String({ format: "uri" })),
    rsvpAt: t.String(),
  },
  { $id: "Attendee" },
);
export type Attendee = Static<typeof Attendee>;
