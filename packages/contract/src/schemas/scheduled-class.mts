import { type Static, Type as t } from "@sinclair/typebox";
import { ClassType } from "../enums/class-type.mts";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const ScheduledClass = t.Object(
  {
    classId: t.String(),
    gymId: t.String(),
    date: t.String(),
    title: t.String(),
    classType: ClassType,
    classTypeLabel: t.Optional(t.String()),
    giType: GiType,
    skillLevel: SkillLevel,
    startTime: t.String(),
    endTime: t.String(),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    status: t.Union([t.Literal("scheduled"), t.Literal("cancelled")]),
    note: t.Optional(t.String()),
    capacity: t.Optional(t.Integer({ minimum: 0 })),
    goingCount: t.Integer({ minimum: 0 }),
  },
  { $id: "ScheduledClass" },
);
export type ScheduledClass = Static<typeof ScheduledClass>;
