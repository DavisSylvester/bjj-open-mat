import { type Static, Type as t } from "@sinclair/typebox";
import { MessageReportReason } from "../enums/message-report-reason.mts";
import { MessageReportStatus } from "../enums/message-report-status.mts";

export const MessageReport = t.Object(
  {
    id: t.String(),
    messageId: t.Optional(t.String()),
    reportedUserId: t.String(),
    reporterId: t.String(),
    gymId: t.String(),
    reason: MessageReportReason,
    note: t.Optional(t.String()),
    status: t.Union([MessageReportStatus], { default: "open" }),
    createdAt: t.Optional(t.String()),
    reviewedAt: t.Optional(t.String()),
  },
  { $id: "MessageReport" },
);
export type MessageReport = Static<typeof MessageReport>;
