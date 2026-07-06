import { randomUUID } from "node:crypto";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import type { LogoContentType } from "@bjj/contract";
import { AppError } from "../http/errors.mts";

export interface PresignedUpload {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

const EXTENSION_BY_TYPE: Record<LogoContentType, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};

const UPLOAD_EXPIRY_SECONDS = 300;

export interface AssetStorage {
  presignLogoUpload(ownerId: string, contentType: LogoContentType): Promise<PresignedUpload>;
}

/// Generates presigned S3 PUT URLs for gym logo uploads. The bucket serves the
/// `logos/*` prefix as public-read, so the returned publicUrl is stable and
/// never expires.
export class S3AssetStorage implements AssetStorage {

  private readonly client: S3Client;

  public constructor(
    private readonly bucket: string,
    private readonly region: string,
    client?: S3Client,
  ) {
    this.client = client ?? new S3Client({ region });
  }

  public async presignLogoUpload(ownerId: string, contentType: LogoContentType): Promise<PresignedUpload> {
    const ext = EXTENSION_BY_TYPE[contentType];
    const key = `logos/${ownerId}/${randomUUID()}.${ext}`;
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType });
    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: UPLOAD_EXPIRY_SECONDS });
    const publicUrl = `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}`;
    return { uploadUrl, publicUrl, key };
  }
}

/// Fallback used when no assets bucket is configured (e.g. local dev without
/// AWS). Any upload attempt fails with a clear, actionable error.
export class UnconfiguredAssetStorage implements AssetStorage {

  public presignLogoUpload(): Promise<PresignedUpload> {
    throw new AppError("service_unavailable", "Logo uploads are not configured (ASSETS_BUCKET unset)");
  }
}
