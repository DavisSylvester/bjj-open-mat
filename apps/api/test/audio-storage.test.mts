import { describe, expect, it } from "bun:test";
import { S3Client } from "@aws-sdk/client-s3";
import { S3AudioStorage, UnconfiguredAudioStorage } from "../src/services/audio-storage.mts";
import { AppError } from "../src/http/errors.mts";

// Static creds keep getSignedUrl fully offline (signature is computed locally),
// regardless of whether the host has real AWS credentials configured.
function testClient(region: string): S3Client {
  return new S3Client({
    region,
    credentials: { accessKeyId: "AKIATEST", secretAccessKey: "secret" },
  });
}

describe("AudioStorage", () => {
  it("presigns an upload URL with a scoped key", async () => {
    const store = new S3AudioStorage("test-bucket", "us-east-1", () => "fixed-uuid", testClient("us-east-1"));
    const { uploadUrl, audioKey } = await store.presignUpload("user-1", "audio/mp4");
    expect(audioKey).toBe("reports/audio/user-1/fixed-uuid.m4a");
    expect(uploadUrl).toContain("test-bucket");
    expect(uploadUrl).toContain("fixed-uuid.m4a");
  });
  it("unconfigured storage throws service_unavailable", async () => {
    const store = new UnconfiguredAudioStorage();
    await expect(store.presignUpload("u", "audio/mp4")).rejects.toBeInstanceOf(AppError);
  });
});
