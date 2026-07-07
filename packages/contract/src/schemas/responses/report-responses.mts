import { type Static, Type as t } from "@sinclair/typebox";

export const AudioUploadUrlResponse = t.Object(
  { uploadUrl: t.String(), audioKey: t.String() },
  { $id: "AudioUploadUrlResponse" },
);
export type AudioUploadUrlResponse = Static<typeof AudioUploadUrlResponse>;

export const TranscribeAudioResponse = t.Object(
  { text: t.String(), durationMs: t.Number() },
  { $id: "TranscribeAudioResponse" },
);
export type TranscribeAudioResponse = Static<typeof TranscribeAudioResponse>;
