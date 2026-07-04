import { type Static, Type as t } from "@sinclair/typebox";

export const NotificationListQuery = t.Object(
  {
    unread: t.Optional(t.Boolean()),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "NotificationListQuery" },
);
export type NotificationListQuery = Static<typeof NotificationListQuery>;
