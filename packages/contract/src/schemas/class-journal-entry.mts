import { type Static, Type as t } from "@sinclair/typebox";

export const ClassJournalEntry = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    userId: t.String(),
    date: t.String({ description: "ISO YYYY-MM-DD" }),
    whatWasTaught: t.Optional(t.String()),
    techniqueTags: t.Array(t.String(), { default: [] }),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
    note: t.Optional(t.String()),
    shared: t.Boolean({ default: false }),
    createdAt: t.Optional(t.String()),
    updatedAt: t.Optional(t.String()),
  },
  { $id: "ClassJournalEntry" },
);
export type ClassJournalEntry = Static<typeof ClassJournalEntry>;
