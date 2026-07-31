import { type Static, Type as t } from "@sinclair/typebox";

export const MessageReportStatus = t.Union(
  [t.Literal("open"), t.Literal("reviewed"), t.Literal("dismissed")],
  { $id: "MessageReportStatus" },
);
export type MessageReportStatus = Static<typeof MessageReportStatus>;
