import { describe, expect, it } from "bun:test";
import { S3Client } from "@aws-sdk/client-s3";
import { S3AssetStorage, UnconfiguredAssetStorage } from "../src/services/asset-storage.mts";
import { AppError } from "../src/http/errors.mts";

// Static creds keep getSignedUrl fully offline (signature is computed locally).
function testClient(region: string): S3Client {
  return new S3Client({
    region,
    credentials: { accessKeyId: "AKIATEST", secretAccessKey: "secret" },
  });
}

describe("S3AssetStorage", () => {
  it("presigns a PUT under logos/<ownerId>/ with the right extension and public URL", async () => {
    const storage = new S3AssetStorage("bjj-assets", "us-east-1", testClient("us-east-1"));
    const res = await storage.presignLogoUpload("owner-1", "image/png");

    expect(res.key.startsWith("logos/owner-1/")).toBe(true);
    expect(res.key.endsWith(".png")).toBe(true);
    expect(res.publicUrl).toBe(`https://bjj-assets.s3.us-east-1.amazonaws.com/${res.key}`);
    expect(res.uploadUrl.startsWith("https://bjj-assets.s3.us-east-1.amazonaws.com/")).toBe(true);
    expect(res.uploadUrl).toContain("X-Amz-Signature");
  });

  it("maps jpeg content type to a .jpg extension", async () => {
    const storage = new S3AssetStorage("bjj-assets", "us-east-1", testClient("us-east-1"));
    const res = await storage.presignLogoUpload("owner-2", "image/jpeg");
    expect(res.key.endsWith(".jpg")).toBe(true);
  });

  it("generates a distinct key per call", async () => {
    const storage = new S3AssetStorage("bjj-assets", "us-east-1", testClient("us-east-1"));
    const a = await storage.presignLogoUpload("owner-1", "image/webp");
    const b = await storage.presignLogoUpload("owner-1", "image/webp");
    expect(a.key).not.toBe(b.key);
  });
});

describe("UnconfiguredAssetStorage", () => {
  it("rejects uploads with a service_unavailable AppError", () => {
    const storage = new UnconfiguredAssetStorage();
    expect(() => storage.presignLogoUpload()).toThrow(AppError);
    try {
      storage.presignLogoUpload();
    } catch (e) {
      expect((e as AppError).code).toBe("service_unavailable");
    }
  });
});
