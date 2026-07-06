import { type Static, Type as t } from "@sinclair/typebox";

export const ReportType = t.Union([t.Literal("bug"), t.Literal("feature")], { $id: "ReportType" });
export type ReportType = Static<typeof ReportType>;
