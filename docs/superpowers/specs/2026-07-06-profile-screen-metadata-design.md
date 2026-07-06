# Profile Screen Metadata & SSO — Design Spec

**Date:** 2026-07-06
**Status:** Approved (brainstorming)

## Goal

Turn the Profile screen into an accurate, all-metadata view of the signed-in user. Social/SSO users' identity (name, email, avatar) comes from the provider and is read-only; they may only edit birthday, belt, and home gym. Also: tapping the bottom-nav Home icon returns to the default Find page.

## Decisions (from brainstorming)

1. **Home nav:** tapping Home navigates to the Find/search page as the default landing and resets that branch to its root.
2. **Edit rules:** all social/SSO users get the restricted edit set (birthday, belt, home gym). Email-password users keep full editing. The dev-bypass user counts as full-edit.
3. **Birthday:** stored as an ISO `YYYY-MM-DD` date via a date picker; the profile displays the **computed age**, never a stored age.
4. **Stats:** real stats only — Check-ins, Reviews written, Gyms visited (distinct) — computed from `myCheckins`. Drop "Hours" (untracked).
5. **SSO metadata source:** the mobile app reads `name`/`email`/`pictureUrl` from the Auth0 (Google) OIDC credentials and syncs them to the API on login. No Auth0 tenant configuration required.

## Provider classification

`isSocial(user)` ≡ `user.auth0Id != null && !user.auth0Id.startsWith("auth0|")`.
- `google-oauth2|…`, `apple|…`, etc. → **social** (restricted edits, provider-authoritative identity).
- `auth0|…` (email-password database) → **full edit**.
- No `auth0Id` (dev-bypass) → **full edit**.

This is computed identically on the client (to shape the edit UI) and on the API (to enforce the edit rules). Server enforcement is authoritative; the client UI is a convenience.

## Data model & contract

Add `birthday` to the shared contract, the API user doc + update request, and the mobile `UserProfile`:
- `User.birthday: t.Optional(t.String())` — ISO `YYYY-MM-DD`.
- `UpdateUserRequest.birthday: t.Optional(t.String())`.
- Mongo `UserDoc` gains `birthday?: string`.
- Mobile `UserProfile.birthday: String?` (+ `fromJson`/`toJson`).

Age is derived in the UI from `birthday`; no `age` field is stored.

## SSO metadata sync

On social login the app already receives OIDC profile fields in the Auth0 credentials' `user`. Capture `name`, `email`, `pictureUrl` and sync to the API so the stored profile matches the provider:
- Client: after a social login, send `{ displayName, email, avatarUrl }` to the API (via `PUT /users/me` or an extended `/auth/me` sync) on each login, keeping Google authoritative.
- API `getOrCreate`: when real claims are supplied, use them instead of deriving `displayName` from the email prefix.

## Edit permissions

- **Social users:** editable = { birthday, beltRank, beltStripes, homeGymId }. `displayName`, `email`, `avatarUrl`, `bio` are read-only.
- **Email-password / bypass users:** full edit set (name, bio, weight/division, belt, birthday, home gym).
- **Enforcement:** the edit screen renders only the permitted fields for the user's class. On the API's user-update path, when `isSocial` is true, disallowed fields are **stripped** from the patch (silently ignored) rather than rejected — the allowed fields still persist, and no client-facing error is needed. This keeps the rule server-authoritative without breaking clients.

## Profile screen (glass)

Rebuild the main Profile screen on the glass design system, showing real metadata:
- **Identity:** avatar (provider picture, else belt-colored initial), display name, email, role.
- **BJJ:** belt rank + stripes (belt pin/icon), **age** (from birthday), **home gym** (name resolved via `/gyms/:id`).
- **Member since:** from `createdAt`.
- **Stats (real only):** Check-ins, Reviews written, Gyms visited (distinct) — from `myCheckins`.
- **Edit affordance:** opens the edit screen scoped to the user's permission class.
- The existing inline settings section / role toggle behavior is preserved.

## Home-gym selector

A searchable picker backed by `GET /api/v1/gyms`; selection sets `homeGymId`. The profile resolves and shows the gym name via `GET /api/v1/gyms/:id`. No free-text entry (must reference a real gym).

## Bottom-nav Home behavior

Tapping the Home tab navigates to the Find/search branch root as the default landing, resetting any nested route in that branch. Implemented in the bottom nav's home-tab `onTap`.

## Testing

- **API:** birthday round-trip on update; `isSocial` derivation; social users' disallowed field edits are rejected while allowed ones persist; extend the `user.routes` HTTP test.
- **Mobile:** analyzer-clean; on-simulator verification of (a) social vs email-password edit sets, (b) age display from birthday, (c) home-gym pick + resolved name, (d) Home→Find reset.

## Out of scope

- Auth0 tenant/Action configuration (custom claims) — explicitly avoided per decision 5.
- Editing avatar for any user (social avatar is provider-owned; non-social avatar editing is not added here).
- The separate public-profile screen (`/user/:id`) beyond what already exists.
