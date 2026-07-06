import { type Static, Type as t } from "@sinclair/typebox";
import { ReportType } from "../../enums/report-type.mts";

export const CreateReportRequest = t.Object(
  {
    type: ReportType,
    title: t.String({ minLength: 3, maxLength: 120 }),
    description: t.String({ minLength: 10, maxLength: 4000 }),
  },
  { $id: "CreateReportRequest" },
);
export type CreateReportRequest = Static<typeof CreateReportRequest>;
