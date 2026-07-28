import { type Static, Type as t } from "@sinclair/typebox";
import { GymClass } from "../gym-class.mts";

// CreateClassRequest = GymClass minus id, gymId, status, createdAt
export const CreateClassRequest = t.Omit(GymClass, ["id", "gymId", "status", "createdAt"], { $id: "CreateClassRequest" });
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

export const ClassAttendeesQuery = t.Object({ date: t.String() }, { $id: "ClassAttendeesQuery" });
export type ClassAttendeesQuery = Static<typeof ClassAttendeesQuery>;
