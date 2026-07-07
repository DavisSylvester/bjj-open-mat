# Voice-to-text for Bug / Feature Reports — Design

**Date:** 2026-07-07
**Status:** Approved (brainstorming) — ready for implementation plan
**Area:** `apps/mobile` (Flutter Report screen) + `apps/api` (Elysia API) + `packages/contract`

## Summary

Enhance the existing in-app **Report** flow so the **Description** can be filled by
voice. The user records a voice note; the app uploads the raw audio to **S3 via a
presigned URL**; the backend transcribes it to **English text via OpenAI Whisper**
(translation mode); the English text is appended into the still-editable Description.
The **Title stays typed and required**. Voice is optional — typing still works exactly
as today.

The **raw audio is retained for admin/debugging only** — it is never surfaced to end
users. Reports link to their audio object keys so an admin can retrieve them later via
a signed URL.

This builds on the existing `report_screen.dart`, `report_repository.dart`,
`CreateReportRequest`, `ReportFacade`, and `POST /api/v1/reports` — no new screen.

## Goals

- Let users dictate the report Description instead of typing it.
- Retain the **raw audio** in S3 (admin/debug only) so reports can be reviewed by voice.
- Transcribe **and translate to English** so all reports arrive in one language.
- Keep the transcript **editable** before submit; the user reviews before filing.
- Title remains **typed and required** (min 3 chars, unchanged).
- Follow existing codebase patterns (presigned S3 uploads, `ReportFacade`, injectable
  external services, TypeBox contract, `.mts`).

## Non-goals (out of scope)

- Admin playback UI. Audio is stored + linked and retrievable via signed URL, but no
  admin screen is built here. **Audio is never shown to end users.**
- On-device / live / streaming transcription.
- Editing/re-recording an individual past segment (segments append; the Description
  text is freely editable as plain text).

## Requirements (decided in brainstorming)

1. **Transcription location:** cloud / server-side.
2. **Provider:** OpenAI Whisper API, **translation** endpoint (any language → English).
3. **Audio storage:** **AWS S3**, uploaded via **presigned PUT URL** (matches the
   existing gym-logo upload pattern; the API never handles file bytes for upload).
4. **Flow:** record → stop → presign → PUT to S3 → transcribe-by-key → `Transcribing…`
   → English text **appended** into the editable Description; user may record
   **multiple** times (each appends text + adds one audio key); Title typed;
   **Submit** persists the audio keys on the report.
5. **Recording cap:** ~2 minutes / ≤ 24 MB per segment (Whisper's 25 MB limit).
6. **Audience for audio:** admins only, for debugging.

## Architecture & data flow

```
Report screen
  tap mic → record (record pkg, .m4a/AAC) → stop
     │
     ├─ POST /api/v1/reports/audio-upload-url { contentType: "audio/mp4" }
     │      API: AudioStorage.presignUpload(userId, contentType)
     │      → { uploadUrl, audioKey }          key: reports/audio/<userId>/<uuid>.m4a
     │
     ├─ HTTP PUT the audio bytes directly to `uploadUrl` (S3)
     │
     ├─ POST /api/v1/reports/transcribe { audioKey }
     │      API: AudioStorage.getObject(audioKey) → bytes
     │           TranscriptionService.translateToEnglish(bytes, "audio.m4a")
     │             → OpenAI Whisper /v1/audio/translations (model whisper-1)
     │      → { text, durationMs }
     │
     ├─ append `text` into the editable Description; push `audioKey` to a local list
     │  (repeat for additional recordings)
     │
     └─ type Title → Submit
            POST /api/v1/reports { type, title, description, audioKeys[] }
              API: ReportFacade.create persists the report with audioKeys
```

Three calls: **presign** → (direct S3 PUT) → **transcribe**, then the existing
**create**. The audio object exists in S3 as soon as it's PUT; if the report is never
submitted the key is simply never referenced. An **S3 lifecycle rule** may expire
unreferenced audio under `reports/audio/` (operational concern, not code).

## Components

### Contract (`packages/contract/src`, TypeBox, `.mts`, barrel-exported)

- **`schemas/requests/report-requests.mts`** (modify):
  - `CreateReportRequest` gains `audioKeys: t.Optional(t.Array(t.String(), { maxItems: 20 }))`.
  - Add `AudioUploadUrlRequest = t.Object({ contentType: t.Union([t.Literal("audio/mp4"), t.Literal("audio/m4a"), t.Literal("audio/aac")]) }, { $id: "AudioUploadUrlRequest" })`.
  - Add `TranscribeAudioRequest = t.Object({ audioKey: t.String({ minLength: 1 }) }, { $id: "TranscribeAudioRequest" })`.
- **`schemas/responses/`** (new file `report-responses.mts`, barrel it):
  - `AudioUploadUrlResponse = t.Object({ uploadUrl: t.String(), audioKey: t.String() }, { $id: "AudioUploadUrlResponse" })`.
  - `TranscribeAudioResponse = t.Object({ text: t.String(), durationMs: t.Number() }, { $id: "TranscribeAudioResponse" })`.
- **`schemas/report.mts`** (modify): `Report` gains
  `audioKeys: t.Optional(t.Array(t.String()))`.

### Backend (`apps/api/src`, Elysia, `.mts`, facade pattern, DI via `container.mts`)

- **`services/audio-storage.mts`** (new; model after `services/asset-storage.mts`):
  `AudioStorage` interface + `S3AudioStorage` (`presignUpload(userId, contentType) →
  { uploadUrl, audioKey }` via `PutObjectCommand` + `getSignedUrl`; `getObject(key) →
  Uint8Array` via `GetObjectCommand`; `signedDownloadUrl(key)` for future admin use).
  An `UnconfiguredAudioStorage` fallback throws `AppError("service_unavailable", …)`
  when the bucket env is unset — mirrors `UnconfiguredAssetStorage`.
- **`services/transcription.mts`** (new; model after `services/github-issue.mts`
  a.k.a. `HttpGitHubIssueService`): `TranscriptionService` interface +
  `WhisperTranscriptionService` using `fetch` to OpenAI `/v1/audio/translations`
  (multipart `FormData` with `file` Blob + `model=whisper-1`), returns
  `{ text, durationMs }`. Injectable, **optional** — `null` when `OPENAI_API_KEY`
  unset (like the GitHub issue service); the transcribe route then returns
  `AppError("service_unavailable", …)`.
- **`routes/report.routes.mts`** (modify): add two authed routes on the existing
  `/api/v1/reports` module:
  - `POST /audio-upload-url` `{ body: AudioUploadUrlRequest }` →
    `data(await audioStorage.presignUpload(userId, body.contentType))`.
  - `POST /transcribe` `{ body: TranscribeAudioRequest }` →
    `data(await reportFacade.transcribe(userId, body.audioKey))`.
  - `POST /` body now includes optional `audioKeys` (contract change flows through).
- **`facades/report.facade.mts`** (modify): `create` persists `audioKeys` onto the
  `Report`. Add `transcribe(userId, audioKey): Promise<TranscribeAudioResponse>` that
  fetches bytes via `AudioStorage.getObject` and calls `TranscriptionService`
  (throws `service_unavailable` if either dependency is null/unconfigured). Inject
  `audioStorage` and `transcription` into `ReportFacade`.
- **`repositories/report.repository.mts`** (modify): `insert`/`update` already persist
  the whole `Report`; ensure `audioKeys` round-trips (it's part of the `Report` shape).
- **`container.mts`** (modify): construct `S3AudioStorage` (or `UnconfiguredAudioStorage`)
  and `WhisperTranscriptionService | null`; pass both into `new ReportFacade(...)`; add
  to the `Container` interface as needed.
- **`config/env.mts`** (modify): add `OPENAI_API_KEY` (optional), `AUDIO_BUCKET`
  (optional), `AUDIO_REGION` (optional; default to `ASSETS_REGION`/`us-east-1`) to
  `EnvSchema` + `AppEnv` + `loadEnv`.
- Logging via Winston; no `console.*`.

### Mobile (`apps/mobile/lib`)

- **`core/api/endpoints.dart`** (modify): add
  `static const String reportAudioUploadUrl = '/api/v1/reports/audio-upload-url';`
  and `static const String reportTranscribe = '/api/v1/reports/transcribe';`.
- **`features/report/data/report_audio_repository.dart`** (new): 
  `presignUpload(String contentType) → (uploadUrl, audioKey)`;
  `putAudio(String uploadUrl, File file)` (Dio `put` of bytes with content-type);
  `transcribe(String audioKey) → (text, durationMs)`. Riverpod provider.
- **`features/report/data/report_repository.dart`** (modify): `create(...)` gains
  `List<String> audioKeys = const []`, included in the POST body.
- **`features/report/models/report.dart`** (modify): add `audioKeys` (default `[]`).
- **`features/report/screens/report_screen.dart`** (modify): add a mic button on the
  Description; recording panel (timer + Stop); state machine
  `idle → recording → transcribing → idle` (+ recoverable `error`). Each finished
  transcription appends `"\n\n" + text.trim()` to `_descCtrl` and pushes `audioKey`
  to `List<String> _audioKeys`. Submit passes `audioKeys: _audioKeys`.
- **Audio capture:** add the **`record`** package; format AAC/`.m4a`
  (`AudioEncoder.aacLc`), auto-stop at ~120 s.
- **Permissions:** iOS `Info.plist` add **`NSMicrophoneUsageDescription`**; Android
  `AndroidManifest.xml` add **`RECORD_AUDIO`**.

## Data model

`Report` document adds `audioKeys: string[]` (S3 object keys, spoken order). No
separate collection. Signed URLs are generated on demand for admins; never stored.

## Error handling

- Mic permission denied → inline prompt + "Open Settings"; typing still works.
- Offline / presign / PUT / transcribe failure → inline error; Description stays
  editable so the user can type. A failed segment's key is not added to `_audioKeys`.
- Over-length recording → auto-stop at cap with a toast; captured portion still
  transcribes.
- `OPENAI_API_KEY` / `AUDIO_BUCKET` unset → API returns typed
  `service_unavailable`; mobile surfaces the message (existing `ApiException`).
- Empty/near-silent transcript → append nothing; show "Didn't catch that — try again."

## Security & privacy

- Audio contains voice (PII). S3 bucket is **private**; objects never public. Admin
  access via short-lived **signed URLs** only. **Audio is admin/debug-only.**
- `audio-upload-url`, `transcribe`, and `reports` routes require auth (existing).
- OpenAI/AWS keys live **server-side only**.
- **Privacy policy** (`docs/store/privacy-policy.html`) updated to disclose voice
  recordings collected to process bug/feature reports.

## Testing

- **Mobile (widget tests):** record-button state machine; transcript appends (not
  replaces); multiple segments accumulate `audioKeys`; Submit body includes
  `audioKeys`. Mock `report_audio_repository`.
- **API (`bun test`):** `WhisperTranscriptionService` (mock `fetch`); `ReportFacade.
  transcribe` with fake `AudioStorage` + fake `TranscriptionService` (hand-rolled
  fakes per existing `report-facade.test.mts` style); route test for
  `POST /reports` persisting `audioKeys` and `audio-upload-url` returning a URL.
  Contract round-trip validation for the new schemas.

## Configuration / new env vars

| Var | Where | Purpose |
|-----|-------|---------|
| `OPENAI_API_KEY` | `apps/api` | Whisper translation (optional; feature off when unset) |
| `AUDIO_BUCKET` | `apps/api` | S3 bucket for report audio (optional; feature off when unset) |
| `AUDIO_REGION` | `apps/api` | S3 region for the audio bucket (defaults to `ASSETS_REGION`/`us-east-1`) |

Plus an **S3 lifecycle rule** to expire unreferenced `reports/audio/` objects (ops).

## Resolved decisions

- Presigned S3 upload (not multipart) — matches codebase. ✅
- Multiple recordings **append**. ✅
- **~2 min** per-recording cap. ✅
- Translate **always to English**. ✅
- Audio is **admin/debug-only**, never shown to users; no admin UI in this scope. ✅
