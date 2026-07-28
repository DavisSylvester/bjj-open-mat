import { type Static, Type as t } from "@sinclair/typebox";

export const ClassRsvp = t.Object(
  {
    classId: t.String(),
    date: t.String(),
    userId: t.String(),
    rsvpAt: t.String(),
    isMember: t.Boolean(),
  },
  { $id: "ClassRsvp" },
);
export type ClassRsvp = Static<typeof ClassRsvp>;
