# Design — Automated App Store Review Submission

**Date:** 2026-07-23
**App:** BJJ Open Mat (`com.davissylvester.bjjopenmat`)
**Goal:** Add a GitHub Actions workflow that submits an already-built iOS binary to
App Store review, gated by a manual approval step. Building + uploading to TestFlight
already exists (`.github/workflows/mobile-release.yml` → `ios` job) and is unchanged.

---

## Problem

The current pipeline stops at TestFlight. Promoting a build to actual App Store review
is a fully manual App Store Connect task today. We want that submission automated but
kept behind a deliberate human gate, because submitting for review is an irreversible,
outward-facing action.

---

## Architecture — two decoupled stages

**Stage 1 (exists, unchanged):** the `ios` job in `mobile-release.yml` builds the signed
IPA and uploads it to TestFlight via `apple-actions/upload-testflight-build`.

**Stage 2 (new):** a dedicated workflow, `.github/workflows/ios-appstore-submit.yml`,
that does **not rebuild**. It takes an already-uploaded TestFlight build, attaches it to
an App Store version, and submits it for review using Fastlane `deliver`.

Decoupling rationale:

- The build is verified on TestFlight **before** submission (the chosen manual-gate flow).
- The binary has finished Apple-side processing by submit time (no attach race).
- A submit failure never costs a ~20-minute rebuild.

---

## The submit workflow (`ios-appstore-submit.yml`)

### Trigger

`workflow_dispatch` only. Inputs:

| Input | Default | Purpose |
|-------|---------|---------|
| `build_number` | *(empty = latest)* | Which processed TestFlight build to submit. |
| `submit` | `false` | `false` = dry run (auth + precheck + prepare version, **stop before submitting**). `true` = actually submit for review. |
| `auto_release` | `false` | After Apple approval: `false` = you release manually; `true` = auto-release. |

### Approval gate

The job declares `environment: appstore-production`. That GitHub Environment is configured
with a **required reviewer**, so even a `submit=true` run blocks until a human approves in
the GitHub UI — a second checkpoint on top of the manual trigger. (Prerequisite: the
Environment and its reviewer must be created in repo settings before first use.)

### Runner & tooling

- `runs-on: macos-15`.
- Ruby (bundler) + Fastlane. Fastlane drives Stage 2 only; `apple-actions` remains the
  Stage-1 uploader (the "1&2" hybrid).

### Fastlane lane (`fastlane/Fastfile`, lane `submit_review`)

Uses `deliver` with:

- `skip_binary_upload: true` — binary already on TestFlight.
- `skip_metadata: true`, `skip_screenshots: true` — **Phase 1**: metadata stays manual in ASC.
- `build_number:` — from the workflow input (omit → latest processed build).
- `submit_for_review: true`.
- `run_precheck_before_submit: true` — catch metadata violations before the irreversible submit.
- `automatic_release:` — from `auto_release` input.
- `force: true` — non-interactive (no HTML preview prompt).
- `submission_information:` — required because the app now shows an ATT dialog; without
  explicit answers `deliver` stalls on the IDFA / export-compliance questions:
  - `export_compliance_uses_encryption: false` (standard HTTPS/OS crypto only; exempt).
  - `add_id_info_uses_idfa: false` (no ad SDKs; ATT is used for tracking-consent
    correctness, not IDFA-based advertising).

When `submit=false`, the workflow invokes a `prepare_only` path (or passes
`submit_for_review: false` / runs precheck standalone) so it authenticates, resolves the
build, and runs precheck **without** submitting.

### Auth & secrets

Reuses the **existing** App Store Connect API key secrets — no new credentials:

| Secret | Use |
|--------|-----|
| `ASC_API_KEY_P8_BASE64` | `.p8` key, base64. |
| `ASC_ISSUER_ID` | ASC API issuer id. |
| `ASC_KEY_ID` | ASC API key id. |
| `IOS_TEAM_ID` | Apple team id (already present). |

Fastlane's `app_store_connect_api_key` action consumes these and sets the key for `deliver`.

---

## Phase 2 (documented, NOT built now)

Turn the Phase-1 skip flags off and add a `fastlane/metadata/` + `fastlane/screenshots/`
tree so release notes, description, and screenshots become versioned code, pushed by CI on
every submit. Same lane, same secrets, same trigger — a configuration change, not a rewrite.

---

## Testing / verification

A real submission cannot be exercised without submitting. Verification is therefore:

1. Run the workflow with `submit=false`.
2. Confirm the job: authenticates with the ASC API key, resolves the target build, and
   `precheck` passes with no metadata violations.

That proves everything up to — but not including — the irreversible submit click. The first
real `submit=true` run is the acceptance test for the end-to-end path.

---

## Out of scope

- No change to the Android job or the Stage-1 iOS build/TestFlight job.
- No metadata/screenshot management (Phase 2).
- No automatic version-number bumping beyond what Stage 1 already derives.

---

## Definition of Done

- [ ] `.github/workflows/ios-appstore-submit.yml` exists, `workflow_dispatch` with the three inputs.
- [ ] `appstore-production` GitHub Environment created with a required reviewer.
- [ ] `fastlane/Fastfile` `submit_review` lane using `deliver` as specified.
- [ ] `fastlane/Appfile` (or lane params) sets app identifier + team from secrets.
- [ ] Dry run (`submit=false`) authenticates and passes precheck.
- [ ] Docs updated (`docs/` submission runbook) with how to trigger and approve.
