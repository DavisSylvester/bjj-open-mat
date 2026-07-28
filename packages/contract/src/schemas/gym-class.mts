import { type Static, Type as t } from "@sinclair/typebox";
import { ClassType } from "../enums/class-type.mts";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const GymClass = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    title: t.String({ minLength: 1 }),
    classType: ClassType,
    classTypeLabel: t.Optional(t.String()),
    description: t.Optional(t.String()),
    giType: GiType,
    skillLevel: SkillLevel,
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    isRecurring: t.Boolean({ default: true }),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm" }),
    endTime: t.String({ description: "24h HH:mm" }),
    specificDate: t.Optional(t.String({ description: "ISO YYYY-MM-DD (one-off)" })),
    capacity: t.Optional(t.Integer({ minimum: 0 })),
    status: t.Optional(t.Union([t.Literal("active"), t.Literal("archived")], { default: "active" })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "GymClass" },
);
export type GymClass = Static<typeof GymClass>;
