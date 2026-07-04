import { type Static, Type as t } from "@sinclair/typebox";
import { NotificationType } from "../enums/notification-type.mts";

export const Notification = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    type: NotificationType,
    title: t.String(),
    body: t.String(),
    read: t.Boolean({ default: false }),
    data: t.Optional(t.Record(t.String(), t.Unknown())),
    createdAt: t.String(),
  },
  { $id: "Notification" },
);
export type Notification = Static<typeof Notification>;
