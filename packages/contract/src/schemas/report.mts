import { type Static, Type as t } from "@sinclair/typebox";
import { ReportType } from "../enums/report-type.mts";

export const Report = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    type: ReportType,
    title: t.String(),
    description: t.String(),
    status: t.Literal("open", { default: "open" }),
    createdAt: t.String(),
    githubIssueNumber: t.Optional(t.Number()),
    githubIssueUrl: t.Optional(t.String()),
  },
  { $id: "Report" },
);
export type Report = Static<typeof Report>;
