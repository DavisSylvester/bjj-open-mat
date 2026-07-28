import { type Static, Type as t } from "@sinclair/typebox";

export const UpsertJournalRequest = t.Object(
  {
    date: t.String(),
    whatWasTaught: t.Optional(t.String()),
    techniqueTags: t.Optional(t.Array(t.String())),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
    note: t.Optional(t.String()),
    shared: t.Optional(t.Boolean()),
  },
  { $id: "UpsertJournalRequest" },
);
export type UpsertJournalRequest = Static<typeof UpsertJournalRequest>;

export const JournalRangeQuery = t.Object(
  { from: t.String(), to: t.String() },
  { $id: "JournalRangeQuery" },
);
export type JournalRangeQuery = Static<typeof JournalRangeQuery>;

export const OccurrenceJournalQuery = t.Object(
  { date: t.String() },
  { $id: "OccurrenceJournalQuery" },
);
export type OccurrenceJournalQuery = Static<typeof OccurrenceJournalQuery>;

export const UpsertInstructorRatingRequest = t.Object(
  {
    date: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    anonymous: t.Optional(t.Boolean()),
  },
  { $id: "UpsertInstructorRatingRequest" },
);
export type UpsertInstructorRatingRequest = Static<typeof UpsertInstructorRatingRequest>;

export const InstructorFeedbackQuery = t.Object(
  {
    instructorUserId: t.Optional(t.String()),
    from: t.Optional(t.String()),
    to: t.Optional(t.String()),
  },
  { $id: "InstructorFeedbackQuery" },
);
export type InstructorFeedbackQuery = Static<typeof InstructorFeedbackQuery>;
