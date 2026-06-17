import { type Static, Type as t } from "@sinclair/typebox";
import { GiType } from "../../enums/gi-type.mts";
import { SkillLevel } from "../../enums/skill-level.mts";

export const CreateOpenMatRequest = t.Object(
  {
    gymId: t.String(),
    hostId: t.Optional(t.String()),
    title: t.String({ minLength: 1 }),
    description: t.Optional(t.String()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String(),
    endTime: t.String(),
    isRecurring: t.Optional(t.Boolean()),
    specificDate: t.Optional(t.String()),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: t.Optional(SkillLevel),
    giType: t.Optional(GiType),
    feeCents: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateOpenMatRequest" },
);
export type CreateOpenMatRequest = Static<typeof CreateOpenMatRequest>;

export const UpdateOpenMatRequest = t.Partial(CreateOpenMatRequest, { $id: "UpdateOpenMatRequest" });
export type UpdateOpenMatRequest = Static<typeof UpdateOpenMatRequest>;

export const OpenMatListQuery = t.Object(
  {
    dayOfWeek: t.Optional(t.Number({ minimum: 0, maximum: 6 })),
    giType: t.Optional(GiType),
    skillLevel: t.Optional(SkillLevel),
    mine: t.Optional(t.Boolean()),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "OpenMatListQuery" },
);
export type OpenMatListQuery = Static<typeof OpenMatListQuery>;

export const RsvpRequest = t.Object({ sessionDate: t.String() }, { $id: "RsvpRequest" });
export type RsvpRequest = Static<typeof RsvpRequest>;

export const CheckinRequest = t.Object({ sessionDate: t.String() }, { $id: "CheckinRequest" });
export type CheckinRequest = Static<typeof CheckinRequest>;
