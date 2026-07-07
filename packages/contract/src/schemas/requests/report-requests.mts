import { type Static, Type as t } from "@sinclair/typebox";
import { ReportType } from "../../enums/report-type.mts";

export const CreateReportRequest = t.Object(
  {
    type: ReportType,
    title: t.String({ minLength: 3, maxLength: 120 }),
    description: t.String({ minLength: 10, maxLength: 4000 }),
    audioKeys: t.Optional(t.Array(t.String(), { maxItems: 20 })),
  },
  { $id: "CreateReportRequest" },
);
export type CreateReportRequest = Static<typeof CreateReportRequest>;

export const AudioUploadUrlRequest = t.Object(
  {
    contentType: t.Union([t.Literal("audio/mp4"), t.Literal("audio/m4a"), t.Literal("audio/aac")]),
  },
  { $id: "AudioUploadUrlRequest" },
);
export type AudioUploadUrlRequest = Static<typeof AudioUploadUrlRequest>;

export const TranscribeAudioRequest = t.Object(
  { audioKey: t.String({ minLength: 1 }) },
  { $id: "TranscribeAudioRequest" },
);
export type TranscribeAudioRequest = Static<typeof TranscribeAudioRequest>;
