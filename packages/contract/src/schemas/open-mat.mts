import { type Static, Type as t } from "@sinclair/typebox";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const OpenMat = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    hostId: t.Optional(t.String()),
    title: t.String(),
    description: t.Optional(t.String()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm" }),
    endTime: t.String({ description: "24h HH:mm" }),
    isRecurring: t.Boolean({ default: true }),
    specificDate: t.Optional(t.String({ description: "ISO date YYYY-MM-DD" })),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: SkillLevel,
    giType: GiType,
    isCancelled: t.Boolean({ default: false }),
    verified: t.Boolean({ default: false }),
    status: t.Union([t.Literal("live"), t.Literal("hidden")], { default: "live" }),
    feeCents: t.Optional(t.Integer({ minimum: 0 })),
    attendeeCount: t.Optional(t.Integer({ minimum: 0 })),
    gymName: t.Optional(t.String()),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "OpenMat" },
);
export type OpenMat = Static<typeof OpenMat>;
