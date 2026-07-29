import { type Static, Type as t } from "@sinclair/typebox";

export const NotificationType = t.Union(
  [
    t.Literal("rsvp"),
    t.Literal("review"),
    t.Literal("session_update"),
    t.Literal("system"),
    t.Literal("forum_answer"),
    t.Literal("forum_accepted"),
  ],
  { $id: "NotificationType" },
);
export type NotificationType = Static<typeof NotificationType>;
