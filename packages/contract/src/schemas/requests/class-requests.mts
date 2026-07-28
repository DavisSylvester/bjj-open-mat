import { type Static, Type as t } from "@sinclair/typebox";
import { ClassType } from "../../enums/class-type.mts";
import { GiType } from "../../enums/gi-type.mts";
import { SkillLevel } from "../../enums/skill-level.mts";

// CreateClassRequest = GymClass minus id, gymId, status, createdAt
// with isRecurring made optional instead of defaulted
export const CreateClassRequest = t.Object(
  {
    title: t.String({ minLength: 1 }),
    classType: ClassType,
    classTypeLabel: t.Optional(t.String()),
    description: t.Optional(t.String()),
    giType: GiType,
    skillLevel: SkillLevel,
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    isRecurring: t.Optional(t.Boolean()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm" }),
    endTime: t.String({ description: "24h HH:mm" }),
    specificDate: t.Optional(t.String({ description: "ISO YYYY-MM-DD (one-off)" })),
    capacity: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateClassRequest" },
);
export type CreateClassRequest = Static<typeof CreateClassRequest>;

export const UpdateClassRequest = t.Partial(CreateClassRequest, { $id: "UpdateClassRequest" });
export type UpdateClassRequest = Static<typeof UpdateClassRequest>;

export const OccurrenceOverrideRequest = t.Object(
  {
    status: t.Optional(t.Union([t.Literal("scheduled"), t.Literal("cancelled")])),
    startTime: t.Optional(t.String()),
    endTime: t.Optional(t.String()),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    note: t.Optional(t.String()),
  },
  { $id: "OccurrenceOverrideRequest" },
);
export type OccurrenceOverrideRequest = Static<typeof OccurrenceOverrideRequest>;

export const ClassRsvpRequest = t.Object({ date: t.String() }, { $id: "ClassRsvpRequest" });
export type ClassRsvpRequest = Static<typeof ClassRsvpRequest>;

export const ScheduleQuery = t.Object(
  { from: t.String({ description: "ISO YYYY-MM-DD" }), to: t.String({ description: "ISO YYYY-MM-DD" }) },
  { $id: "ScheduleQuery" },
);
export type ScheduleQuery = Static<typeof ScheduleQuery>;

export const AttendeesQuery = t.Object({ date: t.String() }, { $id: "AttendeesQuery" });
export type AttendeesQuery = Static<typeof AttendeesQuery>;
