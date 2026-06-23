# BJJ Open Mat — Full API + MongoDB Design

**Date:** 2026-06-17
**Status:** Proposed (design approved in brainstorming; pending written-spec review)
**Source of truth (shapes):** `packages/contract` (TypeBox). This doc describes the system; the contract package is authoritative and emitted at `GET /openapi.json`.

## Purpose

Build the complete backend API surface the Flutter app (`apps/mobile`) needs, backed by MongoDB. Replaces the in-memory seed scaffold in `apps/api` with a real datastore, real auth, and the full set of endpoints referenced in `apps/mobile/lib/core/api/endpoints.dart` plus speculative Notifications & Settings.

## Goals

- Every endpoint the Flutter frontend references, plus Notifications & Settings.
- TypeBox for all validation, schemas, derived types, and enums — each in its own file.
- Validation failures logged via Winston with a `VALIDATION:` prefix for easy identification.
- MongoDB via the native driver (v7.3), env-driven connection (Atlas or local container).
- Strict layering: **Routes → Facade (BAL) → Repository (DAL) → MongoDB**. BAL never touches the driver.
- Postman collection covering every endpoint.

## Non-goals

- Flutter app changes (the app is wired to the API in a later session). One frontend implication is flagged: the `OpenMat` model's `isGiSession: bool` becomes `giType` (see Enums).
- Real-time / push delivery for notifications (REST list + mark-read only).
- Payment / fee processing (fees are stored data only).

---

## Architecture & layering

```
HTTP (Elysia routes)         routes/<domain>.routes.mts
   └─► Facade (BAL)          facades/<domain>.facade.mts     ← business logic; never touches Mongo
          └─► Repository     repositories/<entity>.repository.mts  ← Mongo access only
                 └─► MongoDB (native driver v7.3)
```

| Layer | Responsibility | Rule |
|---|---|---|
| **Route** | HTTP in/out, TypeBox request validation, response-envelope shaping. | No business logic. |
| **Facade (BAL)** | Business rules: ownership checks, RSVP idempotency, denormalization, distance calc, get-or-create. Orchestrates one or more repositories. | **Consumes repositories only. Never the `Db`/driver.** |
| **Repository (DAL)** | Collection access: CRUD, index creation, `Value.Parse()` parse-on-read into contract types. | No business logic. Only place that imports the driver. |

- **DI container** (`container.mts`) is the composition root: constructs the `MongoClient` + `Db`, then repositories, then facades; injects facades into routes. No `new` in routes or facades. The `Db` handle is injected **into repositories only** — facades receive repositories, which structurally enforces "BAL never accesses data directly."
- One facade per domain: `UserFacade`, `GymFacade`, `OpenMatFacade`, `CheckInFacade`, `FavoriteFacade`, `NotificationFacade`, `SettingsFacade`.
- One repository per collection (see Data model).

---

## Contract package restructure (`packages/contract/src`)

Split the current monolithic `index.mts` into individual files, one concept per file, grouped by kind, barrelled.

```
packages/contract/src/
├─ enums/
│  ├─ belt-rank.mts          # white | blue | purple | brown | black
│  ├─ skill-level.mts        # all | beginner | intermediate | advanced
│  ├─ gi-type.mts            # gi | nogi | both
│  ├─ user-role.mts          # practitioner | gym_owner
│  ├─ notification-type.mts  # rsvp | review | session_update | system
│  ├─ review-category.mts    # instruction | cleanliness | variety | worth_returning | overall
│  └─ index.mts              # barrel
├─ schemas/
│  ├─ user.mts  gym.mts  geo-location.mts  open-mat.mts  open-mat-detail.mts
│  ├─ attendee.mts  check-in.mts  review.mts  favorite.mts
│  ├─ notification.mts  settings.mts
│  ├─ requests/             # create/update/query bodies per domain (one per file)
│  ├─ responses/            # envelope helpers + health
│  │  ├─ envelope.mts       # DataResponse<T>, ListResponse<T>, ListMeta, ErrorResponse
│  │  └─ health.mts
│  └─ index.mts
├─ types/                   # derived `Static<typeof X>` types, one per file, barrel
│  └─ index.mts
└─ index.mts                # top-level barrel
```

- **Schema-first:** define TypeBox schema → derive `Static<>` type → export both. Each enum/schema/type in its own file.
- Entity schemas carry `$id` so they emit as named OpenAPI components.
- Elysia routes validate using these schemas directly (TypeBox-native), so runtime validation and the contract never drift.

---

## Enumerations

| Enum | Values | Notes |
|---|---|---|
| `BeltRank` | `white \| blue \| purple \| brown \| black` | |
| `SkillLevel` | `all \| beginner \| intermediate \| advanced` | |
| `GiType` | `gi \| nogi \| both` | **Replaces `OpenMat.isGiSession: bool`.** Stored on the session. Search filter `giType=gi` matches `gi`+`both`; `giType=nogi` matches `nogi`+`both`; omitted = all. Flutter `OpenMat` model + create-session form update when the app is wired. |
| `UserRole` | `practitioner \| gym_owner` | Drives ownership-guarded routes. |
| `NotificationType` | `rsvp \| review \| session_update \| system` | Speculative surface. |
| `ReviewCategory` | `instruction \| cleanliness \| variety \| worth_returning \| overall` | The 5 rating dimensions the review screen collects. |

---

## Data model (MongoDB collections)

| Collection | Key fields | Indexes |
|---|---|---|
| `users` | `_id`, `auth0Id`, `email`, `displayName`, `role`, `beltRank?`, `beltStripes?`, `weight?`, `bio?`, `avatarUrl?`, `homeGymId?`, `settings` (embedded) | unique `auth0Id`; unique `email` |
| `gyms` | `_id`, `ownerId?`, `name`, `description?`, `address`, `city?`, `state?`, `country?`, `postalCode?`, `location` (GeoJSON Point), `googlePlaceId?`, `phone?`, `website?`, `amenities[]`, `isVerified`, `rating?`, `createdAt` | `2dsphere` on `location`; `ownerId` |
| `openMats` | `_id`, `gymId`, `hostId?`, `title`, `description?`, `dayOfWeek?`, `startTime`, `endTime`, `isRecurring`, `specificDate?`, `maxParticipants?`, `skillLevel`, `giType`, `isCancelled`, `feeCents?`, denormalized `gymName`/`location` (GeoJSON Point, copied from gym), `createdAt` | `gymId`+`dayOfWeek`; `2dsphere` on `location` |
| `rsvps` | `openMatId`, `sessionDate`, `userId`, `rsvpAt` | unique `(openMatId, sessionDate, userId)` |
| `checkins` | `_id`, `openMatId`, `userId`, `sessionDate`, `checkedInAt`, `rating?`, `review?`, `categoryRatings?`, denormalized `gymName?/openMatTitle?/userName?/beltRank?`, `createdAt` | `userId`; `openMatId`+`sessionDate` |
| `favorites` | `userId`, `gymId`, `createdAt` | unique `(userId, gymId)` |
| `notifications` | `_id`, `userId`, `type`, `title`, `body`, `read`, `data?`, `createdAt` | `userId`+`read`+`createdAt` |

- `attendeeCount` / `checkinCount` are computed per occurrence (count of `rsvps` / `checkins` for `(openMatId, sessionDate)`), not stored on the session, to avoid drift.
- Settings embedded in the user doc (`theme`, notification prefs); `GET/PUT /users/me/settings` read/patch that subdocument.
- `location` stored as GeoJSON `{ type: "Point", coordinates: [lng, lat] }`; the contract `GeoLocation { lat, lng }` is mapped on read/write. `distanceKm` computed by `$geoNear` for `/nearby`.
- `openMats` denormalize the gym's `location` + `gymName` on create/update so `/open-mats/nearby` and `distanceKm` use a `2dsphere` index directly (no per-query gym join). The `OpenMatFacade` keeps them in sync when a gym's location changes.

---

## Endpoint surface

All under `/api/v1` unless noted. Protected routes require a valid bearer token (or the bypass secret).

**Auth / Users / Settings**
| Method | Path | Purpose |
|---|---|---|
| GET | `/auth/me` | Get-or-create current user from token claims. |
| GET | `/users/me` | Current user profile. |
| PUT | `/users/me` | Update profile (`displayName?, beltRank?, beltStripes?, weight?, bio?, avatarUrl?, homeGymId?`). |
| GET | `/users/:id` | Public profile. |
| GET | `/users/me/settings` | Current user settings. |
| PUT | `/users/me/settings` | Update settings (theme, notification prefs). |

**Gyms**
| Method | Path | Purpose |
|---|---|---|
| GET | `/gyms?mine=&page=&limit=` | List gyms; `mine=true` → owner's gyms. |
| POST | `/gyms` | Create (owner). |
| GET | `/gyms/:id` | Detail. |
| PUT | `/gyms/:id` | Update (owner of resource). |
| GET | `/gyms/nearby?lat=&lng=&radiusKm=` | Geo search with `distanceKm`. |
| GET | `/gyms/:id/directions` | `{ latitude, longitude, address, mapsUrl }` for client deep-link. |
| POST | `/gyms/:id/favorite` | Add favorite. |
| DELETE | `/gyms/:id/favorite` | Remove favorite. |

**Open Mats**
| Method | Path | Purpose |
|---|---|---|
| GET | `/open-mats?dayOfWeek=&giType=&skillLevel=&lat=&lng=&radiusKm=&mine=&page=&limit=` | List/finder. Sorted by `startTime`. |
| POST | `/open-mats` | Create (owner). |
| GET | `/open-mats/nearby?lat=&lng=&radiusKm=` | Geo search. |
| GET | `/open-mats/:id` | Detail (incl. location). 404 if missing. |
| PUT | `/open-mats/:id` | Update (owner). |
| POST | `/open-mats/:id/rsvp` body `{ sessionDate }` | RSVP (idempotent). |
| DELETE | `/open-mats/:id/rsvp?sessionDate=` | Cancel RSVP. |
| GET | `/open-mats/:id/attendees?sessionDate=` | RSVP'd attendees for an occurrence. |
| POST | `/open-mats/:id/checkin` body `{ sessionDate }` | Check in (post-session). |
| GET | `/open-mats/:id/checkins?date=` | Attendance for a session (owner). |

**Check-ins / Training**
| Method | Path | Purpose |
|---|---|---|
| POST | `/checkins/:id/review` body `{ rating, review?, categoryRatings }` | Submit review for a check-in (48h window enforced by facade). |
| GET | `/users/me/checkins?page=&limit=` | Training history. |

**Favorites**
| Method | Path | Purpose |
|---|---|---|
| GET | `/users/me/favorites` | Favorite gyms (joined). |

**Notifications** (speculative)
| Method | Path | Purpose |
|---|---|---|
| GET | `/notifications?unread=&page=&limit=` | List my notifications. |
| POST | `/notifications/:id/read` | Mark one read. |
| POST | `/notifications/read-all` | Mark all read. |

**Infra** — `GET /health`, `GET /ready` (pings Mongo), `GET /openapi.json`.

---

## Response envelope

- **Single:** `{ "data": T }`
- **List:** `{ "data": T[], "meta": { "page": n, "limit": n, "total": n } }`
- **Error:** `{ "error": { "code": string, "message": string, "details?": unknown } }` with appropriate HTTP status.

`DataResponse<T>` / `ListResponse<T>` / `ErrorResponse` are TypeBox helpers in `schemas/responses/envelope.mts`. This matches what the Flutter client already parses (always reads `data`).

---

## Auth

- **`authMiddleware`** (Elysia `resolve`) reads `Authorization: Bearer <token>`:
  - token === bypass secret (`AUTH_BYPASS_SECRET`, default `TopFlightApiSecurity2026+`) → resolve a fixed **demo identity** (`DEMO_USER_ID`, `DEMO_USER_ROLE` via env). Dev/test escape hatch.
  - else → verify Auth0 JWT against tenant **JWKS** (cached), check `iss`/`aud`/`exp`; extract `sub`→userId, role, email.
  - invalid/missing on a protected route → `401`.
- `GET /auth/me` upserts the user from token claims (get-or-create) on first call.
- Ownership-guarded routes (`POST/PUT /gyms`, `POST/PUT /open-mats`, `/open-mats/:id/checkins`) require `role === gym_owner` and matching `ownerId` (403 otherwise).
- Auth config (Auth0 domain, audience, bypass secret, demo identity) is DI-managed env, validated with `Value.Parse()` at boot. Missing required env = boot blocker.

---

## Validation + `VALIDATION:` logging

- Request bodies/queries/params validated by Elysia against contract TypeBox schemas.
- Global `onError` hook: when `error.code === "VALIDATION"`, log via Winston at `warn`:
  `VALIDATION: <METHOD> <path> — <field>: <reason>` and return `400` with the error envelope.
- Non-validation errors log without the prefix, so `VALIDATION:` uniquely flags validation issues in logs.

---

## MongoDB integration

- **Driver:** `mongodb@^6.21` (native; no ODM). Pinned to 6.x because `mongodb@7`/`bson@7` fail to load under Bun 1.3.x (`node:v8 isBuildingSnapshot` unimplemented). 6.21 still provides the modern features used here: shared `MongoClient` with `timeoutMS` (CSOT, ≥6.11), `AbortSignal` on reads (≥6.13), parent `Db`/`MongoClient` access (≥6.20), `$geoNear`. Revisit 7.x when Bun implements the missing v8 API.
- **Connection:** `MONGODB_URI` env → Atlas or local. `docker-compose.yml` runs MongoDB 7 locally; connection is env-driven so either works.
- **Indexes:** each repository ensures its indexes on first use / startup (see Data model).
- **Seed:** `bun run seed` upserts the existing `seed.mts` fixtures into Mongo (idempotent) so the app is exercisable immediately.
- **`/ready`** runs `db.command({ ping: 1 })` → `ready` / `degraded`.

---

## Postman collection

- `docs/postman/bjj-open-mat.postman_collection.json` + `docs/postman/bjj-open-mat.postman_environment.json`.
- Folders per domain; every endpoint with example bodies derived from the contract.
- Collection variables: `{{baseUrl}}` = `http://localhost:3100`, `{{bearerToken}}` pre-set to the bypass secret so requests work out of the box.

---

## Testing & verification gate

- Socket-bound boot test (extends the current one), run against a real ephemeral MongoDB (or skipped-with-blocker if unavailable): `/health`, `/ready`, `/openapi.json` → 200; representative CRUD per domain; auth-bypass happy path; a `VALIDATION:` 400 path; an ownership 403 path.
- `bun run verify` = `type-check && lint && test` across `@bjj/contract` + `@bjj/api`.
- ESLint clean (strict, no `any`, explicit return types). Elysia inferred-return functions keep the existing targeted lint-disable.

---

## Suggested phasing (for the implementation plan)

1. Contract restructure — enums/schemas/types split + new entities (gi-type, user, settings, notification, favorite, review).
2. Mongo plumbing — driver dep, `MongoClient`/`Db`, env validation, DI, `docker-compose.yml`, index bootstrap, seed script.
3. Repositories (DAL) — one per collection, parse-on-read.
4. Facades (BAL) — one per domain, consuming repositories.
5. Auth middleware + bypass + ownership guards.
6. Routes + validation logging + response envelope.
7. OpenAPI doc update + Postman collection.
8. Tests + `verify` gate green.

## Known limitations

- **Denormalized open-mat fields are set at create time and not re-synced on gym update.** `openMats` store `gymName`/`location`/`gymOwnerId` copied from the gym at creation. If a gym is later renamed, relocated, or transferred to a new owner, existing open mats keep the stale values (affecting `/open-mats/nearby` geo and `mine` filtering). Cross-entity propagation is deferred; revisit if gym mutation becomes common.

## Open implementation notes

- `attendeeCount`/`checkinCount` computed per `(openMatId, sessionDate)` — not stored.
- Review 48h window: facade compares `now` to `checkedInAt`; outside window → 409/403.
- Distance: `$geoNear` for `/nearby`; detail/list without coords omit `distanceKm`.
- Frontend follow-up (out of scope here): update Flutter `OpenMat` model `isGiSession` → `giType`, and fix `endpoints.dart` health path (already changed to `/health`).
