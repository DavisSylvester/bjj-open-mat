import { type Static, Type as t } from "@sinclair/typebox";

export const InstructorRating = t.Object(
  {
    id: t.String(),
    classId: t.String(),
    gymId: t.String(),
    date: t.String(),
    instructorUserId: t.Optional(t.String()),
    instructorName: t.Optional(t.String()),
    ratedByUserId: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    anonymous: t.Boolean({ default: false }),
    createdAt: t.Optional(t.String()),
  },
  { $id: "InstructorRating" },
);
export type InstructorRating = Static<typeof InstructorRating>;

export const InstructorRatingSummary = t.Object(
  {
    instructorUserId: t.String(),
    avg: t.Number({ minimum: 0, maximum: 5 }),
    count: t.Integer({ minimum: 0 }),
  },
  { $id: "InstructorRatingSummary" },
);
export type InstructorRatingSummary = Static<typeof InstructorRatingSummary>;

export const InstructorFeedbackItem = t.Object(
  {
    classId: t.String(),
    date: t.String(),
    stars: t.Integer({ minimum: 1, maximum: 5 }),
    comment: t.Optional(t.String()),
    ratedByName: t.Optional(t.String()),
    anonymous: t.Boolean(),
    createdAt: t.Optional(t.String()),
  },
  { $id: "InstructorFeedbackItem" },
);
export type InstructorFeedbackItem = Static<typeof InstructorFeedbackItem>;
