# Voice-to-text Bug/Feature Report — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users fill a bug/feature report's Description by speaking; the app uploads the raw audio to S3 via a presigned URL and the backend transcribes+translates it to English (OpenAI Whisper), appending the text into the still-editable Description. Title stays typed.

**Architecture:** Presigned S3 upload (matches the gym-logo pattern) → transcribe-by-key endpoint that reads the object from S3 and calls Whisper → report persists the audio object keys. Injectable, optional external services (`AudioStorage`, `TranscriptionService`) wired in `container.mts` and consumed by `ReportFacade`. Contract changes flow through TypeBox schemas.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (`apps/api`), Flutter + Riverpod + Dio + `record` (`apps/mobile`), `@bjj/contract` (TypeBox, `.mts`), `@aws-sdk/client-s3` + `@aws-sdk/s3-request-presigner` (already present), OpenAI Whisper via `fetch`.

## Global Constraints

- All API + contract files use the **`.mts`** extension; imports include the full `.mts` specifier. tsconfig is `noEmit`; no build step.
- Contract validation uses **TypeBox** (`Type as t`, `Static`), each schema has a `$id`, exported via barrels; consumed as `import { X } from "@bjj/contract"`.
- Backend logging uses **Winston**; **no `console.*`** in `apps/api`.
- Backend layering: route handler → **`ReportFacade`** → repository/services. No `new` in routes; services resolved from `container.mts`. External services are **injectable and optional** (`null`/`Unconfigured…` when their env is unset), mirroring `HttpGitHubIssueService` / `S3AssetStorage`.
- URL prefix is per-module: reports live under **`/api/v1/reports`**.
- Report field limits (unchanged): `title` 3–120, `description` 10–4000. `audioKeys` max 20.
- Transcription is **always translate-to-English** (Whisper `/v1/audio/translations`, model `whisper-1`).
- Recording cap: **~120 s / ≤ 24 MB**, AAC/`.m4a`.
- **Audio is admin/debug-only** — never surfaced to end users; private S3, signed URLs only.
- Tests: API via `bun test` (route tests need Mongo at `mongodb://localhost:27017`); mobile via `flutter test`.
- Feature branch: `feature/voice-report` (this plan is authored on `feature/voice-report-spec`; create the impl branch off latest `main`).

---

### Task 1: Contract schemas (audioKeys + audio endpoints)

**Files:**
- Modify: `packages/contract/src/schemas/requests/report-requests.mts`
- Modify: `packages/contract/src/schemas/report.mts`
- Create: `packages/contract/src/schemas/responses/report-responses.mts`
- Modify: `packages/contract/src/schemas/responses/index.mts` (barrel)
- Test: `packages/contract/test/report-audio-schemas.test.mts`

**Interfaces:**
- Produces: `CreateReportRequest` (now with optional `audioKeys: string[]`), `AudioUploadUrlRequest { contentType }`, `TranscribeAudioRequest { audioKey }`, `AudioUploadUrlResponse { uploadUrl, audioKey }`, `TranscribeAudioResponse { text, durationMs }`, `Report` (now with optional `audioKeys`). All exported from `@bjj/contract`.

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/report-audio-schemas.test.mts`:
```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test ../../packages/contract/test/report-audio-schemas.test.mts`
Expected: FAIL — `AudioUploadUrlRequest`/`TranscribeAudioRequest`/response schemas are not exported yet.

- [ ] **Step 3: Add the request schemas**

In `packages/contract/src/schemas/requests/report-requests.mts`, add `audioKeys` to `CreateReportRequest` and append the two new request schemas:
```ts
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
```

- [ ] **Step 4: Add the response schemas + barrel**

Create `packages/contract/src/schemas/responses/report-responses.mts`:
```ts
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
```
Append to `packages/contract/src/schemas/responses/index.mts`:
```ts
export * from "./report-responses.mts";
```

- [ ] **Step 5: Add audioKeys to the Report schema**

In `packages/contract/src/schemas/report.mts`, add to the `Report` object (after `createdAt`):
```ts
    audioKeys: t.Optional(t.Array(t.String())),
```

- [ ] **Step 6: Run tests + type-check to verify they pass**

Run: `cd apps/api && bun test ../../packages/contract/test/report-audio-schemas.test.mts`
Expected: PASS (all 5)
Run: `cd packages/contract && bun run type-check`
Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add packages/contract/src packages/contract/test/report-audio-schemas.test.mts
git commit -m "feat(contract): audioKeys on reports + audio upload/transcribe schemas"
```

---

### Task 2: API config — audio + OpenAI env vars

**Files:**
- Modify: `apps/api/src/config/env.mts`
- Test: `apps/api/test/env-audio.test.mts`

**Interfaces:**
- Produces: `AppEnv` gains `openaiApiKey: string | undefined`, `audioBucket: string | undefined`, `audioRegion: string`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/env-audio.test.mts`:
```ts
import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

const base = {
  MONGODB_URI: "mongodb://localhost:27017", MONGODB_DB: "x",
  AUTH_BYPASS_SECRET: "s", DEMO_USER_ID: "d", DEMO_USER_ROLE: "practitioner", DEMO_USER_EMAIL: "d@d.dev",
};

describe("audio/openai env", () => {
  it("defaults audio settings when unset", () => {
    const env = loadEnv(base);
    expect(env.openaiApiKey).toBeUndefined();
    expect(env.audioBucket).toBeUndefined();
    expect(env.audioRegion).toBe("us-east-1");
  });
  it("reads audio settings when set", () => {
    const env = loadEnv({ ...base, OPENAI_API_KEY: "sk-1", AUDIO_BUCKET: "b", AUDIO_REGION: "us-west-2" });
    expect(env.openaiApiKey).toBe("sk-1");
    expect(env.audioBucket).toBe("b");
    expect(env.audioRegion).toBe("us-west-2");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/env-audio.test.mts`
Expected: FAIL — `openaiApiKey`/`audioBucket`/`audioRegion` do not exist on `AppEnv`.

- [ ] **Step 3: Add the env fields**

In `apps/api/src/config/env.mts`: add to `EnvSchema`:
```ts
  OPENAI_API_KEY: t.Optional(t.String()),
  AUDIO_BUCKET: t.Optional(t.String()),
  AUDIO_REGION: t.Optional(t.String()),
```
Add to the `AppEnv` interface:
```ts
  readonly openaiApiKey: string | undefined;
  readonly audioBucket: string | undefined;
  readonly audioRegion: string;
```
Map in the `loadEnv` return object:
```ts
    openaiApiKey: raw.OPENAI_API_KEY,
    audioBucket: raw.AUDIO_BUCKET,
    audioRegion: raw.AUDIO_REGION ?? raw.ASSETS_REGION ?? "us-east-1",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/env-audio.test.mts`
Expected: PASS (2)

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/config/env.mts apps/api/test/env-audio.test.mts
git commit -m "feat(api): OPENAI_API_KEY + AUDIO_BUCKET/AUDIO_REGION env config"
```

---

### Task 3: API `AudioStorage` service (presign + get)

**Files:**
- Create: `apps/api/src/services/audio-storage.mts`
- Test: `apps/api/test/audio-storage.test.mts`
- Reference (read for pattern): `apps/api/src/services/asset-storage.mts`, `apps/api/src/http/errors.mts`

**Interfaces:**
- Produces: `interface AudioStorage { presignUpload(userId: string, contentType: string): Promise<{ uploadUrl: string; audioKey: string }>; getObject(key: string): Promise<Uint8Array>; signedDownloadUrl(key: string): Promise<string>; }`, `class S3AudioStorage implements AudioStorage`, `class UnconfiguredAudioStorage implements AudioStorage`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/audio-storage.test.mts`:
```ts
import { describe, expect, it } from "bun:test";
import { S3AudioStorage, UnconfiguredAudioStorage } from "../src/services/audio-storage.mts";
import { AppError } from "../src/http/errors.mts";

describe("AudioStorage", () => {
  it("presigns an upload URL with a scoped key", async () => {
    const store = new S3AudioStorage("test-bucket", "us-east-1", () => "fixed-uuid");
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/audio-storage.test.mts`
Expected: FAIL — module `audio-storage.mts` does not exist.

- [ ] **Step 3: Implement the service**

Create `apps/api/src/services/audio-storage.mts`:
```ts
import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "node:crypto";
import { AppError } from "../http/errors.mts";

export interface AudioStorage {
  presignUpload(userId: string, contentType: string): Promise<{ uploadUrl: string; audioKey: string }>;
  getObject(key: string): Promise<Uint8Array>;
  signedDownloadUrl(key: string): Promise<string>;
}

type IdFactory = () => string;

export class S3AudioStorage implements AudioStorage {
  private readonly s3: S3Client;
  public constructor(
    private readonly bucket: string,
    region: string,
    private readonly newId: IdFactory = randomUUID,
  ) {
    this.s3 = new S3Client({ region });
  }

  public async presignUpload(userId: string, contentType: string): Promise<{ uploadUrl: string; audioKey: string }> {
    const audioKey = `reports/audio/${userId}/${this.newId()}.m4a`;
    const cmd = new PutObjectCommand({ Bucket: this.bucket, Key: audioKey, ContentType: contentType });
    const uploadUrl = await getSignedUrl(this.s3, cmd, { expiresIn: 300 });
    return { uploadUrl, audioKey };
  }

  public async getObject(key: string): Promise<Uint8Array> {
    const res = await this.s3.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    return await res.Body!.transformToByteArray();
  }

  public async signedDownloadUrl(key: string): Promise<string> {
    return getSignedUrl(this.s3, new GetObjectCommand({ Bucket: this.bucket, Key: key }), { expiresIn: 300 });
  }
}

export class UnconfiguredAudioStorage implements AudioStorage {
  private fail(): never {
    throw new AppError("service_unavailable", "Audio storage is not configured (AUDIO_BUCKET unset)");
  }
  public async presignUpload(): Promise<{ uploadUrl: string; audioKey: string }> { this.fail(); }
  public async getObject(): Promise<Uint8Array> { this.fail(); }
  public async signedDownloadUrl(): Promise<string> { this.fail(); }
}
```

> Verify the `AppError` constructor signature against `apps/api/src/http/errors.mts` (code, message) and match `UnconfiguredAssetStorage`'s exact usage in `asset-storage.mts`. Adjust the error code string if that file uses a different one.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/audio-storage.test.mts`
Expected: PASS (2). (`getSignedUrl` signs locally; no network needed.)

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/services/audio-storage.mts apps/api/test/audio-storage.test.mts
git commit -m "feat(api): S3AudioStorage presign + get for report audio"
```

---

### Task 4: API `TranscriptionService` (Whisper translate)

**Files:**
- Create: `apps/api/src/services/transcription.mts`
- Test: `apps/api/test/transcription.test.mts`
- Reference (read for pattern): `apps/api/src/services/github-issue.mts`

**Interfaces:**
- Produces: `interface TranscriptionService { translateToEnglish(audio: Uint8Array, filename: string): Promise<{ text: string; durationMs: number }>; }`, `class WhisperTranscriptionService implements TranscriptionService` (constructor `(apiKey: string, fetchFn?: typeof fetch)`).

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/transcription.test.mts`:
```ts
import { describe, expect, it } from "bun:test";
import { WhisperTranscriptionService } from "../src/services/transcription.mts";

describe("WhisperTranscriptionService", () => {
  it("posts audio to the translations endpoint and returns text", async () => {
    let calledUrl = ""; let auth = "";
    const fakeFetch = (async (url: string, init: RequestInit) => {
      calledUrl = String(url);
      auth = String((init.headers as Record<string, string>)["Authorization"]);
      return new Response(JSON.stringify({ text: "hello in english" }), { status: 200 });
    }) as unknown as typeof fetch;

    const svc = new WhisperTranscriptionService("sk-test", fakeFetch);
    const out = await svc.translateToEnglish(new Uint8Array([1, 2, 3]), "audio.m4a");

    expect(calledUrl).toBe("https://api.openai.com/v1/audio/translations");
    expect(auth).toBe("Bearer sk-test");
    expect(out.text).toBe("hello in english");
    expect(out.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("throws on a non-200 response", async () => {
    const fakeFetch = (async () => new Response("bad", { status: 500 })) as unknown as typeof fetch;
    const svc = new WhisperTranscriptionService("sk-test", fakeFetch);
    await expect(svc.translateToEnglish(new Uint8Array([1]), "a.m4a")).rejects.toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/transcription.test.mts`
Expected: FAIL — module `transcription.mts` does not exist.

- [ ] **Step 3: Implement the service**

Create `apps/api/src/services/transcription.mts`:
```ts
export interface TranscriptionService {
  translateToEnglish(audio: Uint8Array, filename: string): Promise<{ text: string; durationMs: number }>;
}

export class WhisperTranscriptionService implements TranscriptionService {
  public constructor(
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  public async translateToEnglish(audio: Uint8Array, filename: string): Promise<{ text: string; durationMs: number }> {
    const started = performance.now();
    const form = new FormData();
    form.append("file", new Blob([audio], { type: "audio/mp4" }), filename);
    form.append("model", "whisper-1");
    const res = await this.fetchFn("https://api.openai.com/v1/audio/translations", {
      method: "POST",
      headers: { Authorization: `Bearer ${this.apiKey}` },
      body: form,
    });
    if (!res.ok) {
      throw new Error(`Whisper translation failed: ${res.status}`);
    }
    const json = (await res.json()) as { text: string };
    return { text: json.text ?? "", durationMs: Math.round(performance.now() - started) };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/transcription.test.mts`
Expected: PASS (2)

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/services/transcription.mts apps/api/test/transcription.test.mts
git commit -m "feat(api): WhisperTranscriptionService (translate audio to English)"
```

---

### Task 5: API `ReportFacade` — persist audioKeys + transcribe()

**Files:**
- Modify: `apps/api/src/facades/report.facade.mts`
- Test: `apps/api/test/report-facade-audio.test.mts`
- Reference: `apps/api/test/report-facade.test.mts` (fake-object test style)

**Interfaces:**
- Consumes: `AudioStorage` (Task 3), `TranscriptionService` (Task 4), contract `Report`/`CreateReportRequest` (Task 1).
- Produces: `ReportFacade` constructor now also takes `audio: AudioStorage | null` and `transcription: TranscriptionService | null`; `create` persists `audioKeys`; new method `transcribe(userId: string, audioKey: string): Promise<{ text: string; durationMs: number }>`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/report-facade-audio.test.mts`:
```ts
import { describe, expect, it } from "bun:test";
import { ReportFacade } from "../src/facades/report.facade.mts";
import type { ReportRepository } from "../src/repositories/report.repository.mts";
import type { Report } from "@bjj/contract";

type FakeRepo = Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser" | "ensureIndexes">;
function repo(): { fake: FakeRepo; store: Map<string, Report> } {
  const store = new Map<string, Report>();
  const fake: FakeRepo = {
    insert: async (r) => { store.set(r.id, r); return r; },
    update: async (id, patch) => { const cur = store.get(id); if (!cur) return null; const next = { ...cur, ...patch }; store.set(id, next); return next; },
    findById: async (id) => store.get(id) ?? null,
    listByUser: async (u) => [...store.values()].filter((r) => r.userId === u),
    ensureIndexes: async () => {},
  };
  return { fake, store };
}
const nextId = (): string => "r-1";

describe("ReportFacade audio", () => {
  it("persists audioKeys on create", async () => {
    const { fake, store } = repo();
    const facade = new ReportFacade(fake, null, null, null, nextId, "owner/repo");
    await facade.create("u-1", { type: "bug", title: "Crash bug", description: "Crashes on the map screen.", audioKeys: ["reports/audio/u-1/a.m4a"] });
    expect(store.get("r-1")?.audioKeys).toEqual(["reports/audio/u-1/a.m4a"]);
  });

  it("transcribe reads audio and returns English text", async () => {
    const { fake } = repo();
    const audio = { presignUpload: async () => ({ uploadUrl: "", audioKey: "" }), getObject: async () => new Uint8Array([1]), signedDownloadUrl: async () => "" };
    const transcription = { translateToEnglish: async () => ({ text: "hola -> hello", durationMs: 5 }) };
    const facade = new ReportFacade(fake, null, audio, transcription, nextId, "owner/repo");
    const out = await facade.transcribe("u-1", "reports/audio/u-1/a.m4a");
    expect(out.text).toBe("hola -> hello");
  });

  it("transcribe throws when transcription is not configured", async () => {
    const { fake } = repo();
    const facade = new ReportFacade(fake, null, null, null, nextId, "owner/repo");
    await expect(facade.transcribe("u-1", "k")).rejects.toBeDefined();
  });
});
```

> Note: the ReportFacade constructor arg order below is `(reports, issues, audio, transcription, newId, repo)`. If the existing constructor differs, keep the existing args and append `audio`/`transcription` in a consistent position — then update this test and Task 6's `container.mts` wiring to match.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/report-facade-audio.test.mts`
Expected: FAIL — constructor arity mismatch / `transcribe` undefined.

- [ ] **Step 3: Modify the facade**

In `apps/api/src/facades/report.facade.mts`:
- Import the new service types:
```ts
import type { AudioStorage } from "../services/audio-storage.mts";
import type { TranscriptionService } from "../services/transcription.mts";
import { AppError } from "../http/errors.mts";
```
- Extend the constructor (insert `audio` + `transcription` before `newId`):
```ts
  public constructor(
    private readonly reports: Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser">,
    private readonly issues: GitHubIssueService | null,
    private readonly audio: AudioStorage | null,
    private readonly transcription: TranscriptionService | null,
    private readonly newId: IdFactory,
    private readonly repo: string,
  ) {}
```
- In `create`, persist `audioKeys` on the built report object:
```ts
      audioKeys: req.audioKeys ?? [],
```
- Add the method:
```ts
  public async transcribe(_userId: string, audioKey: string): Promise<{ text: string; durationMs: number }> {
    if (!this.audio || !this.transcription) {
      throw new AppError("service_unavailable", "Voice transcription is not configured");
    }
    const bytes = await this.audio.getObject(audioKey);
    return this.transcription.translateToEnglish(bytes, "audio.m4a");
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/report-facade-audio.test.mts`
Expected: PASS (3)

- [ ] **Step 5: Run the existing facade test (guard against regressions)**

Run: `cd apps/api && bun test test/report-facade.test.mts`
Expected: FAIL if it constructs `ReportFacade` with the old arity — update those `new ReportFacade(...)` calls to pass `null, null` for `audio, transcription`. Re-run until PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/report.facade.mts apps/api/test/report-facade-audio.test.mts apps/api/test/report-facade.test.mts
git commit -m "feat(api): ReportFacade persists audioKeys + transcribe(audioKey)"
```

---

### Task 6: API — container wiring + audio routes

**Files:**
- Modify: `apps/api/src/container.mts`
- Modify: `apps/api/src/routes/report.routes.mts`
- Test: `apps/api/test/report-audio-routes.test.mts`
- Reference: `apps/api/test/report-routes.test.mts` (route test harness), `apps/api/src/routes/gym.routes.mts` (presign route)

**Interfaces:**
- Consumes: `ReportFacade` (Task 5), `S3AudioStorage`/`UnconfiguredAudioStorage` (Task 3), `WhisperTranscriptionService` (Task 4), env fields (Task 2), contract schemas (Task 1).

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/report-audio-routes.test.mts` (mirrors `report-routes.test.mts` harness):
```ts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_report_audio_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: TEST_DB, AUTH_BYPASS_SECRET: "secret-x",
  DEMO_USER_ID: "demo", DEMO_USER_ROLE: "practitioner", DEMO_USER_EMAIL: "d@d.dev" });
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>; let base: string;

beforeAll(async () => {
  await client.connect();
  const c = createContainer(client.db(TEST_DB), env);
  await c.ensureIndexes();
  app = buildApp(c).listen(0);
  base = `http://localhost:${app.server?.port}`;
});
afterAll(async () => { app.stop(); await client.db(TEST_DB).dropDatabase(); await client.close(); });

describe("report audio routes", () => {
  it("persists audioKeys on create", async () => {
    const res = await fetch(`${base}/api/v1/reports`, { method: "POST", headers: auth,
      body: JSON.stringify({ type: "bug", title: "Map crash", description: "Crashes when I open the map.", audioKeys: ["reports/audio/demo/a.m4a"] }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.audioKeys).toEqual(["reports/audio/demo/a.m4a"]);
  });

  it("audio-upload-url returns 503 when AUDIO_BUCKET is unset", async () => {
    const res = await fetch(`${base}/api/v1/reports/audio-upload-url`, { method: "POST", headers: auth,
      body: JSON.stringify({ contentType: "audio/mp4" }) });
    // Unconfigured audio storage -> AppError service_unavailable
    expect(res.status).toBe(503);
  });
});
```

> Confirm the HTTP status `AppError("service_unavailable", …)` maps to in `apps/api/src/http/errors.mts` (likely 503). If it maps to a different code, update the expectation.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/report-audio-routes.test.mts`
Expected: FAIL — routes 404 / container doesn't build the audio deps.

- [ ] **Step 3: Wire the container**

In `apps/api/src/container.mts`:
```ts
import { S3AudioStorage, UnconfiguredAudioStorage, type AudioStorage } from "./services/audio-storage.mts";
import { WhisperTranscriptionService, type TranscriptionService } from "./services/transcription.mts";
```
Inside `createContainer`, before building `reportFacade`:
```ts
  const audioStorage: AudioStorage = env.audioBucket
    ? new S3AudioStorage(env.audioBucket, env.audioRegion)
    : new UnconfiguredAudioStorage();
  const transcription: TranscriptionService | null = env.openaiApiKey
    ? new WhisperTranscriptionService(env.openaiApiKey)
    : null;
```
Update the facade construction to pass them (match Task 5 arg order):
```ts
    reportFacade: new ReportFacade(reportRepo, githubIssueService, audioStorage, transcription, id, env.githubRepo),
```
Add `readonly audioStorage: AudioStorage;` to the `Container` interface and include `audioStorage` in the returned object (routes need it for the presign endpoint).

- [ ] **Step 4: Add the routes**

In `apps/api/src/routes/report.routes.mts`:
- Import the request schemas:
```ts
import { CreateReportRequest, AudioUploadUrlRequest, TranscribeAudioRequest } from "@bjj/contract";
```
- Destructure `const { reportFacade, audioStorage } = container;`
- Add two routes to the returned Elysia chain:
```ts
    .post(
      "/audio-upload-url",
      async ({ identity, body }) => data(await audioStorage.presignUpload(requireId(identity).userId, body.contentType)),
      { requireAuth: true, body: AudioUploadUrlRequest },
    )
    .post(
      "/transcribe",
      async ({ identity, body }) => data(await reportFacade.transcribe(requireId(identity).userId, body.audioKey)),
      { requireAuth: true, body: TranscribeAudioRequest },
    )
```

- [ ] **Step 5: Run tests to verify they pass**

Run (Mongo must be running): `cd apps/api && bun test test/report-audio-routes.test.mts`
Expected: PASS (2)
Run the full suite: `cd apps/api && bun run verify`
Expected: type-check + lint + tests all pass.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/container.mts apps/api/src/routes/report.routes.mts apps/api/test/report-audio-routes.test.mts
git commit -m "feat(api): audio-upload-url + transcribe routes; wire audio/transcription in container"
```

---

### Task 7: Mobile — model, endpoints, repositories

**Files:**
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Modify: `apps/mobile/lib/features/report/models/report.dart`
- Modify: `apps/mobile/lib/features/report/data/report_repository.dart`
- Create: `apps/mobile/lib/features/report/data/report_audio_repository.dart`
- Test: `apps/mobile/test/features/report_audio_repository_test.dart`
- Modify: `apps/mobile/pubspec.yaml` (add `record`)

**Interfaces:**
- Produces: `ReportAudioRepository` with `Future<({String uploadUrl, String audioKey})> presignUpload(String contentType)`, `Future<void> putAudio(String uploadUrl, File file, String contentType)`, `Future<({String text, int durationMs})> transcribe(String audioKey)`; `reportAudioRepositoryProvider`. `ReportRepository.create` gains `List<String> audioKeys`.

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/features/report_audio_repository_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/report/data/report_audio_repository.dart';

void main() {
  test('presignUpload returns url + key', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final mock = DioAdapter(dio: dio);
    mock.onPost('/api/v1/reports/audio-upload-url',
      (s) => s.reply(200, {'data': {'uploadUrl': 'https://s3/put', 'audioKey': 'reports/audio/u/a.m4a'}}),
      data: {'contentType': 'audio/mp4'});
    final repo = ApiReportAudioRepository(dio);
    final r = await repo.presignUpload('audio/mp4');
    expect(r.uploadUrl, 'https://s3/put');
    expect(r.audioKey, 'reports/audio/u/a.m4a');
  });

  test('transcribe returns english text', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final mock = DioAdapter(dio: dio);
    mock.onPost('/api/v1/reports/transcribe',
      (s) => s.reply(200, {'data': {'text': 'hello', 'durationMs': 1200}}),
      data: {'audioKey': 'reports/audio/u/a.m4a'});
    final repo = ApiReportAudioRepository(dio);
    final r = await repo.transcribe('reports/audio/u/a.m4a');
    expect(r.text, 'hello');
    expect(r.durationMs, 1200);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/features/report_audio_repository_test.dart`
Expected: FAIL — `report_audio_repository.dart` does not exist.

- [ ] **Step 3: Add endpoints + audio repository + record dep**

In `apps/mobile/lib/core/api/endpoints.dart`, under `// Reports`:
```dart
  static const String reportAudioUploadUrl = '/api/v1/reports/audio-upload-url';
  static const String reportTranscribe = '/api/v1/reports/transcribe';
```
In `apps/mobile/pubspec.yaml` dependencies add:
```yaml
  record: ^5.1.2
```
Create `apps/mobile/lib/features/report/data/report_audio_repository.dart`:
```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';

abstract class ReportAudioRepository {
  Future<({String uploadUrl, String audioKey})> presignUpload(String contentType);
  Future<void> putAudio(String uploadUrl, File file, String contentType);
  Future<({String text, int durationMs})> transcribe(String audioKey);
}

class ApiReportAudioRepository implements ReportAudioRepository {
  final Dio _dio;
  ApiReportAudioRepository(this._dio);

  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String contentType) async {
    try {
      final res = await _dio.post(Endpoints.reportAudioUploadUrl, data: {'contentType': contentType});
      final d = unwrapData(res.data as Map<String, dynamic>);
      return (uploadUrl: d['uploadUrl'] as String, audioKey: d['audioKey'] as String);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> putAudio(String uploadUrl, File file, String contentType) async {
    final bytes = await file.readAsBytes();
    // Raw PUT straight to S3 (no auth interceptor) — use a bare Dio.
    await Dio().put(uploadUrl, data: Stream.fromIterable([bytes]),
        options: Options(headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        }));
  }

  @override
  Future<({String text, int durationMs})> transcribe(String audioKey) async {
    try {
      final res = await _dio.post(Endpoints.reportTranscribe, data: {'audioKey': audioKey});
      final d = unwrapData(res.data as Map<String, dynamic>);
      return (text: d['text'] as String, durationMs: (d['durationMs'] as num).toInt());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final reportAudioRepositoryProvider = Provider<ReportAudioRepository>(
  (ref) => ApiReportAudioRepository(ref.read(apiClientProvider).dio),
);
```

- [ ] **Step 4: Add audioKeys to the report model + create()**

In `apps/mobile/lib/features/report/models/report.dart`: add field `final List<String> audioKeys;`, add to constructor `this.audioKeys = const []`, and in `fromJson`: `audioKeys: (json['audioKeys'] as List?)?.map((e) => e as String).toList() ?? const [],`.
In `apps/mobile/lib/features/report/data/report_repository.dart`, change the `create` signature and body:
```dart
  Future<Report> create({
    required String type,
    required String title,
    required String description,
    List<String> audioKeys = const [],
  });
```
and in `ApiReportRepository.create` add `'audioKeys': audioKeys,` to the POST `data` map (keep `type`, `title`, `description`).

- [ ] **Step 5: Run tests + pub get to verify they pass**

Run: `cd apps/mobile && flutter pub get && flutter test test/features/report_audio_repository_test.dart`
Expected: PASS (2)

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/core/api/endpoints.dart apps/mobile/lib/features/report/ apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/test/features/report_audio_repository_test.dart
git commit -m "feat(mobile): report audio repository + audioKeys on report model/create"
```

---

### Task 8: Mobile — recording UI on the Report screen

**Files:**
- Modify: `apps/mobile/lib/features/report/screens/report_screen.dart`
- Modify: `apps/mobile/ios/Runner/Info.plist` (mic usage string)
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml` (RECORD_AUDIO)
- Test: `apps/mobile/test/features/report_screen_audio_test.dart`

**Interfaces:**
- Consumes: `reportAudioRepositoryProvider`, `reportRepositoryProvider` (with `audioKeys`).
- Produces: recording state on `_ReportScreenState`; Submit passes `audioKeys: _audioKeys`.

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/features/report_screen_audio_test.dart` — override the audio repo with a fake that returns a fixed transcript, drive the mic action programmatically, and assert the description got the text and submit carries the key. (Because the `record` plugin can't run in a widget test, the screen must call recording through an injectable seam; introduce a `RecorderController` abstraction with a fake in the test.)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/report/data/report_audio_repository.dart';
import 'package:bjj_open_mat/features/report/data/report_repository.dart';
import 'package:bjj_open_mat/features/report/models/report.dart';
import 'package:bjj_open_mat/features/report/screens/report_screen.dart';

class _FakeAudioRepo implements ReportAudioRepository {
  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String c) async => (uploadUrl: 'u', audioKey: 'reports/audio/u/a.m4a');
  @override
  Future<void> putAudio(String u, dynamic f, String c) async {}
  @override
  Future<({String text, int durationMs})> transcribe(String k) async => (text: 'transcribed text', durationMs: 1000);
}

class _CapturingReportRepo implements ReportRepository {
  List<String>? lastAudioKeys;
  @override
  Future<Report> create({required String type, required String title, required String description, List<String> audioKeys = const []}) async {
    lastAudioKeys = audioKeys;
    return Report(id: 'r1', userId: 'u', type: type, title: title, description: description, status: 'open');
  }
  @override
  Future<List<Report>> listMine() async => [];
}

void main() {
  testWidgets('spoken text appends to description and submit carries audioKeys', (tester) async {
    final capture = _CapturingReportRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportAudioRepositoryProvider.overrideWithValue(_FakeAudioRepo()),
        reportRepositoryProvider.overrideWithValue(capture),
      ],
      child: const MaterialApp(home: ReportScreen()),
    ));
    // Drive the recording seam directly (test hook exposed on the state).
    final state = tester.state<ReportScreenStateForTest>(find.byType(ReportScreen));
    await state.debugSimulateRecordingWithKey('reports/audio/u/a.m4a');
    await tester.pump();
    expect(find.textContaining('transcribed text'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('report-title')), 'A valid title');
    await state.debugSubmit();
    expect(capture.lastAudioKeys, ['reports/audio/u/a.m4a']);
  });
}
```

> This task introduces the minimal test seams named above (`ReportScreenStateForTest` typedef on the state, `debugSimulateRecordingWithKey`, `debugSubmit`, and a `Key('report-title')` on the title field). Keep the seams `@visibleForTesting`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/features/report_screen_audio_test.dart`
Expected: FAIL — seams/keys don't exist; description doesn't append.

- [ ] **Step 3: Implement the recording flow on the screen**

In `report_screen.dart`:
- Add state: `final List<String> _audioKeys = [];` and an enum `RecordState { idle, recording, transcribing, error }` field `_rec = RecordState.idle;`.
- Add a **mic `IconButton`** in the Description section header. On tap (idle→recording) start `AudioRecorder().start(const RecordConfig(encoder: AudioEncoder.aacLc), path: <temp>.m4a)`; on tap (recording→transcribing) `stop()`, then:
  ```dart
  final audio = ref.read(reportAudioRepositoryProvider);
  final pre = await audio.presignUpload('audio/mp4');
  await audio.putAudio(pre.uploadUrl, File(path), 'audio/mp4');
  final t = await audio.transcribe(pre.audioKey);
  setState(() {
    final sep = _descCtrl.text.trim().isEmpty ? '' : '\n\n';
    _descCtrl.text = '${_descCtrl.text}$sep${t.text.trim()}';
    _audioKeys.add(pre.audioKey);
    _rec = RecordState.idle;
  });
  ```
  Wrap in try/catch → `setState(() => _rec = RecordState.error)` and show the message; description stays editable.
- Enforce a 120 s auto-stop timer while recording.
- Add `key: const Key('report-title')` to the title `TextField`.
- In `_submit()` pass `audioKeys: _audioKeys` to `reportRepository.create(...)`.
- Add `@visibleForTesting` seams: `typedef ReportScreenStateForTest = _ReportScreenState;` (or expose a public state type), `@visibleForTesting Future<void> debugSimulateRecordingWithKey(String key)` that runs the presign→put→transcribe→append path against the injected repo, and `@visibleForTesting Future<void> debugSubmit()` that calls `_submit()`.

- [ ] **Step 4: Add native permissions**

`apps/mobile/ios/Runner/Info.plist` — add before `</dict>`:
```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>BJJ Open Mat uses the microphone so you can describe a bug or feature by voice.</string>
```
`apps/mobile/android/app/src/main/AndroidManifest.xml` — add with the other `uses-permission` entries:
```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd apps/mobile && flutter test test/features/report_screen_audio_test.dart`
Expected: PASS
Run: `cd apps/mobile && flutter analyze lib/features/report`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/report/screens/report_screen.dart apps/mobile/ios/Runner/Info.plist apps/mobile/android/app/src/main/AndroidManifest.xml apps/mobile/test/features/report_screen_audio_test.dart
git commit -m "feat(mobile): voice recording + transcription on the report screen"
```

---

### Task 9: Privacy policy — disclose voice recordings

**Files:**
- Modify: `docs/store/privacy-policy.html`

- [ ] **Step 1: Add the disclosure**

In the "Information we collect" list of `docs/store/privacy-policy.html`, add a bullet:
```html
    <li><strong>Voice recordings</strong> — if you dictate a bug or feature report,
      we record the audio and transcribe it to text. Recordings are used only to
      process and debug your report and are accessible only to our team.</li>
```

- [ ] **Step 2: Commit**

```bash
git add docs/store/privacy-policy.html
git commit -m "docs: disclose voice recordings in privacy policy"
```

---

## Self-Review

**Spec coverage:** presigned upload (T3/T6), Whisper translate-to-English (T4), audioKeys persistence (T1/T5/T7), transcribe-by-key (T5/T6), editable append flow + multiple segments (T8), 120 s cap (T8), mic permissions (T8), optional/unconfigured services return `service_unavailable` (T3/T5/T6), admin-only audio (no user playback — nothing built), privacy policy (T9), tests at each layer. Covered.

**Placeholder scan:** no TBD/TODO; every code step shows real code; the one flagged verify-against-existing note (AppError signature, facade arg order, error→status mapping, test seams) is an explicit reconciliation instruction, not a placeholder.

**Type consistency:** `audioKeys: string[]` used consistently (contract, facade, repo, Dart model, POST body); `translateToEnglish(Uint8Array, string) → { text, durationMs }` matches across T4/T5; `presignUpload → { uploadUrl, audioKey }` matches T3/T6/T7; `transcribe(userId, audioKey) → { text, durationMs }` matches T5/T6; endpoint constants match route paths.
