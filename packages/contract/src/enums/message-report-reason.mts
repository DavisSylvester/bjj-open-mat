import { type Static, Type as t } from "@sinclair/typebox";

export const MessageReportReason = t.Union(
  [t.Literal("spam"), t.Literal("harassment"), t.Literal("inappropriate"), t.Literal("other")],
  { $id: "MessageReportReason" },
);
export type MessageReportReason = Static<typeof MessageReportReason>;
