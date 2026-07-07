# Voice-to-text for Bug / Feature Reports — Design

**Date:** 2026-07-07
**Status:** Approved (brainstorming) — ready for implementation plan
**Area:** `apps/mobile` (Flutter Report screen) + `apps/apis` (Elysia API) + `packages/contract`

## Summary

Enhance the existing in-app **Report** flow so the **Description** can be filled by
voice. The user records a voice note; the backend stores the **raw audio in S3** and
transcribes it to **English text via OpenAI Whisper** (translation mode); the English
text is appended into the still-editable Description. The **Title stays typed and
required**. Voice is optional — typing still works exactly as today.

This builds on the existing `report_screen.dart`, `report_repository.dart`,
`CreateReportRequest`, and `POST /reports` — it does not introduce a new screen.

## Goals

- Let users dictate the report Description instead of typing it.
- Persist the **raw audio** centrally (S3) so reports can be reviewed by voice later.
- Transcribe **and translate to English** so all reports arrive in one language.
- Keep the transcript **editable** before submit; the user reviews before filing.
- Title remains **typed and required** (min 3 chars, unchanged).

## Non-goals (out of scope for this spec)

- Admin playback UI for recorded audio (audio is stored + linked; playback is a
  separate future admin feature).
- On-device / live transcription.
- Editing or re-recording an individual past segment (segments only append; the
  whole Description text remains freely editable as plain text).
- Real-time streaming transcription.

## Requirements (decided in brainstorming)

1. **Transcription location:** cloud / server-side.
2. **Provider:** OpenAI Whisper API, **translation** endpoint (any language → English).
3. **Audio storage:** **AWS S3** bucket (raw recording per segment).
4. **Flow:** record → stop → `Transcribing…` → English text **appended** into the
   editable Description; user may record **multiple** times (each appends text + adds
   one audio object); Title typed; **Submit** links the audio to the report.
5. **Recording cap:** ~2 minutes / ≤ 24 MB per segment (Whisper's 25 MB limit).

## Architecture & data flow

```
Report screen
  tap mic → record (record pkg, .m4a/aac) → stop
     │
     ├─ POST /api/v1/reports/transcribe   (multipart: audio file)
     │      API: AudioStorageService.put → S3  reports/audio/pending/<uuid>.m4a
     │           TranscriptionService.translate(file) → OpenAI Whisper (→ English)
     │      → 200 { text, audioKey, durationMs }
     │
     ├─ append `text` into the editable Description; push `audioKey` to a local list
     │  (repeat for additional recordings)
     │
     └─ type Title → Submit
            POST /api/v1/reports { type, title, description, audioKeys[] }
              API: persist report with audioKeys (audio is now "linked")
```

Two calls: **transcribe** (once per recording) then the existing **create** (once).
Abandoned recordings remain as orphan objects under the `pending/` prefix and are
removed by an **S3 lifecycle rule** (e.g., expire `reports/audio/pending/` after 7
days). Linked audio may optionally be copied/moved to a `reports/audio/linked/`
prefix on create (implementation detail; the stored `audioKey` is what the report
references).

## Components

### Mobile (Flutter)

- **`report_screen.dart`** (modified): add a **mic button** in the Description
  section. It drives a small recording panel (record duration timer + Stop). The
  Description remains a normal editable multiline `TextField` at all times.
  - State machine: `idle → recording → transcribing → idle` (transcript appended),
    plus a recoverable `error` state. Submit button stays gated on
    `title ≥ 3 && description ≥ 10` (unchanged).
  - Multiple recordings: each completed transcription appends `"\n\n" + text`
    (trimmed) to the Description and appends its `audioKey` to an in-memory
    `List<String> _audioKeys`.
- **`report_audio_repository.dart`** (new): `Future<TranscriptionResult> transcribe(File audio)`
  → `POST /reports/transcribe` (multipart), returns `{ text, audioKey, durationMs }`.
  Riverpod provider mirrors `reportRepositoryProvider`.
- **`report_repository.dart`** (modified): `create(...)` gains
  `List<String> audioKeys = const []` and includes it in the POST body.
- **Audio capture:** add the **`record`** package. Enforce max duration (~120 s) and
  stop automatically at the cap with a warning. Recorded format: AAC/`.m4a`.
- **Permissions:**
  - iOS `Info.plist`: add **`NSMicrophoneUsageDescription`** (currently missing).
  - Android `AndroidManifest.xml`: add **`RECORD_AUDIO`**.

### Backend (Elysia, Bun) — per layered Router → Service → Repository

- **New route** `POST /api/v1/reports/transcribe` (auth required):
  - Accepts `multipart/form-data` with an `audio` file (Elysia `t.File`, validated
    MIME `audio/*`, size ≤ 24 MB).
  - `AudioStorageService.put(buffer, key)` → S3, key `reports/audio/pending/<uuid>.<ext>`.
  - `TranscriptionService.translateToEnglish(buffer, filename)` → OpenAI Whisper
    (`/v1/audio/translations`, model `whisper-1`).
  - Returns `TranscribeAudioResponse { text, audioKey, durationMs }`.
- **`POST /api/v1/reports`** (modified): accept optional `audioKeys: string[]`,
  persist on the report document.
- **New services (DI-registered, no `new` in routers/services):**
  - `TranscriptionService` — wraps an OpenAI client; single `translateToEnglish` method.
  - `AudioStorageService` — wraps an S3 client (`@aws-sdk/client-s3`); `put`, and a
    `signedUrl(key)` helper for future admin playback.
- **Repository:** report persistence extended to store `audioKeys` (Mongo).
- **Config (via DI, validated with TypeBox `Value.Parse`):** `OPENAI_API_KEY`,
  `AWS_REGION`, `AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
  (or instance role). Logging via Winston (no `console.*`).

### Contract (`packages/contract`, TypeBox, `.mts`)

- **New** `TranscribeAudioResponse` (`schemas/responses/`):
  ```ts
  t.Object({
    text: t.String(),
    audioKey: t.String(),
    durationMs: t.Number(),
  }, { $id: "TranscribeAudioResponse" })
  ```
- **`CreateReportRequest`** gains:
  ```ts
  audioKeys: t.Optional(t.Array(t.String(), { maxItems: 20 })),
  ```
- **`Report`** model + Dart `Report` model gain `audioKeys: string[]` (default `[]`).
- Derived types via `Static<typeof ...>`, barrel-exported per existing convention.

## Data model

`Report` document adds:
- `audioKeys: string[]` — S3 object keys for the raw recordings, in spoken order.

No separate audio collection; the keys reference S3 objects. Signed URLs are
generated on demand (future admin playback), never stored.

## Error handling

- **Mic permission denied:** inline prompt with a "Open Settings" action; typing
  remains available.
- **Offline / upload failure / transcription failure:** inline error on the panel;
  the Description stays editable so the user can type instead. The failed segment's
  audio is not linked.
- **Over-length recording:** auto-stop at the cap with a toast; the captured portion
  can still be transcribed.
- **Whisper/S3 5xx:** API returns a typed error envelope; mobile surfaces the message
  (consistent with existing `ApiException` handling).
- **Empty/near-silent transcript:** append nothing; show "Didn't catch that — try
  again."

## Security & privacy

- Audio contains voice (PII). S3 bucket is **private**; objects are never public.
  Admin access is via short-lived **signed URLs** only.
- `transcribe` and `reports` endpoints require authentication (existing behavior).
- OpenAI/AWS keys live **server-side only** (never in the app).
- **Privacy policy** (`docs/store/privacy-policy.html`) updated to disclose that
  voice recordings are collected to process bug/feature reports.

## Testing

- **Mobile (widget tests):** record-button state machine (idle→recording→
  transcribing→appended, and error); transcript appends (not replaces); multiple
  segments accumulate `audioKeys`; Submit body includes `audioKeys`. Mock
  `report_audio_repository`.
- **Backend (`bun test`):** `TranscriptionService` (mock OpenAI client),
  `AudioStorageService` (mock S3 client), transcribe route validation (MIME/size),
  `POST /reports` persists `audioKeys`. Contract schema round-trip tests.

## Configuration / new env vars

| Var | Where | Purpose |
|-----|-------|---------|
| `OPENAI_API_KEY` | API | Whisper transcription/translation |
| `AWS_REGION`, `AWS_S3_BUCKET` | API | audio storage target |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | API | S3 credentials (or instance role) |

Plus an **S3 lifecycle rule** expiring `reports/audio/pending/` objects (~7 days).

## Resolved decisions

- Multiple recordings **append** (not one-shot). ✅
- **~2 min** per-recording cap. ✅
- Admin playback is **out of scope** (audio stored + linked only). ✅
- Translate **always to English**. ✅
