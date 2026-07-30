# Gym Logo Upload for Existing Gyms — Design

**Date:** 2026-07-30
**App:** BJJ OPEN MAT (iOS, Apple ID `6787704999`)
**Status:** Approved
**Independent of:** the Gym Open Mats Screen spec — these share no code and can ship in
either order.

## Problem

Optional logo upload **already exists at gym creation**. `add_gym_screen.dart:70-100`
picks an image, downscales it to 512×512 at 85% JPEG quality, uploads through
`gymRepositoryProvider.uploadLogo`, shows a preview, blocks submit while uploading, and
surfaces failures. The form requires only name and address (`:68`), so the logo is
genuinely optional.

Two gaps remain:

1. **An existing gym cannot get a logo.** `gym_admin_screen.dart` edits only name and
   address (`:26-27`, `:46-59`). Nothing in the app adds a logo to a gym after creation.
2. **Nothing prompts owners** to add one, so most gyms stay logo-less.

Gap 1 must be closed first: a prompt whose destination cannot perform the action is
worse than no prompt.

## What this builds

### 1. Shared logo picker widget

Extract the picker from `add_gym_screen.dart:70-100` into a shared widget used by both
the create and admin screens: same 512×512 / 85% JPEG downscale, same preview, same
"disable save while uploading" behaviour, same failure message.

**Extract, do not duplicate.** Two copies of upload logic drift, and one silently stops
matching the other's image constraints. This mirrors the `deriveCanManageGym` extraction
made during the My Gym work for the same reason.

### 2. Logo upload on the gym admin screen

`gym_admin_screen.dart` gains the shared picker. On save it patches the gym through the
existing repository method:

```
update(gymId, UpdateGymRequest({'logoUrl': url}))
```

Both `uploadLogo(bytes, contentType)` (`gym_repository.dart:26`) and
`update(id, UpdateGymRequest)` (`:22`) already exist. No backend work.

### 3. Encouragement banner on gym detail

A dismissible card reading "Add your gym's logo", shown only when **both** hold:

- `gym.logoUrl` is null or empty, and
- `deriveCanManageGym(...)` returns true for the current user.

Tapping opens the gym admin screen. Dismissal is stored per gym id in secure storage so
it does not reappear on every visit.

The `deriveCanManageGym` gate is the same shared function introduced by the My Gym fix
wave. Using it guarantees the banner is never shown to someone the API would refuse —
the exact defect that review caught on the Forum and Feedback tiles.

## Who may upload: owners only, for now

The request was to encourage "members and owners". **Members cannot upload today**:
`POST /api/v1/gyms/logo-upload-url` is guarded `requireOwner: true`
(`gym.routes.mts:45`). Prompting a member would produce a 403.

This spec therefore targets owners and managers only, via `deriveCanManageGym`. No
backend authorization change.

Opening uploads to members is deliberately deferred. A gym logo is public-facing brand
identity, so "who may change it" is a product and abuse question — not an
implementation detail — and needs its own design. Recorded in "Follow-up work".

## Testing

- Shared picker: downscale parameters and content type match what `add_gym_screen` used
  before extraction, so creation behaviour is unchanged.
- `add_gym_screen` still uploads a logo at creation and still allows submitting without
  one.
- `gym_admin_screen` uploads a logo and patches `logoUrl`; saving without touching the
  logo leaves the existing value untouched.
- Banner shows when `logoUrl` is empty and the user can manage.
- Banner hidden when a logo exists.
- Banner hidden for a user who cannot manage, even with no logo.
- Dismissal persists for that gym and does not suppress the banner for a different gym.

## Out of scope

- Member logo uploads (see Follow-up work) — requires a backend authorization change.
- Logo moderation, reporting, or removal.
- Changing the image constraints (512×512, 85% JPEG) — the extraction preserves them
  exactly.
- Logos for anything other than gyms.

## Follow-up work

1. **Decide whether members may upload gym logos**, and if so what prevents abuse of a
   gym's public brand image. Requires relaxing `requireOwner` on the logo endpoint plus
   an abuse story — possibly a member-suggests/owner-approves flow.

## Risks

**Nag fatigue.** A banner an owner cannot permanently silence trains them to ignore
prompts generally. Mitigated by per-gym dismissal persisted in secure storage.

**Save-flow coupling.** Adding upload state to `gym_admin_screen` means its save button
must respect an in-flight upload, as the create screen already does. Getting this wrong
allows saving a gym while its logo upload is still running, persisting a stale or empty
`logoUrl`.
