import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  AudioUploadUrlRequest,
  TranscribeAudioRequest,
  AudioUploadUrlResponse,
  TranscribeAudioResponse,
  CreateReportRequest,
} from "@bjj/contract";

describe("report audio schemas", () => {
  it("accepts a report request with audioKeys", () => {
    const ok = { type: "bug", title: "Crash on open", description: "It crashes when I tap the map.", audioKeys: ["reports/audio/u1/a.m4a"] };
    expect(Value.Check(CreateReportRequest, ok)).toBe(true);
  });
  it("accepts a report request without audioKeys (optional)", () => {
    const ok = { type: "feature", title: "Dark mode", description: "Please add a dark theme." };
    expect(Value.Check(CreateReportRequest, ok)).toBe(true);
  });
  it("validates AudioUploadUrlRequest content type", () => {
    expect(Value.Check(AudioUploadUrlRequest, { contentType: "audio/mp4" })).toBe(true);
    expect(Value.Check(AudioUploadUrlRequest, { contentType: "video/mp4" })).toBe(false);
  });
  it("validates TranscribeAudioRequest", () => {
    expect(Value.Check(TranscribeAudioRequest, { audioKey: "reports/audio/u1/a.m4a" })).toBe(true);
    expect(Value.Check(TranscribeAudioRequest, { audioKey: "" })).toBe(false);
  });
  it("shapes the responses", () => {
    expect(Value.Check(AudioUploadUrlResponse, { uploadUrl: "https://s3/...", audioKey: "k" })).toBe(true);
    expect(Value.Check(TranscribeAudioResponse, { text: "hi", durationMs: 1200 })).toBe(true);
  });
});
