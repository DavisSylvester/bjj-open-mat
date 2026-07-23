# iOS App Store Submission (Stage 2)

Promote an already-uploaded TestFlight build to **App Store review**. This is
Stage 2 of the iOS release and never rebuilds — the build + TestFlight upload is
Stage 1 (`ios` job in `.github/workflows/mobile-release.yml`).

- **Workflow:** `.github/workflows/ios-appstore-submit.yml`
- **Fastlane:** `apps/mobile/ios/fastlane/` (`submit_review` lane)
- **App:** `com.davissylvester.bjjopenmat`

## One-time setup

1. **GitHub Environment** — create an environment named `appstore-production`
   (repo Settings → Environments) and add yourself as a **Required reviewer**.
   The submit job runs in this environment, so every run pauses for a manual
   approval in the GitHub UI before it proceeds.
2. **Secrets** — reuses the existing App Store Connect API key secrets (no new
   ones): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64`, `IOS_TEAM_ID`.

## Flow

1. Cut a release so Stage 1 builds and uploads to TestFlight
   (`gh workflow run mobile-release.yml -f build_name=<x.y.z>`).
2. Install the TestFlight build, verify it (ATT dialog, account deletion, etc.).
3. Make sure the App Store **version metadata** (what's new, screenshots,
   description, and the App Privacy answers) is filled in and correct in App
   Store Connect. Phase 1 does **not** manage metadata — only the binary +
   submission.
4. **Dry run first:**
   ```bash
   gh workflow run ios-appstore-submit.yml -f submit=false
   ```
   Approve the environment gate. This authenticates, confirms the target build
   exists, and runs `precheck` against the live metadata — without submitting.
5. **Submit for review:**
   ```bash
   gh workflow run ios-appstore-submit.yml -f submit=true
   # optional: -f build_number=123  -f auto_release=true
   ```
   Approve the environment gate. The lane attaches the build to the version and
   submits it for App Store review.

## Inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `submit` | `false` | `false` = dry-run precheck only. `true` = actually submit for review. |
| `build_number` | latest | Which processed TestFlight build to submit. Blank = latest. |
| `auto_release` | `false` | After Apple approval, auto-release vs. release manually. |

## Notes

- **Export compliance** is declared as exempt (`export_compliance_uses_encryption:
  false`) — the app uses only standard HTTPS / OS crypto.
- **IDFA** is declared unused (`add_id_info_uses_idfa: false`) — the ATT dialog is
  for tracking-consent correctness, not ad targeting; there are no ad SDKs.
  Update these in `fastlane/Fastfile` if that ever changes.

## Phase 2 (future)

Manage release notes, description, and screenshots as code: add a
`apps/mobile/ios/fastlane/metadata/` + `screenshots/` tree and flip
`skip_metadata` / `skip_screenshots` to `false` in the `submit_review` lane.
