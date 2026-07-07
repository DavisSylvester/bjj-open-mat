import { randomUUID } from "node:crypto";
import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { AppError } from "../http/errors.mts";

const UPLOAD_EXPIRY_SECONDS = 300;
const DOWNLOAD_EXPIRY_SECONDS = 300;

type IdFactory = () => string;

export interface AudioStorage {
  presignUpload(userId: string, contentType: string): Promise<{ uploadUrl: string; audioKey: string }>;
  getObject(key: string): Promise<Uint8Array>;
  signedDownloadUrl(key: string): Promise<string>;
}

/// Generates presigned S3 PUT/GET URLs for voice-report audio uploads under the
/// `reports/audio/<userId>/` prefix. Unlike gym-logo assets, audio objects are
/// never public — downloads always go through a short-lived signed GET URL.
export class S3AudioStorage implements AudioStorage {

  private readonly client: S3Client;

  public constructor(
    private readonly bucket: string,
    region: string,
    private readonly newId: IdFactory = randomUUID,
    client?: S3Client,
  ) {
    this.client = client ?? new S3Client({ region });
  }

  public async presignUpload(userId: string, contentType: string): Promise<{ uploadUrl: string; audioKey: string }> {
    const audioKey = `reports/audio/${userId}/${this.newId()}.m4a`;
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: audioKey, ContentType: contentType });
    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: UPLOAD_EXPIRY_SECONDS });
    return { uploadUrl, audioKey };
  }

  public async getObject(key: string): Promise<Uint8Array> {
    const res = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    return await res.Body!.transformToByteArray();
  }

  public async signedDownloadUrl(key: string): Promise<string> {
    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    return getSignedUrl(this.client, command, { expiresIn: DOWNLOAD_EXPIRY_SECONDS });
  }
}

/// Fallback used when no audio bucket is configured (e.g. local dev without
/// AWS). Any storage attempt fails with a clear, actionable error.
export class UnconfiguredAudioStorage implements AudioStorage {

  private fail(): never {
    throw new AppError("service_unavailable", "Audio storage is not configured (AUDIO_BUCKET unset)");
  }

  public async presignUpload(): Promise<{ uploadUrl: string; audioKey: string }> {
    this.fail();
  }

  public async getObject(): Promise<Uint8Array> {
    this.fail();
  }

  public async signedDownloadUrl(): Promise<string> {
    this.fail();
  }
}
