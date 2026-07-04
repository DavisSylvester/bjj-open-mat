# Flutter Owner Wiring (Slice 1) — Design

**Date:** 2026-06-17
**Status:** Proposed (design approved in brainstorming; pending written-spec review)
**Depends on:** `docs/superpowers/specs/2026-06-17-mongodb-api-design.md` (the API this slice consumes)

## Purpose

Wire the Flutter app's **gym-owner journey** to the live API with **real Auth0 authentication**: log in → owner dashboard → manage gyms (list/create/edit) → manage sessions (list/create/edit) → view attendance. This is the first vertical slice of connecting the app (currently stub/`DEV_MODE` driven) to the real backend. Models and the repository foundation built here are reused by later slices.

## Scope

**In scope (Slice 1):**
- Real Auth0 login/logout + silent token refresh (replace `DEV_MODE` auto-auth + stubbed refresh).
- Route guards: auth + role gating.
- Repository layer (abstract interface + single API-backed implementation) for gyms, sessions (open-mats), attendance (check-ins).
- Model alignment with the API contract (`Gym.location`, `OpenMat.giType`, `CheckIn`).
- Owner screens consuming repositories with loading/error/empty states; create/edit forms POST/PUT to the API.
- Small API changes: DB-derived role in auth middleware; `role` added to `UpdateUserRequest`; Auth0 env on the API.

**Out of scope (later slices):** practitioner discover/search, open-mat detail, RSVP, check-in + review, training history, profile/edit, favorites, notifications, practitioner gym detail.

## Non-goals
- No offline/mock data path (per decision: repository pattern, API-backed only).
- No Auth0 tenant provisioning (the user supplies a configured tenant + credentials).
- No redesign of existing screen layouts/themes — wiring only.

---

## Architecture

### Auth0 integration (real)

- **Config (user-supplied):**
  - App (dart-define): `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`. The app requests the API `audience` so the access token is a verifiable JWT (not opaque).
  - API (env): `AUTH0_DOMAIN`, `AUTH0_AUDIENCE` — enables the existing `JwtVerifier` JWKS path.
- **Login flow:** Remove `DEV_MODE` auto-auth in `AuthStateNotifier`. `login_screen` → `auth0_flutter` web auth (Google / Apple / email) with scopes `openid profile email offline_access` + `audience` → store access + refresh tokens in `flutter_secure_storage` → set bearer on the Dio client → call `GET /auth/me` (get-or-create) → set `AuthState.authenticated(user)`.
- **Silent refresh:** Replace `ApiClient._refreshToken()` (currently returns `false`) with `auth0_flutter` credentials renewal using the stored refresh token. On a 401, the Dio error interceptor renews, updates the stored/bearer token, and retries the original request once. On renewal failure → clear tokens, set `unauthenticated`.
- **Logout:** Auth0 web logout + clear secure storage + clear bearer + `unauthenticated`.
- **Route guard** (`routerProvider` redirect, currently disabled):
  - `status == unauthenticated` (and not already on an auth route) → `/login`.
  - authenticated, `user.role == null`/unset → `/role-select`.
  - authenticated practitioner navigating to `/owner/*` → redirect to `/`.
  - authenticated owner → owner shell; the redirect re-runs on `authStateProvider` changes (already watched).

### Role source (decision A — DB-derived)

Auth0 does not carry a `gym_owner` claim by default. The **API auth middleware derives `role` from the Mongo user record** rather than a token claim:
- `JwtVerifier.verify` still validates the JWT (issuer/audience/JWKS) and extracts `sub` → `userId` and `email`.
- The auth middleware then loads the user via the user repository and uses the **stored `role`** for `requireOwner`/authorization. First-login users (not yet in DB) resolve to a default `practitioner` until `/auth/me` get-or-creates them.
- Implication: `requireOwner` reflects the DB role, which the user sets via `role-select`.

Rationale: no Auth0 Action/custom-claim configuration required; role is editable in-app; single indexed `users` lookup per authenticated request (acceptable at this scale). The bypass token path is unchanged (still resolves the demo owner).

### Repository layer (abstract + single API impl)

Under `apps/mobile/lib/core/data/`:
- `api_envelope.dart` — helpers to unwrap `{ data }` (single) and `{ data, meta }` (list, returning items + `ListMeta`), tolerant of absent `meta`.
- `api_exception.dart` — maps the API's `{ error: { code, message } }` + HTTP status into a typed `ApiException` (code, message, status) for uniform error UI.

Per feature (interface + API implementation, registered via Riverpod providers):
- `GymRepository` → `ApiGymRepository`: `listMine()`, `getById(id)`, `create(CreateGymRequest)`, `update(id, UpdateGymRequest)`.
- `SessionRepository` → `ApiSessionRepository` (open-mats): `listMine()`, `getById(id)`, `create(...)`, `update(id, ...)`.
- `AttendanceRepository` → `ApiAttendanceRepository` (check-ins): `forSession(openMatId, {date})`.

Screens consume these through Riverpod `FutureProvider`/`AsyncNotifier` and render `AsyncValue` states. The abstract interfaces exist for test fakes (tests implement the interface); there is no production mock implementation or `USE_MOCK` toggle.

### Model alignment

- `Gym.fromJson`: parse `location` as `{ lat, lng }` (the API shape) — **remove** the GeoJSON `coordinates:[lng,lat]` parsing. Add `rating` (the API includes `rating`).
- `OpenMat`: replace `isGiSession: bool` with `giType: String` (`gi|nogi|both`); update `giBadge` to map the three values; replace the non-API `checkinCount` field with the API's `attendeeCount: int?` (update any UI reads accordingly).
- New `CheckIn` model (attendance) aligned to the API `CheckIn` shape (id, openMatId, userId, sessionDate, checkedInAt, rating?, review?, denormalized name/belt).

### Owner screens (wiring only — no layout redesign)

| Screen | Data |
|---|---|
| `owner_dashboard_screen` | counts/derived from `GymRepository.listMine()` + `SessionRepository.listMine()` |
| `my_gyms_screen` | `GymRepository.listMine()` — loading (shimmer), error (`error_state`), empty |
| `add_gym_screen` | `GymRepository.create(...)` from the form → on success pop + invalidate my-gyms |
| `gym_admin_screen` | `GymRepository.getById` + `update` |
| `session_mgmt_screen` | `SessionRepository.listMine()` |
| `create_session_screen` | `SessionRepository.create(...)`; gym picker sourced from `listMine()`; giType + skillLevel selectors |
| `session_admin_screen` | `SessionRepository.getById` + `update` |
| `attendance_screen` | `AttendanceRepository.forSession(id, date)` |

Mutations invalidate the relevant provider on success; failures surface via the existing `error_state` widget. Reuse existing `shimmer_loader` for loading.

### API changes (small, in `apps/api` + `packages/contract`)

1. **DB-derived role** in the auth middleware: after JWT verification, load the user and use the stored `role` for the `requireOwner`/`requireAuth` identity. Inject the user repository (or user facade) into the auth plugin. Keep the bypass path unchanged.
2. **`role` settable:** add `role: UserRole` (optional) to `UpdateUserRequest` so `PUT /users/me` can promote a user to `gym_owner` from `role-select`. The user facade applies it.
3. **API env:** set `AUTH0_DOMAIN` + `AUTH0_AUDIENCE` (user-supplied) so the JWKS verification path is active alongside the bypass.

---

## Data flow (login → owner dashboard)

1. App launches → `authState` `initial` → router sends to `/login` (guard).
2. User taps a provider → Auth0 web auth → tokens stored, bearer set.
3. `GET /auth/me` get-or-creates the user; `authState` becomes `authenticated(user)`.
4. If `user.role` unset → `/role-select` → user picks "Gym Owner" → `PUT /users/me { role: "gym_owner" }` → `authState` updated.
5. Router routes owner → `/owner/dashboard`. Dashboard loads `listMine()` for gyms + sessions.
6. Owner navigates to gyms/sessions/attendance; each screen reads its repository; creates/edits POST/PUT and invalidate.

## Error handling

- Network/HTTP errors → `ApiException` → `error_state` widget with retry (re-invokes the provider).
- 401 → silent refresh + retry once; on failure → logout to `/login`.
- 403 (non-owner hitting owner endpoint) → shouldn't occur given the route guard, but surfaces as an error state if it does.
- Empty lists → explicit empty state (not an error).

## Testing

- **Repositories:** unit tests against a mocked Dio (success envelope parse for single + list, `mine=true` query param, error → `ApiException` mapping). No live API.
- **API changes:** extend the `bun test` suite — DB-role authorization (a non-owner DB user is rejected by `requireOwner` even with a valid token; an owner is allowed), and `PUT /users/me { role }` updates the stored role.
- **Auth flow:** Auth0 web auth is external and not unit-tested; the refresh/retry interceptor logic and envelope/exception helpers are tested.
- **Manual verification:** with the user-supplied Auth0 config, log in as an owner and exercise the dashboard → gyms → create → sessions → attendance path against the running API + MongoDB.

## Known limitations / notes

- DB-role lookup adds one indexed `users` read per authenticated request (acceptable at this scale; cache later if needed).
- Flutter web vs native Auth0 callback setup differs; the user's tenant must have the appropriate callback/logout URLs for the target platform(s).
- Inherits the API's documented denormalization-drift limitation (gym rename/relocate not propagated to existing open mats).
