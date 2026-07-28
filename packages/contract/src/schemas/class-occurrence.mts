import { type Static, Type as t } from "@sinclair/typebox";

export const ClassOccurrence = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    date: t.String({ description: "ISO YYYY-MM-DD" }),
    status: t.Optional(t.Union([t.Literal("scheduled"), t.Literal("cancelled")], { default: "scheduled" })),
    startTime: t.Optional(t.String()),
    endTime: t.Optional(t.String()),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    note: t.Optional(t.String()),
  },
  { $id: "ClassOccurrence" },
);
export type ClassOccurrence = Static<typeof ClassOccurrence>;
