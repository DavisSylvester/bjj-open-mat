# BJJ Open Mat — Full API + MongoDB Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-memory seed API with a MongoDB-backed Elysia API exposing every endpoint the Flutter app needs (users, gyms, open-mats, check-ins/reviews, favorites, notifications, settings), with Auth0 JWT auth + a bypass secret, TypeBox validation, `VALIDATION:`-prefixed logs, and a Postman collection.

**Architecture:** Strict layering — Routes → Facade (BAL) → Repository (DAL) → MongoDB native driver. Facades receive repositories (never the `Db`), structurally enforcing "BAL never touches data directly." Composition root in `container.mts` wires `MongoClient` → repositories → facades → routes. Shapes live in `@bjj/contract` (TypeBox, one concept per file), consumed by Elysia for runtime validation and emitted at `GET /openapi.json`.

**Tech Stack:** Bun 1.3, Elysia 1.2, TypeBox (`@sinclair/typebox` 0.34), MongoDB native driver **6.21** (see driver note), Winston, `jose` (JWKS/JWT verify), Turborepo. Tests: `bun test` (socket-bound boot test against a real ephemeral MongoDB).

> **Driver version note (applied during execution):** The plan originally specified `mongodb@^7.3`. That fails to load under Bun 1.3.x — `bson@7` calls `node:v8`'s `isBuildingSnapshot()` at module init, which Bun (1.3.12 and 1.3.14) does not implement. Pinned to `mongodb@^6.21.0` instead: it loads cleanly under Bun and still provides every feature this plan uses (CSOT `timeoutMS` ≥6.11, `AbortSignal` ≥6.13, `$geoNear`, parent-handle access ≥6.20). Repository code is unchanged. Revisit 7.x once a Bun release implements the missing v8 API.

**Spec:** `docs/superpowers/specs/2026-06-17-mongodb-api-design.md`

---

## Execution note: intermediate type-check is red during the API rewrite

After Phase 1, the old seed-era API files (`src/data/seed.mts`, `src/openapi.mts`, `src/services/open-mat.service.mts`) reference removed contract symbols and won't type-check. They are interdependent with the old `container.mts`/`app.mts`, so they're replaced as a unit across Phases 6–8 (container/app/routes in Phase 6, openapi in Phase 7, seed migrated + service deleted by Phase 6/8). Until then, **do not gate on whole-package `bun run type-check`** — verify each new module via its own `bun test <file>` (Bun transpiles per-file and the new tests don't import the broken old files). The full `type-check` + `lint` + `test` gate runs at Task 8.3.

## Conventions for every task

- TypeScript strict. No `any` (use `unknown` + parse). Explicit return types and access modifiers. Double quotes, trailing commas, named exports.
- Source files are `.mts`; internal imports use explicit `.mts` specifiers.
- Each enum / schema / derived type in its own file; barrels via `index.mts`.
- One interface/schema concept per file.
- Run `bun run --filter @bjj/api type-check` and `bun run --filter @bjj/api lint` after each implementation step; both must be clean before commit.
- Tests live in `apps/api/test/`. Run a single file with `bun test test/<file>` from `apps/api`.
- Commit messages use Conventional Commits. Never add Co-Authored-By lines.
- Health endpoints are `/health` + `/ready` — never `/healthz`.

---

## File Structure Map

### `packages/contract/src/`
```
enums/
  belt-rank.mts            BeltRank union + type
  skill-level.mts          SkillLevel
  gi-type.mts              GiType (gi|nogi|both)
  user-role.mts            UserRole (practitioner|gym_owner)
  notification-type.mts    NotificationType
  review-category.mts      ReviewCategory
  index.mts                barrel
schemas/
  geo-location.mts         GeoLocation {lat,lng}
  user.mts                 User, UserSettings (embedded)
  gym.mts                  Gym
  open-mat.mts             OpenMat (list item)
  open-mat-detail.mts      OpenMatDetail (+location)
  attendee.mts             Attendee
  check-in.mts             CheckIn
  review.mts               Review category ratings
  favorite.mts             Favorite (and FavoriteGym view = Gym)
  notification.mts         Notification
  requests/
    user-requests.mts      UpdateUserRequest, UpdateSettingsRequest
    gym-requests.mts       CreateGymRequest, UpdateGymRequest, NearbyQuery, GymListQuery
    open-mat-requests.mts  CreateOpenMatRequest, UpdateOpenMatRequest, OpenMatListQuery, RsvpRequest, CheckinRequest
    check-in-requests.mts  ReviewRequest, CheckinsQuery, AttendeesQuery, MyCheckinsQuery
    notification-requests.mts NotificationListQuery
    index.mts              barrel
  responses/
    envelope.mts           DataResponse<T>, ListResponse<T>, ListMeta, ErrorResponse
    health.mts             HealthResponse, ReadyResponse
    index.mts              barrel
  index.mts                barrel (geo/user/gym/... + requests + responses)
types/
  index.mts                re-exports all Static<> types (already exported alongside schemas)
index.mts                  top-level barrel (export * from enums, schemas)
```

### `apps/api/src/`
```
config/
  logger.mts               (exists) Winston
  env.mts                  TypeBox-validated env (MONGODB_URI, DB name, Auth0, bypass)
db/
  mongo.mts                createMongoClient(env) -> { client, db }
  collections.mts          collection name constants + typed doc helpers
auth/
  auth.types.mts           AuthIdentity interface
  jwt-verifier.mts         JwksVerifier (jose) + bypass
  auth.middleware.mts      Elysia plugin: resolve identity, requireAuth, requireOwner
http/
  envelope.mts             data(), list() helpers
  errors.mts               typed AppError + httpStatusFor
  error-handler.mts        Elysia onError -> VALIDATION: logging + ErrorResponse
repositories/             (DAL — only layer importing the driver)
  base.repository.mts      shared helpers (parse-on-read, toId)
  user.repository.mts
  gym.repository.mts
  open-mat.repository.mts
  rsvp.repository.mts
  check-in.repository.mts
  favorite.repository.mts
  notification.repository.mts
facades/                  (BAL — consume repositories only)
  user.facade.mts
  gym.facade.mts
  open-mat.facade.mts
  check-in.facade.mts
  favorite.facade.mts
  notification.facade.mts
routes/
  health.routes.mts        (exists; extend /ready to ping Mongo)
  user.routes.mts
  gym.routes.mts
  open-mat.routes.mts      (replaces existing open-mat.routes.mts)
  check-in.routes.mts
  favorite.routes.mts
  notification.routes.mts
data/
  seed.mts                 (exists) fixtures — reused by seed script
  seed-runner.mts          bun run seed entrypoint (upsert fixtures into Mongo)
container.mts              (rewrite) composition root
app.mts                    (rewrite) build Elysia graph w/ auth + error handler
openapi.mts                (rewrite) full component + path set
index.mts                  (exists) boot + listen
```

### Root / infra
```
docker-compose.yml         MongoDB 7 for local dev
.env.example               (extend) MONGODB_URI, MONGODB_DB, AUTH0_*, AUTH_BYPASS_SECRET, DEMO_*
docs/postman/
  bjj-open-mat.postman_collection.json
  bjj-open-mat.postman_environment.json
```

---

## PHASE 0 — Dependencies, env, docker-compose

### Task 0.1: Add runtime dependencies

**Files:**
- Modify: `apps/api/package.json`

- [ ] **Step 1: Add deps**

In `apps/api/package.json` `dependencies`, add `mongodb` and `jose`; add a `seed` script.

```jsonc
  "scripts": {
    "dev": "bun --watch src/index.mts",
    "start": "bun src/index.mts",
    "seed": "bun src/data/seed-runner.mts",
    "type-check": "tsc --noEmit",
    "lint": "eslint src test",
    "test": "bun test",
    "verify": "bun run type-check && bun run lint && bun run test"
  },
  "dependencies": {
    "@bjj/contract": "workspace:*",
    "@sinclair/typebox": "^0.34.0",
    "elysia": "^1.2.0",
    "jose": "^5.9.0",
    "mongodb": "^7.3.0",
    "winston": "^3.17.0"
  },
```

- [ ] **Step 2: Install**

Run (from repo root): `bun install`
Expected: `mongodb` and `jose` resolved, lockfile saved.

- [ ] **Step 3: Commit**

```bash
git add apps/api/package.json bun.lock
git commit -m "chore: add mongodb and jose deps to @bjj/api"
```

### Task 0.2: docker-compose for local MongoDB

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write compose file**

```yaml
services:
  mongo:
    image: mongo:7
    container_name: bjj-mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - bjj-mongo-data:/data/db

volumes:
  bjj-mongo-data:
```

- [ ] **Step 2: Verify it boots**

Run: `docker compose up -d && docker compose ps`
Expected: `bjj-mongo` listed as running. (If Docker is unavailable, note as blocker; an Atlas `MONGODB_URI` is the alternative.)

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: add docker-compose for local MongoDB"
```

### Task 0.3: Extend `.env.example`

**Files:**
- Modify: `.env.example`

- [ ] **Step 1: Write env keys**

```bash
# BJJ Open Mat API
PORT=3100

# MongoDB (Atlas connection string or local container)
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB=bjj_open_mat

# Auth0 (JWT verification)
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://api.bjj-open-mat

# Dev/test auth bypass — present this exact string as the Bearer token to skip JWT verification
AUTH_BYPASS_SECRET=TopFlightApiSecurity2026+
DEMO_USER_ID=u-me
DEMO_USER_ROLE=gym_owner
DEMO_USER_EMAIL=demo@bjj-open-mat.test
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: document mongo + auth env vars"
```

---

## PHASE 1 — Contract restructure (`packages/contract`)

> The current `packages/contract/src/index.mts` is monolithic. We split it into per-concept files. Keep the existing schema content; relocate and add new entities.

### Task 1.1: Enums

**Files:**
- Create: `packages/contract/src/enums/belt-rank.mts`, `skill-level.mts`, `gi-type.mts`, `user-role.mts`, `notification-type.mts`, `review-category.mts`, `index.mts`

- [ ] **Step 1: Write each enum file**

`belt-rank.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const BeltRank = t.Union(
  [t.Literal("white"), t.Literal("blue"), t.Literal("purple"), t.Literal("brown"), t.Literal("black")],
  { $id: "BeltRank" },
);
export type BeltRank = Static<typeof BeltRank>;
```

`skill-level.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const SkillLevel = t.Union(
  [t.Literal("all"), t.Literal("beginner"), t.Literal("intermediate"), t.Literal("advanced")],
  { $id: "SkillLevel" },
);
export type SkillLevel = Static<typeof SkillLevel>;
```

`gi-type.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

// Stored on a session AND used as a search filter. Filter semantics (facade):
// gi -> matches gi|both; nogi -> matches nogi|both; omitted -> all.
export const GiType = t.Union(
  [t.Literal("gi"), t.Literal("nogi"), t.Literal("both")],
  { $id: "GiType" },
);
export type GiType = Static<typeof GiType>;
```

`user-role.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const UserRole = t.Union(
  [t.Literal("practitioner"), t.Literal("gym_owner")],
  { $id: "UserRole" },
);
export type UserRole = Static<typeof UserRole>;
```

`notification-type.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const NotificationType = t.Union(
  [t.Literal("rsvp"), t.Literal("review"), t.Literal("session_update"), t.Literal("system")],
  { $id: "NotificationType" },
);
export type NotificationType = Static<typeof NotificationType>;
```

`review-category.mts`:
```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const ReviewCategory = t.Union(
  [
    t.Literal("instruction"),
    t.Literal("cleanliness"),
    t.Literal("variety"),
    t.Literal("worth_returning"),
    t.Literal("overall"),
  ],
  { $id: "ReviewCategory" },
);
export type ReviewCategory = Static<typeof ReviewCategory>;
```

`index.mts`:
```typescript
export * from "./belt-rank.mts";
export * from "./skill-level.mts";
export * from "./gi-type.mts";
export * from "./user-role.mts";
export * from "./notification-type.mts";
export * from "./review-category.mts";
```

- [ ] **Step 2: type-check**

Run (from `packages/contract`): `bun run type-check`
Expected: clean (no consumers yet).

- [ ] **Step 3: Commit**

```bash
git add packages/contract/src/enums
git commit -m "feat(contract): add enum modules (belt, skill, gi, role, notification, review)"
```

### Task 1.2: Entity schemas

**Files:**
- Create under `packages/contract/src/schemas/`: `geo-location.mts`, `user.mts`, `gym.mts`, `open-mat.mts`, `open-mat-detail.mts`, `attendee.mts`, `check-in.mts`, `review.mts`, `favorite.mts`, `notification.mts`

- [ ] **Step 1: Write `geo-location.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const GeoLocation = t.Object(
  { lat: t.Number({ minimum: -90, maximum: 90 }), lng: t.Number({ minimum: -180, maximum: 180 }) },
  { $id: "GeoLocation" },
);
export type GeoLocation = Static<typeof GeoLocation>;
```

- [ ] **Step 2: Write `user.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { UserRole } from "../enums/user-role.mts";

export const UserSettings = t.Object(
  {
    theme: t.Union([t.Literal("sport"), t.Literal("glass")], { default: "glass" }),
    notifyRsvp: t.Boolean({ default: true }),
    notifySessionUpdates: t.Boolean({ default: true }),
  },
  { $id: "UserSettings" },
);
export type UserSettings = Static<typeof UserSettings>;

export const User = t.Object(
  {
    id: t.String(),
    auth0Id: t.Optional(t.String()),
    email: t.String({ format: "email" }),
    displayName: t.String(),
    role: UserRole,
    beltRank: t.Optional(BeltRank),
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    weight: t.Optional(t.String()),
    bio: t.Optional(t.String()),
    avatarUrl: t.Optional(t.String()),
    homeGymId: t.Optional(t.String()),
    settings: t.Optional(UserSettings),
    createdAt: t.Optional(t.String()),
  },
  { $id: "User" },
);
export type User = Static<typeof User>;
```

- [ ] **Step 3: Write `gym.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { GeoLocation } from "./geo-location.mts";

export const Gym = t.Object(
  {
    id: t.String(),
    ownerId: t.Optional(t.String()),
    name: t.String(),
    description: t.Optional(t.String()),
    address: t.String(),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    country: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    location: t.Optional(GeoLocation),
    googlePlaceId: t.Optional(t.String()),
    phone: t.Optional(t.String()),
    website: t.Optional(t.String()),
    amenities: t.Array(t.String(), { default: [] }),
    isVerified: t.Boolean({ default: false }),
    rating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "Gym" },
);
export type Gym = Static<typeof Gym>;
```

- [ ] **Step 4: Write `open-mat.mts`** (note `giType` replaces `isGiSession`)

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { GiType } from "../enums/gi-type.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const OpenMat = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    hostId: t.Optional(t.String()),
    title: t.String(),
    description: t.Optional(t.String()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm" }),
    endTime: t.String({ description: "24h HH:mm" }),
    isRecurring: t.Boolean({ default: true }),
    specificDate: t.Optional(t.String({ description: "ISO date YYYY-MM-DD" })),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: SkillLevel,
    giType: GiType,
    isCancelled: t.Boolean({ default: false }),
    feeCents: t.Optional(t.Integer({ minimum: 0 })),
    attendeeCount: t.Optional(t.Integer({ minimum: 0 })),
    gymName: t.Optional(t.String()),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "OpenMat" },
);
export type OpenMat = Static<typeof OpenMat>;
```

- [ ] **Step 5: Write `open-mat-detail.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { OpenMat } from "./open-mat.mts";

export const OpenMatDetail = t.Composite(
  [
    OpenMat,
    t.Object({
      latitude: t.Number(),
      longitude: t.Number(),
      address: t.String(),
      city: t.String(),
      state: t.String(),
      postalCode: t.Optional(t.String()),
      gymRating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    }),
  ],
  { $id: "OpenMatDetail" },
);
export type OpenMatDetail = Static<typeof OpenMatDetail>;
```

- [ ] **Step 6: Write `attendee.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const Attendee = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    skillLevel: SkillLevel,
    avatarUrl: t.Optional(t.String({ format: "uri" })),
    rsvpAt: t.String(),
  },
  { $id: "Attendee" },
);
export type Attendee = Static<typeof Attendee>;
```

- [ ] **Step 7: Write `review.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

// 0–5 score per category collected by the review screen.
export const CategoryRatings = t.Object(
  {
    instruction: t.Number({ minimum: 0, maximum: 5 }),
    cleanliness: t.Number({ minimum: 0, maximum: 5 }),
    variety: t.Number({ minimum: 0, maximum: 5 }),
    worth_returning: t.Number({ minimum: 0, maximum: 5 }),
    overall: t.Number({ minimum: 0, maximum: 5 }),
  },
  { $id: "CategoryRatings" },
);
export type CategoryRatings = Static<typeof CategoryRatings>;
```

- [ ] **Step 8: Write `check-in.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { CategoryRatings } from "./review.mts";

export const CheckIn = t.Object(
  {
    id: t.String(),
    openMatId: t.String(),
    userId: t.String(),
    sessionDate: t.String(),
    checkedInAt: t.String(),
    rating: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    review: t.Optional(t.String()),
    categoryRatings: t.Optional(CategoryRatings),
    gymName: t.Optional(t.String()),
    openMatTitle: t.Optional(t.String()),
    userName: t.Optional(t.String()),
    beltRank: t.Optional(BeltRank),
    createdAt: t.Optional(t.String()),
  },
  { $id: "CheckIn" },
);
export type CheckIn = Static<typeof CheckIn>;
```

- [ ] **Step 9: Write `favorite.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const Favorite = t.Object(
  { userId: t.String(), gymId: t.String(), createdAt: t.String() },
  { $id: "Favorite" },
);
export type Favorite = Static<typeof Favorite>;
```

- [ ] **Step 10: Write `notification.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { NotificationType } from "../enums/notification-type.mts";

export const Notification = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    type: NotificationType,
    title: t.String(),
    body: t.String(),
    read: t.Boolean({ default: false }),
    data: t.Optional(t.Record(t.String(), t.Unknown())),
    createdAt: t.String(),
  },
  { $id: "Notification" },
);
export type Notification = Static<typeof Notification>;
```

- [ ] **Step 11: type-check & commit**

Run (from `packages/contract`): `bun run type-check` → clean.
```bash
git add packages/contract/src/schemas
git commit -m "feat(contract): add entity schemas (user, gym, open-mat, check-in, favorite, notification)"
```

### Task 1.3: Request schemas

**Files:**
- Create under `packages/contract/src/schemas/requests/`: `user-requests.mts`, `gym-requests.mts`, `open-mat-requests.mts`, `check-in-requests.mts`, `notification-requests.mts`, `index.mts`

> **Correction (applied during execution):** Use `t.Number(...)` for numeric query fields, NOT `t.Numeric(...)`. `t.Numeric` is an Elysia-only extension and is not available on framework-agnostic `@sinclair/typebox`, which is the only dependency of `@bjj/contract`. Elysia auto-coerces numeric query strings against `t.Number()` schemas at the route layer, so behavior is preserved. The code blocks below show `t.Numeric` historically; the implemented files use `t.Number`.

- [ ] **Step 1: `user-requests.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { UserSettings } from "../user.mts";

export const UpdateUserRequest = t.Partial(
  t.Object({
    displayName: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    weight: t.String(),
    bio: t.String(),
    avatarUrl: t.String(),
    homeGymId: t.String(),
  }),
  { $id: "UpdateUserRequest" },
);
export type UpdateUserRequest = Static<typeof UpdateUserRequest>;

export const UpdateSettingsRequest = t.Partial(UserSettings, { $id: "UpdateSettingsRequest" });
export type UpdateSettingsRequest = Static<typeof UpdateSettingsRequest>;
```

- [ ] **Step 2: `gym-requests.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { GeoLocation } from "../geo-location.mts";

export const CreateGymRequest = t.Object(
  {
    name: t.String({ minLength: 1 }),
    description: t.Optional(t.String()),
    address: t.String({ minLength: 1 }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    country: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    location: t.Optional(GeoLocation),
    googlePlaceId: t.Optional(t.String()),
    phone: t.Optional(t.String()),
    website: t.Optional(t.String()),
    amenities: t.Optional(t.Array(t.String())),
  },
  { $id: "CreateGymRequest" },
);
export type CreateGymRequest = Static<typeof CreateGymRequest>;

export const UpdateGymRequest = t.Partial(CreateGymRequest, { $id: "UpdateGymRequest" });
export type UpdateGymRequest = Static<typeof UpdateGymRequest>;

export const NearbyQuery = t.Object(
  {
    lat: t.Numeric(),
    lng: t.Numeric(),
    radiusKm: t.Optional(t.Numeric({ minimum: 1, maximum: 500, default: 25 })),
  },
  { $id: "NearbyQuery" },
);
export type NearbyQuery = Static<typeof NearbyQuery>;

export const GymListQuery = t.Object(
  {
    mine: t.Optional(t.Boolean()),
    page: t.Optional(t.Numeric({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Numeric({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "GymListQuery" },
);
export type GymListQuery = Static<typeof GymListQuery>;
```

- [ ] **Step 3: `open-mat-requests.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { GiType } from "../../enums/gi-type.mts";
import { SkillLevel } from "../../enums/skill-level.mts";

export const CreateOpenMatRequest = t.Object(
  {
    gymId: t.String(),
    hostId: t.Optional(t.String()),
    title: t.String({ minLength: 1 }),
    description: t.Optional(t.String()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String(),
    endTime: t.String(),
    isRecurring: t.Optional(t.Boolean()),
    specificDate: t.Optional(t.String()),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: t.Optional(SkillLevel),
    giType: t.Optional(GiType),
    feeCents: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateOpenMatRequest" },
);
export type CreateOpenMatRequest = Static<typeof CreateOpenMatRequest>;

export const UpdateOpenMatRequest = t.Partial(CreateOpenMatRequest, { $id: "UpdateOpenMatRequest" });
export type UpdateOpenMatRequest = Static<typeof UpdateOpenMatRequest>;

export const OpenMatListQuery = t.Object(
  {
    dayOfWeek: t.Optional(t.Numeric({ minimum: 0, maximum: 6 })),
    giType: t.Optional(GiType),
    skillLevel: t.Optional(SkillLevel),
    lat: t.Optional(t.Numeric()),
    lng: t.Optional(t.Numeric()),
    radiusKm: t.Optional(t.Numeric({ minimum: 1, maximum: 500 })),
    mine: t.Optional(t.Boolean()),
    page: t.Optional(t.Numeric({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Numeric({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "OpenMatListQuery" },
);
export type OpenMatListQuery = Static<typeof OpenMatListQuery>;

export const RsvpRequest = t.Object({ sessionDate: t.String() }, { $id: "RsvpRequest" });
export type RsvpRequest = Static<typeof RsvpRequest>;

export const CheckinRequest = t.Object({ sessionDate: t.String() }, { $id: "CheckinRequest" });
export type CheckinRequest = Static<typeof CheckinRequest>;
```

- [ ] **Step 4: `check-in-requests.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { CategoryRatings } from "../review.mts";

export const ReviewRequest = t.Object(
  {
    rating: t.Integer({ minimum: 1, maximum: 5 }),
    review: t.Optional(t.String()),
    categoryRatings: CategoryRatings,
  },
  { $id: "ReviewRequest" },
);
export type ReviewRequest = Static<typeof ReviewRequest>;

export const SessionDateQuery = t.Object(
  { sessionDate: t.Optional(t.String()), date: t.Optional(t.String()) },
  { $id: "SessionDateQuery" },
);
export type SessionDateQuery = Static<typeof SessionDateQuery>;

export const PageQuery = t.Object(
  {
    page: t.Optional(t.Numeric({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Numeric({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "PageQuery" },
);
export type PageQuery = Static<typeof PageQuery>;
```

- [ ] **Step 5: `notification-requests.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const NotificationListQuery = t.Object(
  {
    unread: t.Optional(t.Boolean()),
    page: t.Optional(t.Numeric({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Numeric({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "NotificationListQuery" },
);
export type NotificationListQuery = Static<typeof NotificationListQuery>;
```

- [ ] **Step 6: `requests/index.mts`**

```typescript
export * from "./user-requests.mts";
export * from "./gym-requests.mts";
export * from "./open-mat-requests.mts";
export * from "./check-in-requests.mts";
export * from "./notification-requests.mts";
```

- [ ] **Step 7: type-check & commit**

Run (from `packages/contract`): `bun run type-check` → clean.
```bash
git add packages/contract/src/schemas/requests
git commit -m "feat(contract): add request schemas"
```

### Task 1.4: Response envelope + health schemas + barrels

**Files:**
- Create: `packages/contract/src/schemas/responses/envelope.mts`, `health.mts`, `index.mts`
- Create: `packages/contract/src/schemas/index.mts`, `packages/contract/src/types/index.mts`
- Rewrite: `packages/contract/src/index.mts`

- [ ] **Step 1: `responses/envelope.mts`**

```typescript
import { type Static, type TSchema, Type as t } from "@sinclair/typebox";

export const ListMeta = t.Object(
  { page: t.Integer({ minimum: 1 }), limit: t.Integer({ minimum: 1 }), total: t.Integer({ minimum: 0 }) },
  { $id: "ListMeta" },
);
export type ListMeta = Static<typeof ListMeta>;

// Generic envelope builders for OpenAPI composition.
export const DataResponse = <T extends TSchema>(data: T): ReturnType<typeof t.Object> =>
  t.Object({ data });
export const ListResponse = <T extends TSchema>(item: T): ReturnType<typeof t.Object> =>
  t.Object({ data: t.Array(item), meta: ListMeta });

export const ErrorResponse = t.Object(
  {
    error: t.Object({
      code: t.String(),
      message: t.String(),
      details: t.Optional(t.Unknown()),
    }),
  },
  { $id: "ErrorResponse" },
);
export type ErrorResponse = Static<typeof ErrorResponse>;
```

- [ ] **Step 2: `responses/health.mts`** (moved from old index)

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const HealthResponse = t.Object(
  { status: t.Literal("ok"), uptimeSeconds: t.Number() },
  { $id: "HealthResponse" },
);
export type HealthResponse = Static<typeof HealthResponse>;

export const ReadyResponse = t.Object(
  { status: t.Union([t.Literal("ready"), t.Literal("degraded")]), checks: t.Record(t.String(), t.Boolean()) },
  { $id: "ReadyResponse" },
);
export type ReadyResponse = Static<typeof ReadyResponse>;
```

- [ ] **Step 3: `responses/index.mts`**

```typescript
export * from "./envelope.mts";
export * from "./health.mts";
```

- [ ] **Step 4: `schemas/index.mts`**

```typescript
export * from "./geo-location.mts";
export * from "./user.mts";
export * from "./gym.mts";
export * from "./open-mat.mts";
export * from "./open-mat-detail.mts";
export * from "./attendee.mts";
export * from "./review.mts";
export * from "./check-in.mts";
export * from "./favorite.mts";
export * from "./notification.mts";
export * from "./requests/index.mts";
export * from "./responses/index.mts";
```

- [ ] **Step 5: `types/index.mts`**

```typescript
// Derived static types are exported alongside their schemas; this barrel
// re-exports them for consumers that want types only.
export type * from "../enums/index.mts";
export type * from "../schemas/index.mts";
```

- [ ] **Step 6: Rewrite top-level `index.mts`**

```typescript
// @bjj/contract — single source of truth for the BJJ Open Mat API.
// Framework-agnostic TypeBox schemas + derived static types.
export * from "./enums/index.mts";
export * from "./schemas/index.mts";
```

- [ ] **Step 7: Delete old inline definitions**

The old monolithic content in `index.mts` is fully replaced by Step 6. Confirm no other file imports removed symbols by name path (all imports use the package root `@bjj/contract`).

- [ ] **Step 8: type-check & commit**

Run (from `packages/contract`): `bun run type-check` → clean.
```bash
git add packages/contract/src
git commit -m "feat(contract): split into per-concept modules with response envelope"
```

---

## PHASE 2 — Mongo plumbing & config

### Task 2.1: Env config (TypeBox-validated)

**Files:**
- Create: `apps/api/src/config/env.mts`
- Test: `apps/api/test/env.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

describe("loadEnv", () => {
  it("parses a complete env object", () => {
    const env = loadEnv({
      PORT: "3100",
      MONGODB_URI: "mongodb://localhost:27017",
      MONGODB_DB: "bjj_test",
      AUTH0_DOMAIN: "t.us.auth0.com",
      AUTH0_AUDIENCE: "https://api",
      AUTH_BYPASS_SECRET: "secret",
      DEMO_USER_ID: "u-me",
      DEMO_USER_ROLE: "gym_owner",
      DEMO_USER_EMAIL: "demo@test.dev",
    });
    expect(env.port).toBe(3100);
    expect(env.mongoDb).toBe("bjj_test");
    expect(env.demoUser.role).toBe("gym_owner");
  });

  it("throws when MONGODB_URI is missing", () => {
    expect(() => loadEnv({ MONGODB_DB: "x" })).toThrow();
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run (from `apps/api`): `bun test test/env.test.mts`
Expected: FAIL — `loadEnv` not exported.

- [ ] **Step 3: Implement `env.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { Value } from "@sinclair/typebox/value";

const EnvSchema = t.Object({
  PORT: t.Optional(t.String()),
  MONGODB_URI: t.String({ minLength: 1 }),
  MONGODB_DB: t.String({ minLength: 1 }),
  AUTH0_DOMAIN: t.Optional(t.String()),
  AUTH0_AUDIENCE: t.Optional(t.String()),
  AUTH_BYPASS_SECRET: t.String({ minLength: 1 }),
  DEMO_USER_ID: t.String({ minLength: 1 }),
  DEMO_USER_ROLE: t.Union([t.Literal("practitioner"), t.Literal("gym_owner")]),
  DEMO_USER_EMAIL: t.String({ minLength: 1 }),
});

type RawEnv = Static<typeof EnvSchema>;

export interface AppEnv {
  readonly port: number;
  readonly mongoUri: string;
  readonly mongoDb: string;
  readonly auth0Domain: string | undefined;
  readonly auth0Audience: string | undefined;
  readonly bypassSecret: string;
  readonly demoUser: { readonly id: string; readonly role: "practitioner" | "gym_owner"; readonly email: string };
}

export function loadEnv(source: Record<string, string | undefined> = process.env): AppEnv {
  const raw: RawEnv = Value.Parse(EnvSchema, source);
  return {
    port: Number(raw.PORT ?? "3100"),
    mongoUri: raw.MONGODB_URI,
    mongoDb: raw.MONGODB_DB,
    auth0Domain: raw.AUTH0_DOMAIN,
    auth0Audience: raw.AUTH0_AUDIENCE,
    bypassSecret: raw.AUTH_BYPASS_SECRET,
    demoUser: { id: raw.DEMO_USER_ID, role: raw.DEMO_USER_ROLE, email: raw.DEMO_USER_EMAIL },
  };
}
```

- [ ] **Step 4: Run, verify pass**

Run (from `apps/api`): `bun test test/env.test.mts` → PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/config/env.mts apps/api/test/env.test.mts
git commit -m "feat(api): TypeBox-validated env loader"
```

### Task 2.2: Mongo client + collection registry

**Files:**
- Create: `apps/api/src/db/mongo.mts`, `apps/api/src/db/collections.mts`

- [ ] **Step 1: `collections.mts`**

```typescript
export const COLLECTIONS = {
  users: "users",
  gyms: "gyms",
  openMats: "openMats",
  rsvps: "rsvps",
  checkins: "checkins",
  favorites: "favorites",
  notifications: "notifications",
} as const;

export type CollectionName = (typeof COLLECTIONS)[keyof typeof COLLECTIONS];
```

- [ ] **Step 2: `mongo.mts`**

```typescript
import { type Db, MongoClient } from "mongodb";
import type { AppEnv } from "../config/env.mts";

export interface MongoContext {
  readonly client: MongoClient;
  readonly db: Db;
}

// v7 driver: timeoutMS applies CSOT across the whole operation chain.
export function createMongoContext(env: AppEnv): MongoContext {
  const client = new MongoClient(env.mongoUri, { timeoutMS: 10_000 });
  const db = client.db(env.mongoDb);
  return { client, db };
}
```

- [ ] **Step 3: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/db
git commit -m "feat(api): mongo client context + collection registry"
```

---

## PHASE 3 — Cross-cutting: envelope, errors, validation logging, auth

### Task 3.1: HTTP envelope + typed errors

**Files:**
- Create: `apps/api/src/http/envelope.mts`, `apps/api/src/http/errors.mts`
- Test: `apps/api/test/envelope.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { data, list } from "../src/http/envelope.mts";

describe("envelope", () => {
  it("wraps a single item under data", () => {
    expect(data({ id: "x" })).toEqual({ data: { id: "x" } });
  });

  it("wraps a list with meta", () => {
    expect(list([{ id: "x" }], { page: 1, limit: 20, total: 1 })).toEqual({
      data: [{ id: "x" }],
      meta: { page: 1, limit: 20, total: 1 },
    });
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run (from `apps/api`): `bun test test/envelope.test.mts` → FAIL.

- [ ] **Step 3: Implement `envelope.mts`**

```typescript
import type { ListMeta } from "@bjj/contract";

export function data<T>(value: T): { data: T } {
  return { data: value };
}

export function list<T>(items: T[], meta: ListMeta): { data: T[]; meta: ListMeta } {
  return { data: items, meta };
}
```

- [ ] **Step 4: Implement `errors.mts`**

```typescript
export type AppErrorCode =
  | "not_found"
  | "forbidden"
  | "unauthorized"
  | "conflict"
  | "bad_request";

export class AppError extends Error {
  public constructor(
    public readonly code: AppErrorCode,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export function httpStatusFor(code: AppErrorCode): number {
  switch (code) {
    case "not_found":
      return 404;
    case "forbidden":
      return 403;
    case "unauthorized":
      return 401;
    case "conflict":
      return 409;
    case "bad_request":
      return 400;
  }
}
```

- [ ] **Step 5: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/envelope.test.mts` → PASS.
```bash
git add apps/api/src/http/envelope.mts apps/api/src/http/errors.mts apps/api/test/envelope.test.mts
git commit -m "feat(api): response envelope helpers + typed AppError"
```

### Task 3.2: Error handler with `VALIDATION:` logging

**Files:**
- Create: `apps/api/src/http/error-handler.mts`
- Test: `apps/api/test/error-handler.test.mts`

- [ ] **Step 1: Write failing test** (asserts a `VALIDATION:`-prefixed log line is emitted on a validation error)

```typescript
import { describe, expect, it } from "bun:test";
import { Elysia, t } from "elysia";
import { registerErrorHandler } from "../src/http/error-handler.mts";

describe("error handler", () => {
  it("logs validation failures with VALIDATION: prefix and returns 400 envelope", async () => {
    const lines: string[] = [];
    const app = registerErrorHandler(
      new Elysia(),
      { warn: (m: string) => lines.push(m), error: () => {} },
    ).post("/echo", ({ body }) => body, { body: t.Object({ name: t.String() }) });

    const res = await app.handle(
      new Request("http://localhost/echo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: 123 }),
      }),
    );

    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json.error.code).toBe("bad_request");
    expect(lines.some((l) => l.startsWith("VALIDATION: "))).toBe(true);
  });

  it("maps AppError not_found to 404", async () => {
    const { AppError } = await import("../src/http/errors.mts");
    const app = registerErrorHandler(new Elysia(), { warn: () => {}, error: () => {} }).get("/x", () => {
      throw new AppError("not_found", "nope");
    });
    const res = await app.handle(new Request("http://localhost/x"));
    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run (from `apps/api`): `bun test test/error-handler.test.mts` → FAIL.

- [ ] **Step 3: Implement `error-handler.mts`**

```typescript
import type { Elysia } from "elysia";
import { AppError, httpStatusFor } from "./errors.mts";

export interface ErrorLogger {
  warn(message: string): void;
  error(message: string): void;
}

// Registers a global onError hook. Validation failures are logged with a
// "VALIDATION: " prefix so they are trivially greppable.
export function registerErrorHandler<T extends Elysia>(app: T, logger: ErrorLogger): T {
  return app.onError(({ code, error, set, request, path }) => {
    if (code === "VALIDATION") {
      const message = error instanceof Error ? error.message : String(error);
      logger.warn(`VALIDATION: ${request.method} ${path} — ${message.replace(/\s+/g, " ").trim()}`);
      set.status = 400;
      return { error: { code: "bad_request", message: "Request validation failed", details: message } };
    }

    if (error instanceof AppError) {
      set.status = httpStatusFor(error.code);
      return { error: { code: error.code, message: error.message, details: error.details } };
    }

    if (code === "NOT_FOUND") {
      set.status = 404;
      return { error: { code: "not_found", message: "Route not found" } };
    }

    logger.error(`${request.method} ${path} — ${error instanceof Error ? error.message : String(error)}`);
    set.status = 500;
    return { error: { code: "internal_error", message: "Internal server error" } };
  }) as T;
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/error-handler.test.mts` → PASS.
```bash
git add apps/api/src/http/error-handler.mts apps/api/test/error-handler.test.mts
git commit -m "feat(api): global error handler with VALIDATION: logging"
```

### Task 3.3: Auth identity + JWT verifier with bypass

**Files:**
- Create: `apps/api/src/auth/auth.types.mts`, `apps/api/src/auth/jwt-verifier.mts`
- Test: `apps/api/test/jwt-verifier.test.mts`

- [ ] **Step 1: `auth.types.mts`**

```typescript
import type { UserRole } from "@bjj/contract";

export interface AuthIdentity {
  readonly userId: string;
  readonly role: UserRole;
  readonly email: string;
  readonly viaBypass: boolean;
}
```

- [ ] **Step 2: Write failing test for the bypass path**

```typescript
import { describe, expect, it } from "bun:test";
import { JwtVerifier } from "../src/auth/jwt-verifier.mts";

const verifier = new JwtVerifier({
  bypassSecret: "SECRET",
  demoUser: { id: "u-me", role: "gym_owner", email: "demo@test.dev" },
  auth0Domain: undefined,
  auth0Audience: undefined,
});

describe("JwtVerifier", () => {
  it("resolves the demo identity for the bypass secret", async () => {
    const id = await verifier.verify("SECRET");
    expect(id).toEqual({ userId: "u-me", role: "gym_owner", email: "demo@test.dev", viaBypass: true });
  });

  it("returns null for a missing token", async () => {
    expect(await verifier.verify(undefined)).toBeNull();
  });

  it("throws for a malformed non-bypass token when Auth0 is configured-less", async () => {
    await expect(verifier.verify("not-a-jwt")).rejects.toBeDefined();
  });
});
```

- [ ] **Step 3: Run, verify fail**

Run (from `apps/api`): `bun test test/jwt-verifier.test.mts` → FAIL.

- [ ] **Step 4: Implement `jwt-verifier.mts`**

```typescript
import { createRemoteJWKSet, jwtVerify } from "jose";
import type { UserRole } from "@bjj/contract";
import type { AuthIdentity } from "./auth.types.mts";

export interface JwtVerifierConfig {
  readonly bypassSecret: string;
  readonly demoUser: { readonly id: string; readonly role: UserRole; readonly email: string };
  readonly auth0Domain: string | undefined;
  readonly auth0Audience: string | undefined;
}

type Jwks = ReturnType<typeof createRemoteJWKSet>;

export class JwtVerifier {
  private readonly jwks: Jwks | undefined;

  public constructor(private readonly config: JwtVerifierConfig) {
    this.jwks = config.auth0Domain
      ? createRemoteJWKSet(new URL(`https://${config.auth0Domain}/.well-known/jwks.json`))
      : undefined;
  }

  // Returns null when no token is present; throws when a present token is invalid.
  public async verify(token: string | undefined): Promise<AuthIdentity | null> {
    if (!token) return null;

    if (token === this.config.bypassSecret) {
      return { ...this.config.demoUser, userId: this.config.demoUser.id, viaBypass: true } as AuthIdentity;
    }

    if (!this.jwks) {
      throw new Error("Auth0 not configured and token is not the bypass secret");
    }

    const { payload } = await jwtVerify(token, this.jwks, {
      issuer: `https://${this.config.auth0Domain}/`,
      audience: this.config.auth0Audience,
    });

    const role = (payload["https://bjj/role"] as UserRole | undefined) ?? "practitioner";
    return {
      userId: String(payload.sub),
      role,
      email: String(payload["email"] ?? ""),
      viaBypass: false,
    };
  }
}
```

> Note: the demo-user spread sets `userId` from `id`; the literal `as AuthIdentity` is acceptable here because all fields are present. Lint allows this single assertion (object is fully constructed).

- [ ] **Step 5: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/jwt-verifier.test.mts` → PASS.
```bash
git add apps/api/src/auth/auth.types.mts apps/api/src/auth/jwt-verifier.mts apps/api/test/jwt-verifier.test.mts
git commit -m "feat(api): Auth0 JWT verifier with bypass secret"
```

### Task 3.4: Auth middleware (Elysia plugin)

**Files:**
- Create: `apps/api/src/auth/auth.middleware.mts`

- [ ] **Step 1: Implement the plugin**

```typescript
import { Elysia } from "elysia";
import { AppError } from "../http/errors.mts";
import type { AuthIdentity } from "./auth.types.mts";
import type { JwtVerifier } from "./jwt-verifier.mts";

function bearer(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const [scheme, value] = header.split(" ");
  return scheme === "Bearer" ? value : undefined;
}

// `resolve` attaches `identity` (possibly null) to context. Guards throw AppError.
export function authPlugin(verifier: JwtVerifier) {
  return new Elysia({ name: "auth" })
    .resolve(async ({ headers }): Promise<{ identity: AuthIdentity | null }> => {
      const token = bearer(headers["authorization"]);
      const identity = await verifier.verify(token);
      return { identity };
    })
    .macro({
      requireAuth: (enabled: boolean) => ({
        beforeHandle({ identity }: { identity: AuthIdentity | null }) {
          if (enabled && !identity) throw new AppError("unauthorized", "Authentication required");
        },
      }),
      requireOwner: (enabled: boolean) => ({
        beforeHandle({ identity }: { identity: AuthIdentity | null }) {
          if (!enabled) return;
          if (!identity) throw new AppError("unauthorized", "Authentication required");
          if (identity.role !== "gym_owner") throw new AppError("forbidden", "Gym owner role required");
        },
      }),
    });
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/auth/auth.middleware.mts
git commit -m "feat(api): Elysia auth plugin (resolve identity + requireAuth/requireOwner)"
```

---

## PHASE 4 — Repositories (DAL)

> Repositories are the ONLY files that import `mongodb`. Each maps Mongo documents to contract types via `Value.Parse` and back. Mongo `_id` is a string we control (we set `id`), so we store documents with an explicit string `_id === id` and project it out.

### Task 4.1: Base repository helpers

> **Addition (applied during execution):** Also create `apps/api/src/config/formats.mts` registering TypeBox string formats (`email`, `uri`) via `FormatRegistry.Set`, and add a side-effect import `import "../config/formats.mts";` at the top of `base.repository.mts`. Without it, repository `Value.Parse` throws `Unknown format 'email'` because TypeBox formats are not registered outside Elysia.

**Files:**
- Create: `apps/api/src/repositories/base.repository.mts`
- Create: `apps/api/src/config/formats.mts`

- [ ] **Step 1: Implement**

```typescript
import type { Collection, Db, Document } from "mongodb";

// Strips Mongo's _id from a fetched doc, returning the domain shape.
export function stripId<T extends Document>(doc: (T & { _id?: unknown }) | null): T | null {
  if (!doc) return null;
  const { _id, ...rest } = doc;
  return rest as unknown as T;
}

export abstract class BaseRepository {
  protected readonly db: Db;

  protected constructor(db: Db) {
    this.db = db;
  }

  protected collection<T extends Document>(name: string): Collection<T> {
    return this.db.collection<T>(name);
  }
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/repositories/base.repository.mts
git commit -m "feat(api): base repository helpers"
```

### Task 4.2: User repository

**Files:**
- Create: `apps/api/src/repositories/user.repository.mts`
- Test: `apps/api/test/user.repository.test.mts`

- [ ] **Step 1: Write failing test** (uses a real Mongo via `MONGODB_URI`, falls back to skip if unreachable)

```typescript
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserRepository } from "../src/repositories/user.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_users");

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("UserRepository", () => {
  it("upserts by auth0Id and reads back", async () => {
    const repo = new UserRepository(db);
    await repo.ensureIndexes();
    const created = await repo.upsertByAuth0Id("auth0|1", {
      id: "u-1",
      email: "a@b.dev",
      displayName: "A",
      role: "practitioner",
    });
    expect(created.id).toBe("u-1");
    const found = await repo.findById("u-1");
    expect(found?.email).toBe("a@b.dev");
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run (from `apps/api`): `bun test test/user.repository.test.mts` → FAIL (no `UserRepository`).
> If Mongo is unreachable, start it: `docker compose up -d`. A connection error here is a blocker, not a skip.

- [ ] **Step 3: Implement `user.repository.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { Value } from "@sinclair/typebox/value";
import type { Db } from "mongodb";
import { User } from "@bjj/contract";
import type { User as UserType } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface UserDoc extends UserType {
  _id: string;
}

const UserDocSchema = t.Composite([User, t.Object({ _id: t.String() })]);
type ParsedUserDoc = Static<typeof UserDocSchema>;

export interface NewUser {
  id: string;
  email: string;
  displayName: string;
  role: UserType["role"];
}

export class UserRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    await col.createIndex({ auth0Id: 1 }, { unique: true, sparse: true });
    await col.createIndex({ email: 1 }, { unique: true });
  }

  public async findById(id: string): Promise<UserType | null> {
    const doc = await this.collection<UserDoc>(COLLECTIONS.users).findOne({ _id: id });
    return stripId<UserType>(doc);
  }

  public async upsertByAuth0Id(auth0Id: string, user: NewUser): Promise<UserType> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    const existing = await col.findOne({ auth0Id });
    if (existing) return stripId<UserType>(existing) as UserType;

    const doc: ParsedUserDoc = Value.Parse(UserDocSchema, {
      _id: user.id,
      id: user.id,
      auth0Id,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      amenities: undefined,
      createdAt: new Date().toISOString(),
    });
    await col.insertOne(doc as unknown as UserDoc);
    return stripId<UserType>(doc as unknown as UserDoc) as UserType;
  }

  public async update(id: string, patch: Partial<UserType>): Promise<UserType | null> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    await col.updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }

  public async insert(user: UserType): Promise<UserType> {
    await this.collection<UserDoc>(COLLECTIONS.users).insertOne({ ...user, _id: user.id });
    return user;
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/user.repository.test.mts` → PASS.
```bash
git add apps/api/src/repositories/user.repository.mts apps/api/test/user.repository.test.mts
git commit -m "feat(api): user repository"
```

### Task 4.3: Gym repository (with geo)

**Files:**
- Create: `apps/api/src/repositories/gym.repository.mts`
- Test: `apps/api/test/gym.repository.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { GymRepository } from "../src/repositories/gym.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_gyms");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("GymRepository", () => {
  it("inserts and finds nearby with distanceKm", async () => {
    const repo = new GymRepository(db);
    await repo.ensureIndexes();
    await repo.insert({
      id: "g-1", name: "Atos", address: "9587 Distribution Ave",
      amenities: [], isVerified: true, location: { lat: 32.901, lng: -117.213 },
    });
    const near = await repo.findNearby(32.9, -117.21, 25);
    expect(near[0]?.id).toBe("g-1");
    expect(near[0]?.distanceKm).toBeGreaterThanOrEqual(0);
  });
});
```

- [ ] **Step 2: Run, verify fail** → `bun test test/gym.repository.test.mts` FAIL.

- [ ] **Step 3: Implement `gym.repository.mts`**

```typescript
import type { Db, Document } from "mongodb";
import type { Gym } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface GeoPoint {
  type: "Point";
  coordinates: [number, number];
}

interface GymDoc extends Omit<Gym, "location" | "distanceKm"> {
  _id: string;
  geo?: GeoPoint;
}

function toGeo(loc: Gym["location"]): GeoPoint | undefined {
  return loc ? { type: "Point", coordinates: [loc.lng, loc.lat] } : undefined;
}

function fromDoc(doc: (GymDoc & { distanceMeters?: number }) | null): Gym | null {
  if (!doc) return null;
  const { _id, geo, distanceMeters, ...rest } = doc;
  const gym: Gym = { ...(rest as unknown as Gym) };
  if (geo) gym.location = { lng: geo.coordinates[0], lat: geo.coordinates[1] };
  if (typeof distanceMeters === "number") gym.distanceKm = distanceMeters / 1000;
  return gym;
}

export class GymRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    await col.createIndex({ geo: "2dsphere" });
    await col.createIndex({ ownerId: 1 });
  }

  public async insert(gym: Gym): Promise<Gym> {
    const { location, distanceKm, ...rest } = gym;
    const doc: GymDoc = { ...(rest as unknown as GymDoc), _id: gym.id, geo: toGeo(location) };
    await this.collection<GymDoc>(COLLECTIONS.gyms).insertOne(doc);
    return gym;
  }

  public async findById(id: string): Promise<Gym | null> {
    return fromDoc(await this.collection<GymDoc>(COLLECTIONS.gyms).findOne({ _id: id }));
  }

  public async listByOwner(ownerId: string, skip: number, limit: number): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const total = await col.countDocuments({ ownerId });
    const docs = await col.find({ ownerId }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => fromDoc(d) as Gym), total };
  }

  public async list(skip: number, limit: number): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const total = await col.countDocuments({});
    const docs = await col.find({}).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => fromDoc(d) as Gym), total };
  }

  public async update(id: string, patch: Partial<Gym>): Promise<Gym | null> {
    const { location, distanceKm, ...rest } = patch;
    const set: Document = { ...rest };
    if (location !== undefined) set["geo"] = toGeo(location);
    await this.collection<GymDoc>(COLLECTIONS.gyms).updateOne({ _id: id }, { $set: set });
    return this.findById(id);
  }

  public async findNearby(lat: number, lng: number, radiusKm: number): Promise<Gym[]> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const docs = await col
      .aggregate<GymDoc & { distanceMeters: number }>([
        {
          $geoNear: {
            near: { type: "Point", coordinates: [lng, lat] },
            distanceField: "distanceMeters",
            maxDistance: radiusKm * 1000,
            spherical: true,
          },
        },
      ])
      .toArray();
    return docs.map((d) => fromDoc(d) as Gym);
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/gym.repository.test.mts` → PASS.
```bash
git add apps/api/src/repositories/gym.repository.mts apps/api/test/gym.repository.test.mts
git commit -m "feat(api): gym repository with 2dsphere geo search"
```

### Task 4.4: OpenMat repository

**Files:**
- Create: `apps/api/src/repositories/open-mat.repository.mts`
- Test: `apps/api/test/open-mat.repository.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_openmats");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("OpenMatRepository", () => {
  it("inserts a detail doc and filters by dayOfWeek", async () => {
    const repo = new OpenMatRepository(db);
    await repo.ensureIndexes();
    await repo.insert({
      id: "om-1", gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00",
      isRecurring: true, skillLevel: "all", giType: "gi", isCancelled: false, dayOfWeek: 5,
      latitude: 32.9, longitude: -117.2, address: "x", city: "SD", state: "CA",
    });
    const res = await repo.list({ dayOfWeek: 5 }, 0, 20);
    expect(res.total).toBe(1);
    expect(res.items[0]?.giType).toBe("gi");
    const detail = await repo.findById("om-1");
    expect(detail?.address).toBe("x");
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `open-mat.repository.mts`**

```typescript
import type { Db, Document, Filter } from "mongodb";
import type { GiType, OpenMat, OpenMatDetail, SkillLevel } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface OpenMatDoc extends OpenMatDetail {
  _id: string;
  geo?: { type: "Point"; coordinates: [number, number] };
}

export interface OpenMatFilter {
  dayOfWeek?: number;
  giType?: GiType;
  skillLevel?: SkillLevel;
  gymOwnerId?: string;
}

function toListItem(doc: OpenMatDoc): OpenMat {
  const { _id, geo, latitude, longitude, address, city, state, postalCode, gymRating, ...item } = doc;
  return item as unknown as OpenMat;
}

function toDetail(doc: OpenMatDoc | null): OpenMatDetail | null {
  if (!doc) return null;
  const { _id, geo, ...rest } = doc;
  return rest as unknown as OpenMatDetail;
}

export class OpenMatRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<OpenMatDoc>(COLLECTIONS.openMats);
    await col.createIndex({ gymId: 1, dayOfWeek: 1 });
    await col.createIndex({ geo: "2dsphere" });
  }

  public async insert(detail: OpenMatDetail): Promise<OpenMatDetail> {
    const doc: OpenMatDoc = {
      ...detail,
      _id: detail.id,
      geo: { type: "Point", coordinates: [detail.longitude, detail.latitude] },
    };
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).insertOne(doc);
    return detail;
  }

  public async findById(id: string): Promise<OpenMatDetail | null> {
    return toDetail(await this.collection<OpenMatDoc>(COLLECTIONS.openMats).findOne({ _id: id }));
  }

  public async list(filter: OpenMatFilter, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    const q: Filter<OpenMatDoc> = {};
    if (filter.dayOfWeek !== undefined) q.dayOfWeek = filter.dayOfWeek;
    if (filter.skillLevel) q.skillLevel = filter.skillLevel;
    if (filter.giType === "gi") q.giType = { $in: ["gi", "both"] };
    else if (filter.giType === "nogi") q.giType = { $in: ["nogi", "both"] };

    const col = this.collection<OpenMatDoc>(COLLECTIONS.openMats);
    const total = await col.countDocuments(q);
    const docs = await col.find(q).sort({ startTime: 1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map(toListItem), total };
  }

  public async findNearby(lat: number, lng: number, radiusKm: number): Promise<OpenMat[]> {
    const docs = await this.collection<OpenMatDoc>(COLLECTIONS.openMats)
      .aggregate<OpenMatDoc & { distanceMeters: number }>([
        {
          $geoNear: {
            near: { type: "Point", coordinates: [lng, lat] },
            distanceField: "distanceMeters",
            maxDistance: radiusKm * 1000,
            spherical: true,
          },
        },
      ])
      .toArray();
    return docs.map((d) => ({ ...toListItem(d), distanceKm: d.distanceMeters / 1000 }));
  }

  public async update(id: string, patch: Partial<OpenMatDetail>): Promise<OpenMatDetail | null> {
    const set: Document = { ...patch };
    if (patch.latitude !== undefined && patch.longitude !== undefined) {
      set["geo"] = { type: "Point", coordinates: [patch.longitude, patch.latitude] };
    }
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).updateOne({ _id: id }, { $set: set });
    return this.findById(id);
  }

  public async setAttendeeCount(id: string, count: number): Promise<void> {
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).updateOne({ _id: id }, { $set: { attendeeCount: count } });
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/open-mat.repository.test.mts` → PASS.
```bash
git add apps/api/src/repositories/open-mat.repository.mts apps/api/test/open-mat.repository.test.mts
git commit -m "feat(api): open-mat repository (filter + geo)"
```

### Task 4.5: RSVP, CheckIn, Favorite, Notification repositories

**Files:**
- Create: `apps/api/src/repositories/rsvp.repository.mts`, `check-in.repository.mts`, `favorite.repository.mts`, `notification.repository.mts`
- Test: `apps/api/test/secondary-repositories.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { RsvpRepository } from "../src/repositories/rsvp.repository.mts";
import { CheckInRepository } from "../src/repositories/check-in.repository.mts";
import { FavoriteRepository } from "../src/repositories/favorite.repository.mts";
import { NotificationRepository } from "../src/repositories/notification.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_secondary");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("secondary repositories", () => {
  it("rsvp is idempotent per (openMat, date, user)", async () => {
    const repo = new RsvpRepository(db);
    await repo.ensureIndexes();
    await repo.add("om-1", "2026-06-20", "u-1");
    await repo.add("om-1", "2026-06-20", "u-1");
    expect(await repo.count("om-1", "2026-06-20")).toBe(1);
    await repo.remove("om-1", "2026-06-20", "u-1");
    expect(await repo.count("om-1", "2026-06-20")).toBe(0);
  });

  it("favorites toggle and list", async () => {
    const repo = new FavoriteRepository(db);
    await repo.ensureIndexes();
    await repo.add("u-1", "g-1");
    expect((await repo.listGymIds("u-1"))).toContain("g-1");
    await repo.remove("u-1", "g-1");
    expect((await repo.listGymIds("u-1"))).toHaveLength(0);
  });

  it("checkins insert + review update", async () => {
    const repo = new CheckInRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: new Date().toISOString() });
    await repo.setReview("c-1", { rating: 5, categoryRatings: { instruction: 5, cleanliness: 5, variety: 5, worth_returning: 5, overall: 5 } });
    const mine = await repo.listByUser("u-1", 0, 20);
    expect(mine.items[0]?.rating).toBe(5);
  });

  it("notifications list + mark read", async () => {
    const repo = new NotificationRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "n-1", userId: "u-1", type: "system", title: "hi", body: "b", read: false, createdAt: new Date().toISOString() });
    await repo.markRead("n-1", "u-1");
    const res = await repo.listByUser("u-1", false, 0, 20);
    expect(res.items[0]?.read).toBe(true);
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3a: Implement `rsvp.repository.mts`**

```typescript
import type { Db } from "mongodb";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface RsvpDoc {
  openMatId: string;
  sessionDate: string;
  userId: string;
  rsvpAt: string;
}

export class RsvpRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).createIndex(
      { openMatId: 1, sessionDate: 1, userId: 1 },
      { unique: true },
    );
  }

  public async add(openMatId: string, sessionDate: string, userId: string): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).updateOne(
      { openMatId, sessionDate, userId },
      { $setOnInsert: { rsvpAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(openMatId: string, sessionDate: string, userId: string): Promise<void> {
    await this.collection<RsvpDoc>(COLLECTIONS.rsvps).deleteOne({ openMatId, sessionDate, userId });
  }

  public async count(openMatId: string, sessionDate: string): Promise<number> {
    return this.collection<RsvpDoc>(COLLECTIONS.rsvps).countDocuments({ openMatId, sessionDate });
  }

  public async userIds(openMatId: string, sessionDate: string): Promise<string[]> {
    const docs = await this.collection<RsvpDoc>(COLLECTIONS.rsvps).find({ openMatId, sessionDate }).toArray();
    return docs.map((d) => d.userId);
  }
}
```

- [ ] **Step 3b: Implement `check-in.repository.mts`**

```typescript
import type { Db } from "mongodb";
import type { CategoryRatings, CheckIn } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface CheckInDoc extends CheckIn {
  _id: string;
}

export class CheckInRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<CheckInDoc>(COLLECTIONS.checkins);
    await col.createIndex({ userId: 1 });
    await col.createIndex({ openMatId: 1, sessionDate: 1 });
  }

  public async insert(checkIn: CheckIn): Promise<CheckIn> {
    await this.collection<CheckInDoc>(COLLECTIONS.checkins).insertOne({ ...checkIn, _id: checkIn.id });
    return checkIn;
  }

  public async findById(id: string): Promise<CheckIn | null> {
    return stripId<CheckIn>(await this.collection<CheckInDoc>(COLLECTIONS.checkins).findOne({ _id: id }));
  }

  public async setReview(
    id: string,
    review: { rating: number; review?: string; categoryRatings: CategoryRatings },
  ): Promise<CheckIn | null> {
    await this.collection<CheckInDoc>(COLLECTIONS.checkins).updateOne({ _id: id }, { $set: review });
    return this.findById(id);
  }

  public async listByUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    const col = this.collection<CheckInDoc>(COLLECTIONS.checkins);
    const total = await col.countDocuments({ userId });
    const docs = await col.find({ userId }).sort({ checkedInAt: -1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => stripId<CheckIn>(d) as CheckIn), total };
  }

  public async listBySession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    const q = sessionDate ? { openMatId, sessionDate } : { openMatId };
    const docs = await this.collection<CheckInDoc>(COLLECTIONS.checkins).find(q).toArray();
    return docs.map((d) => stripId<CheckIn>(d) as CheckIn);
  }
}
```

- [ ] **Step 3c: Implement `favorite.repository.mts`**

```typescript
import type { Db } from "mongodb";
import type { Favorite } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class FavoriteRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).createIndex({ userId: 1, gymId: 1 }, { unique: true });
  }

  public async add(userId: string, gymId: string): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).updateOne(
      { userId, gymId },
      { $setOnInsert: { createdAt: new Date().toISOString() } },
      { upsert: true },
    );
  }

  public async remove(userId: string, gymId: string): Promise<void> {
    await this.collection<Favorite>(COLLECTIONS.favorites).deleteOne({ userId, gymId });
  }

  public async listGymIds(userId: string): Promise<string[]> {
    const docs = await this.collection<Favorite>(COLLECTIONS.favorites).find({ userId }).toArray();
    return docs.map((d) => d.gymId);
  }
}
```

- [ ] **Step 3d: Implement `notification.repository.mts`**

```typescript
import type { Db, Filter } from "mongodb";
import type { Notification } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface NotificationDoc extends Notification {
  _id: string;
}

export class NotificationRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).createIndex({ userId: 1, read: 1, createdAt: -1 });
  }

  public async insert(n: Notification): Promise<Notification> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).insertOne({ ...n, _id: n.id });
    return n;
  }

  public async listByUser(
    userId: string,
    unreadOnly: boolean,
    skip: number,
    limit: number,
  ): Promise<{ items: Notification[]; total: number }> {
    const q: Filter<NotificationDoc> = unreadOnly ? { userId, read: false } : { userId };
    const col = this.collection<NotificationDoc>(COLLECTIONS.notifications);
    const total = await col.countDocuments(q);
    const docs = await col.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map((d) => stripId<Notification>(d) as Notification), total };
  }

  public async markRead(id: string, userId: string): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).updateOne({ _id: id, userId }, { $set: { read: true } });
  }

  public async markAllRead(userId: string): Promise<void> {
    await this.collection<NotificationDoc>(COLLECTIONS.notifications).updateMany({ userId, read: false }, { $set: { read: true } });
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/secondary-repositories.test.mts` → PASS.
```bash
git add apps/api/src/repositories/rsvp.repository.mts apps/api/src/repositories/check-in.repository.mts apps/api/src/repositories/favorite.repository.mts apps/api/src/repositories/notification.repository.mts apps/api/test/secondary-repositories.test.mts
git commit -m "feat(api): rsvp, check-in, favorite, notification repositories"
```

---

## PHASE 5 — Facades (BAL)

> Facades hold business logic and consume repositories only. Each gets repositories via constructor injection.

### Task 5.1: User facade

**Files:**
- Create: `apps/api/src/facades/user.facade.mts`
- Test: `apps/api/test/user.facade.test.mts`

- [ ] **Step 1: Write failing test** (uses a fake repository — pure unit test, no Mongo)

```typescript
import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { User } from "@bjj/contract";

function fakeRepo(seed: User[]) {
  const users = new Map(seed.map((u) => [u.id, u]));
  return {
    findById: async (id: string) => users.get(id) ?? null,
    upsertByAuth0Id: async (_a: string, u: { id: string; email: string; displayName: string; role: User["role"] }) => {
      const created: User = { ...u };
      users.set(created.id, created);
      return created;
    },
    update: async (id: string, patch: Partial<User>) => {
      const cur = users.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      users.set(id, next);
      return next;
    },
    insert: async (u: User) => { users.set(u.id, u); return u; },
    ensureIndexes: async () => {},
  };
}

describe("UserFacade", () => {
  it("getOrCreate returns existing user", async () => {
    const repo = fakeRepo([{ id: "u-1", email: "a@b.dev", displayName: "A", role: "practitioner" }]);
    const facade = new UserFacade(repo);
    const u = await facade.getOrCreate({ userId: "u-1", role: "practitioner", email: "a@b.dev", viaBypass: true });
    expect(u.id).toBe("u-1");
  });

  it("updateProfile applies a patch", async () => {
    const repo = fakeRepo([{ id: "u-1", email: "a@b.dev", displayName: "A", role: "practitioner" }]);
    const facade = new UserFacade(repo);
    const u = await facade.updateProfile("u-1", { displayName: "B" });
    expect(u.displayName).toBe("B");
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `user.facade.mts`**

```typescript
import type { UpdateSettingsRequest, UpdateUserRequest, User, UserSettings } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { AppError } from "../http/errors.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

const DEFAULT_SETTINGS: UserSettings = { theme: "glass", notifyRsvp: true, notifySessionUpdates: true };

export class UserFacade {
  public constructor(private readonly users: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert">) {}

  public async getOrCreate(identity: AuthIdentity): Promise<User> {
    const existing = await this.users.findById(identity.userId);
    if (existing) return existing;
    return this.users.insert({
      id: identity.userId,
      email: identity.email,
      displayName: identity.email.split("@")[0] ?? identity.userId,
      role: identity.role,
      settings: DEFAULT_SETTINGS,
      createdAt: new Date().toISOString(),
    });
  }

  public async getById(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new AppError("not_found", `User ${id} not found`);
    return user;
  }

  public async updateProfile(id: string, patch: UpdateUserRequest): Promise<User> {
    const updated = await this.users.update(id, patch);
    if (!updated) throw new AppError("not_found", `User ${id} not found`);
    return updated;
  }

  public async getSettings(id: string): Promise<UserSettings> {
    const user = await this.getById(id);
    return user.settings ?? DEFAULT_SETTINGS;
  }

  public async updateSettings(id: string, patch: UpdateSettingsRequest): Promise<UserSettings> {
    const current = await this.getSettings(id);
    const next: UserSettings = { ...current, ...patch };
    await this.users.update(id, { settings: next });
    return next;
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/user.facade.test.mts` → PASS.
```bash
git add apps/api/src/facades/user.facade.mts apps/api/test/user.facade.test.mts
git commit -m "feat(api): user facade"
```

### Task 5.2: Gym facade

**Files:**
- Create: `apps/api/src/facades/gym.facade.mts`
- Test: `apps/api/test/gym.facade.test.mts`

- [ ] **Step 1: Write failing test** (fake repos; verifies ownership guard + id generation)

```typescript
import { describe, expect, it } from "bun:test";
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { Gym } from "@bjj/contract";

function repos() {
  const gyms = new Map<string, Gym>();
  const favs: Array<{ userId: string; gymId: string }> = [];
  const gymRepo = {
    insert: async (g: Gym) => { gyms.set(g.id, g); return g; },
    findById: async (id: string) => gyms.get(id) ?? null,
    update: async (id: string, patch: Partial<Gym>) => {
      const cur = gyms.get(id); if (!cur) return null;
      const next = { ...cur, ...patch }; gyms.set(id, next); return next;
    },
    list: async () => ({ items: [...gyms.values()], total: gyms.size }),
    listByOwner: async (ownerId: string) => {
      const items = [...gyms.values()].filter((g) => g.ownerId === ownerId);
      return { items, total: items.length };
    },
    findNearby: async () => [...gyms.values()],
    ensureIndexes: async () => {},
  };
  const favRepo = {
    add: async (userId: string, gymId: string) => { favs.push({ userId, gymId }); },
    remove: async (userId: string, gymId: string) => {
      const i = favs.findIndex((f) => f.userId === userId && f.gymId === gymId);
      if (i >= 0) favs.splice(i, 1);
    },
    listGymIds: async (userId: string) => favs.filter((f) => f.userId === userId).map((f) => f.gymId),
    ensureIndexes: async () => {},
  };
  return { gymRepo, favRepo };
}

describe("GymFacade", () => {
  it("create assigns ownerId and an id", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "gym-generated");
    const gym = await facade.create("owner-1", { name: "Atos", address: "x" });
    expect(gym.id).toBe("gym-generated");
    expect(gym.ownerId).toBe("owner-1");
  });

  it("update rejects a non-owner", async () => {
    const { gymRepo, favRepo } = repos();
    const facade = new GymFacade(gymRepo, favRepo, () => "g-1");
    await facade.create("owner-1", { name: "Atos", address: "x" });
    await expect(facade.update("someone-else", "g-1", { name: "New" })).rejects.toMatchObject({ code: "forbidden" });
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `gym.facade.mts`**

```typescript
import type { CreateGymRequest, Gym, UpdateGymRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { FavoriteRepository } from "../repositories/favorite.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";

type IdFactory = () => string;

export interface DirectionsPayload {
  latitude: number;
  longitude: number;
  address: string;
  mapsUrl: string;
}

export class GymFacade {
  public constructor(
    private readonly gyms: Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "findNearby">,
    private readonly favorites: Pick<FavoriteRepository, "add" | "remove" | "listGymIds">,
    private readonly newId: IdFactory,
  ) {}

  public async create(ownerId: string, req: CreateGymRequest): Promise<Gym> {
    const gym: Gym = {
      id: this.newId(),
      ownerId,
      name: req.name,
      description: req.description,
      address: req.address,
      city: req.city,
      state: req.state,
      country: req.country,
      postalCode: req.postalCode,
      location: req.location,
      googlePlaceId: req.googlePlaceId,
      phone: req.phone,
      website: req.website,
      amenities: req.amenities ?? [],
      isVerified: false,
      createdAt: new Date().toISOString(),
    };
    return this.gyms.insert(gym);
  }

  public async getById(id: string): Promise<Gym> {
    const gym = await this.gyms.findById(id);
    if (!gym) throw new AppError("not_found", `Gym ${id} not found`);
    return gym;
  }

  public async update(ownerId: string, id: string, patch: UpdateGymRequest): Promise<Gym> {
    const gym = await this.getById(id);
    if (gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
    const updated = await this.gyms.update(id, patch);
    return updated as Gym;
  }

  public async list(opts: { ownerId?: string; skip: number; limit: number }): Promise<{ items: Gym[]; total: number }> {
    return opts.ownerId
      ? this.gyms.listByOwner(opts.ownerId, opts.skip, opts.limit)
      : this.gyms.list(opts.skip, opts.limit);
  }

  public async nearby(lat: number, lng: number, radiusKm: number): Promise<Gym[]> {
    return this.gyms.findNearby(lat, lng, radiusKm);
  }

  public async directions(id: string): Promise<DirectionsPayload> {
    const gym = await this.getById(id);
    if (!gym.location) throw new AppError("not_found", "Gym has no location");
    const { lat, lng } = gym.location;
    return {
      latitude: lat,
      longitude: lng,
      address: gym.address,
      mapsUrl: `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`,
    };
  }

  public async favorite(userId: string, gymId: string): Promise<void> {
    await this.getById(gymId);
    await this.favorites.add(userId, gymId);
  }

  public async unfavorite(userId: string, gymId: string): Promise<void> {
    await this.favorites.remove(userId, gymId);
  }

  public async listFavorites(userId: string): Promise<Gym[]> {
    const ids = await this.favorites.listGymIds(userId);
    const gyms = await Promise.all(ids.map((id) => this.gyms.findById(id)));
    return gyms.filter((g): g is Gym => g !== null);
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/gym.facade.test.mts` → PASS.
```bash
git add apps/api/src/facades/gym.facade.mts apps/api/test/gym.facade.test.mts
git commit -m "feat(api): gym facade (ownership, directions, favorites)"
```

### Task 5.3: OpenMat facade

**Files:**
- Create: `apps/api/src/facades/open-mat.facade.mts`
- Test: `apps/api/test/open-mat.facade.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { OpenMatFacade } from "../src/facades/open-mat.facade.mts";
import type { Gym, OpenMatDetail } from "@bjj/contract";

function deps() {
  const mats = new Map<string, OpenMatDetail>();
  const counts = new Map<string, number>();
  const rsvps: Array<{ k: string; userId: string }> = [];
  const gym: Gym = { id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, location: { lat: 1, lng: 2 }, city: "SD", state: "CA" };
  return {
    matRepo: {
      insert: async (d: OpenMatDetail) => { mats.set(d.id, d); return d; },
      findById: async (id: string) => mats.get(id) ?? null,
      update: async (id: string, patch: Partial<OpenMatDetail>) => {
        const cur = mats.get(id); if (!cur) return null; const next = { ...cur, ...patch }; mats.set(id, next); return next;
      },
      list: async () => ({ items: [...mats.values()], total: mats.size }),
      findNearby: async () => [...mats.values()],
      setAttendeeCount: async (id: string, c: number) => { counts.set(id, c); },
      ensureIndexes: async () => {},
    },
    gymRepo: { findById: async (id: string) => (id === "g-1" ? gym : null) },
    rsvpRepo: {
      add: async (omId: string, date: string, userId: string) => { rsvps.push({ k: `${omId}:${date}`, userId }); },
      remove: async (omId: string, date: string, userId: string) => {
        const i = rsvps.findIndex((r) => r.k === `${omId}:${date}` && r.userId === userId); if (i >= 0) rsvps.splice(i, 1);
      },
      count: async (omId: string, date: string) => rsvps.filter((r) => r.k === `${omId}:${date}`).length,
      userIds: async (omId: string, date: string) => rsvps.filter((r) => r.k === `${omId}:${date}`).map((r) => r.userId),
    },
    counts,
  };
}

describe("OpenMatFacade", () => {
  it("create denormalizes gym name + location", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    const created = await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.gymName).toBe("Atos");
    expect(created.latitude).toBe(1);
    expect(created.giType).toBe("both");
  });

  it("rsvp is idempotent and updates attendeeCount", async () => {
    const d = deps();
    const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-1");
    await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    const r1 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    const r2 = await facade.rsvp("om-1", "2026-06-20", "u-1");
    expect(r1.attendeeCount).toBe(1);
    expect(r2.attendeeCount).toBe(1);
    expect(d.counts.get("om-1")).toBe(1);
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `open-mat.facade.mts`**

```typescript
import type {
  CreateOpenMatRequest,
  OpenMat,
  OpenMatDetail,
  RsvpResponse,
  UpdateOpenMatRequest,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { OpenMatFilter, OpenMatRepository } from "../repositories/open-mat.repository.mts";
import type { RsvpRepository } from "../repositories/rsvp.repository.mts";

type IdFactory = () => string;

export interface RsvpResult {
  ok: true;
  attendeeCount: number;
  attending: boolean;
}

export class OpenMatFacade {
  public constructor(
    private readonly mats: Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount">,
    private readonly gyms: Pick<GymRepository, "findById">,
    private readonly rsvps: Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">,
    private readonly newId: IdFactory,
  ) {}

  public async create(ownerId: string, req: CreateOpenMatRequest): Promise<OpenMatDetail> {
    const gym = await this.gyms.findById(req.gymId);
    if (!gym) throw new AppError("not_found", `Gym ${req.gymId} not found`);
    if (gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
    if (!gym.location) throw new AppError("bad_request", "Gym has no location set");

    const detail: OpenMatDetail = {
      id: this.newId(),
      gymId: req.gymId,
      hostId: req.hostId,
      title: req.title,
      description: req.description,
      dayOfWeek: req.dayOfWeek,
      startTime: req.startTime,
      endTime: req.endTime,
      isRecurring: req.isRecurring ?? true,
      specificDate: req.specificDate,
      maxParticipants: req.maxParticipants,
      skillLevel: req.skillLevel ?? "all",
      giType: req.giType ?? "both",
      isCancelled: false,
      feeCents: req.feeCents,
      attendeeCount: 0,
      gymName: gym.name,
      latitude: gym.location.lat,
      longitude: gym.location.lng,
      address: gym.address,
      city: gym.city ?? "",
      state: gym.state ?? "",
      postalCode: gym.postalCode,
      gymRating: gym.rating,
      createdAt: new Date().toISOString(),
    };
    return this.mats.insert(detail);
  }

  public async detail(id: string): Promise<OpenMatDetail> {
    const found = await this.mats.findById(id);
    if (!found) throw new AppError("not_found", `Open mat ${id} not found`);
    return found;
  }

  public async update(ownerId: string, id: string, patch: UpdateOpenMatRequest): Promise<OpenMatDetail> {
    const current = await this.detail(id);
    const gym = await this.gyms.findById(current.gymId);
    if (!gym || gym.ownerId !== ownerId) throw new AppError("forbidden", "Not the gym owner");
    return (await this.mats.update(id, patch)) as OpenMatDetail;
  }

  public async list(filter: OpenMatFilter, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    return this.mats.list(filter, skip, limit);
  }

  public async nearby(lat: number, lng: number, radiusKm: number): Promise<OpenMat[]> {
    return this.mats.findNearby(lat, lng, radiusKm);
  }

  public async rsvp(id: string, sessionDate: string, userId: string): Promise<RsvpResult> {
    await this.detail(id);
    await this.rsvps.add(id, sessionDate, userId);
    const count = await this.rsvps.count(id, sessionDate);
    await this.mats.setAttendeeCount(id, count);
    return { ok: true, attendeeCount: count, attending: true };
  }

  public async cancelRsvp(id: string, sessionDate: string, userId: string): Promise<RsvpResult> {
    await this.rsvps.remove(id, sessionDate, userId);
    const count = await this.rsvps.count(id, sessionDate);
    await this.mats.setAttendeeCount(id, count);
    return { ok: true, attendeeCount: count, attending: false };
  }

  public async attendeeUserIds(id: string, sessionDate: string): Promise<string[]> {
    return this.rsvps.userIds(id, sessionDate);
  }
}
```

> The `RsvpResponse` import from contract is retained for route typing; `RsvpResult` is the facade's return type (structurally identical). Routes return `data(result)`.

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/open-mat.facade.test.mts` → PASS.
```bash
git add apps/api/src/facades/open-mat.facade.mts apps/api/test/open-mat.facade.test.mts
git commit -m "feat(api): open-mat facade (create denormalization, rsvp counting)"
```

### Task 5.4: CheckIn facade (48h review window)

**Files:**
- Create: `apps/api/src/facades/check-in.facade.mts`
- Test: `apps/api/test/check-in.facade.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { CheckInFacade } from "../src/facades/check-in.facade.mts";
import type { CheckIn } from "@bjj/contract";

function repo(seed: CheckIn[]) {
  const map = new Map(seed.map((c) => [c.id, c]));
  return {
    insert: async (c: CheckIn) => { map.set(c.id, c); return c; },
    findById: async (id: string) => map.get(id) ?? null,
    setReview: async (id: string, r: { rating: number; review?: string; categoryRatings: CheckIn["categoryRatings"] }) => {
      const cur = map.get(id); if (!cur) return null; const next = { ...cur, ...r }; map.set(id, next); return next;
    },
    listByUser: async () => ({ items: [...map.values()], total: map.size }),
    listBySession: async () => [...map.values()],
    ensureIndexes: async () => {},
  };
}

const ratings = { instruction: 5, cleanliness: 5, variety: 5, worth_returning: 5, overall: 5 };

describe("CheckInFacade", () => {
  it("accepts a review within 48h", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    const updated = await facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings });
    expect(updated.rating).toBe(5);
  });

  it("rejects a review after 48h with conflict", async () => {
    const now = new Date("2026-06-25T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    await expect(facade.review("c-1", "u-1", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "conflict" });
  });

  it("rejects a review from a different user", async () => {
    const now = new Date("2026-06-20T12:00:00Z");
    const r = repo([{ id: "c-1", openMatId: "om-1", userId: "u-1", sessionDate: "2026-06-20", checkedInAt: "2026-06-20T00:00:00Z" }]);
    const facade = new CheckInFacade(r, () => "c-x", () => now);
    await expect(facade.review("c-1", "other", { rating: 5, categoryRatings: ratings })).rejects.toMatchObject({ code: "forbidden" });
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `check-in.facade.mts`**

```typescript
import type { CheckIn, ReviewRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { CheckInRepository } from "../repositories/check-in.repository.mts";

type IdFactory = () => string;
type Clock = () => Date;

const REVIEW_WINDOW_MS = 48 * 60 * 60 * 1000;

export class CheckInFacade {
  public constructor(
    private readonly checkins: Pick<CheckInRepository, "insert" | "findById" | "setReview" | "listByUser" | "listBySession">,
    private readonly newId: IdFactory,
    private readonly now: Clock = () => new Date(),
  ) {}

  public async checkIn(openMatId: string, userId: string, sessionDate: string): Promise<CheckIn> {
    return this.checkins.insert({
      id: this.newId(),
      openMatId,
      userId,
      sessionDate,
      checkedInAt: this.now().toISOString(),
      createdAt: this.now().toISOString(),
    });
  }

  public async review(checkInId: string, userId: string, req: ReviewRequest): Promise<CheckIn> {
    const checkIn = await this.checkins.findById(checkInId);
    if (!checkIn) throw new AppError("not_found", `Check-in ${checkInId} not found`);
    if (checkIn.userId !== userId) throw new AppError("forbidden", "Cannot review another user's check-in");

    const elapsed = this.now().getTime() - new Date(checkIn.checkedInAt).getTime();
    if (elapsed > REVIEW_WINDOW_MS) throw new AppError("conflict", "Review window (48h) has expired");

    const updated = await this.checkins.setReview(checkInId, {
      rating: req.rating,
      review: req.review,
      categoryRatings: req.categoryRatings,
    });
    return updated as CheckIn;
  }

  public async listForUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    return this.checkins.listByUser(userId, skip, limit);
  }

  public async listForSession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    return this.checkins.listBySession(openMatId, sessionDate);
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/check-in.facade.test.mts` → PASS.
```bash
git add apps/api/src/facades/check-in.facade.mts apps/api/test/check-in.facade.test.mts
git commit -m "feat(api): check-in facade with 48h review window"
```

### Task 5.5: Notification facade

**Files:**
- Create: `apps/api/src/facades/notification.facade.mts`
- Test: `apps/api/test/notification.facade.test.mts`

- [ ] **Step 1: Write failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { NotificationFacade } from "../src/facades/notification.facade.mts";
import type { Notification } from "@bjj/contract";

function repo() {
  const map = new Map<string, Notification>();
  return {
    insert: async (n: Notification) => { map.set(n.id, n); return n; },
    listByUser: async (userId: string, unread: boolean) => {
      const items = [...map.values()].filter((n) => n.userId === userId && (!unread || !n.read));
      return { items, total: items.length };
    },
    markRead: async (id: string) => { const n = map.get(id); if (n) map.set(id, { ...n, read: true }); },
    markAllRead: async (userId: string) => { for (const [k, n] of map) if (n.userId === userId) map.set(k, { ...n, read: true }); },
    ensureIndexes: async () => {},
  };
}

describe("NotificationFacade", () => {
  it("lists then marks all read", async () => {
    const r = repo();
    const facade = new NotificationFacade(r, () => "n-1");
    await facade.create("u-1", "system", "Hi", "Body");
    const before = await facade.list("u-1", true, 0, 20);
    expect(before.total).toBe(1);
    await facade.markAllRead("u-1");
    const after = await facade.list("u-1", true, 0, 20);
    expect(after.total).toBe(0);
  });
});
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement `notification.facade.mts`**

```typescript
import type { Notification, NotificationType } from "@bjj/contract";
import type { NotificationRepository } from "../repositories/notification.repository.mts";

type IdFactory = () => string;

export class NotificationFacade {
  public constructor(
    private readonly notifications: Pick<NotificationRepository, "insert" | "listByUser" | "markRead" | "markAllRead">,
    private readonly newId: IdFactory,
  ) {}

  public async create(userId: string, type: NotificationType, title: string, body: string): Promise<Notification> {
    return this.notifications.insert({
      id: this.newId(),
      userId,
      type,
      title,
      body,
      read: false,
      createdAt: new Date().toISOString(),
    });
  }

  public async list(userId: string, unread: boolean, skip: number, limit: number): Promise<{ items: Notification[]; total: number }> {
    return this.notifications.listByUser(userId, unread, skip, limit);
  }

  public async markRead(id: string, userId: string): Promise<void> {
    await this.notifications.markRead(id, userId);
  }

  public async markAllRead(userId: string): Promise<void> {
    await this.notifications.markAllRead(userId);
  }
}
```

- [ ] **Step 4: Run, verify pass & commit**

Run (from `apps/api`): `bun test test/notification.facade.test.mts` → PASS.
```bash
git add apps/api/src/facades/notification.facade.mts apps/api/test/notification.facade.test.mts
git commit -m "feat(api): notification facade"
```

---

## PHASE 6 — DI container, routes, app wiring

### Task 6.1: Rewrite the DI container

**Files:**
- Rewrite: `apps/api/src/container.mts`
- **Delete: `apps/api/src/services/open-mat.service.mts`** (orphaned — the facade layer replaces the old service layer; the new container no longer imports it)

- [ ] **Step 1: Implement**

```typescript
import { randomUUID } from "node:crypto";
import type { Db } from "mongodb";
import type { AppEnv } from "./config/env.mts";
import { JwtVerifier } from "./auth/jwt-verifier.mts";
import { CheckInFacade } from "./facades/check-in.facade.mts";
import { GymFacade } from "./facades/gym.facade.mts";
import { NotificationFacade } from "./facades/notification.facade.mts";
import { OpenMatFacade } from "./facades/open-mat.facade.mts";
import { UserFacade } from "./facades/user.facade.mts";
import { CheckInRepository } from "./repositories/check-in.repository.mts";
import { FavoriteRepository } from "./repositories/favorite.repository.mts";
import { GymRepository } from "./repositories/gym.repository.mts";
import { NotificationRepository } from "./repositories/notification.repository.mts";
import { OpenMatRepository } from "./repositories/open-mat.repository.mts";
import { RsvpRepository } from "./repositories/rsvp.repository.mts";
import { UserRepository } from "./repositories/user.repository.mts";

export interface Container {
  readonly db: Db;
  readonly verifier: JwtVerifier;
  readonly userFacade: UserFacade;
  readonly gymFacade: GymFacade;
  readonly openMatFacade: OpenMatFacade;
  readonly checkInFacade: CheckInFacade;
  readonly notificationFacade: NotificationFacade;
  ensureIndexes(): Promise<void>;
}

export function createContainer(db: Db, env: AppEnv): Container {
  const userRepo = new UserRepository(db);
  const gymRepo = new GymRepository(db);
  const openMatRepo = new OpenMatRepository(db);
  const rsvpRepo = new RsvpRepository(db);
  const checkInRepo = new CheckInRepository(db);
  const favoriteRepo = new FavoriteRepository(db);
  const notificationRepo = new NotificationRepository(db);
  const id = (): string => randomUUID();

  return {
    db,
    verifier: new JwtVerifier({
      bypassSecret: env.bypassSecret,
      demoUser: env.demoUser,
      auth0Domain: env.auth0Domain,
      auth0Audience: env.auth0Audience,
    }),
    userFacade: new UserFacade(userRepo),
    gymFacade: new GymFacade(gymRepo, favoriteRepo, id),
    openMatFacade: new OpenMatFacade(openMatRepo, gymRepo, rsvpRepo, id),
    checkInFacade: new CheckInFacade(checkInRepo, id),
    notificationFacade: new NotificationFacade(notificationRepo, id),
    async ensureIndexes(): Promise<void> {
      await Promise.all([
        userRepo.ensureIndexes(),
        gymRepo.ensureIndexes(),
        openMatRepo.ensureIndexes(),
        rsvpRepo.ensureIndexes(),
        checkInRepo.ensureIndexes(),
        favoriteRepo.ensureIndexes(),
        notificationRepo.ensureIndexes(),
      ]);
    },
  };
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/container.mts
git commit -m "feat(api): DI container wiring repositories + facades + verifier"
```

### Task 6.2: User + settings routes

**Files:**
- Create: `apps/api/src/routes/user.routes.mts`

- [ ] **Step 1: Implement**

```typescript
import { Elysia } from "elysia";
import { UpdateSettingsRequest, UpdateUserRequest } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function userRoutes(container: Container) {
  const { userFacade } = container;

  return new Elysia()
    .get("/api/v1/auth/me", async ({ identity }) => data(await userFacade.getOrCreate(requireId(identity))), {
      requireAuth: true,
    })
    .get("/api/v1/users/me", async ({ identity }) => data(await userFacade.getById(requireId(identity).userId)), {
      requireAuth: true,
    })
    .put(
      "/api/v1/users/me",
      async ({ identity, body }) => data(await userFacade.updateProfile(requireId(identity).userId, body)),
      { requireAuth: true, body: UpdateUserRequest },
    )
    .get("/api/v1/users/me/settings", async ({ identity }) => data(await userFacade.getSettings(requireId(identity).userId)), {
      requireAuth: true,
    })
    .put(
      "/api/v1/users/me/settings",
      async ({ identity, body }) => data(await userFacade.updateSettings(requireId(identity).userId, body)),
      { requireAuth: true, body: UpdateSettingsRequest },
    )
    .get("/api/v1/users/:id", async ({ params }) => data(await userFacade.getById(params.id)));
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/routes/user.routes.mts
git commit -m "feat(api): user + settings routes"
```

### Task 6.3: Gym routes

**Files:**
- Create: `apps/api/src/routes/gym.routes.mts`

- [ ] **Step 1: Implement**

```typescript
import { Elysia } from "elysia";
import { CreateGymRequest, GymListQuery, NearbyQuery, UpdateGymRequest } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function gymRoutes(container: Container) {
  const { gymFacade } = container;

  return new Elysia({ prefix: "/api/v1/gyms" })
    .get(
      "/",
      async ({ query, identity }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const ownerId = query.mine ? requireId(identity).userId : undefined;
        const { items, total } = await gymFacade.list({ ownerId, skip: (page - 1) * limit, limit });
        return list(items, { page, limit, total });
      },
      { query: GymListQuery },
    )
    .post("/", async ({ identity, body }) => data(await gymFacade.create(requireId(identity).userId, body)), {
      requireOwner: true,
      body: CreateGymRequest,
    })
    .get("/nearby", async ({ query }) => {
      const gyms = await gymFacade.nearby(query.lat, query.lng, query.radiusKm ?? 25);
      return list(gyms, { page: 1, limit: gyms.length, total: gyms.length });
    }, { query: NearbyQuery })
    .get("/:id", async ({ params }) => data(await gymFacade.getById(params.id)))
    .put("/:id", async ({ identity, params, body }) => data(await gymFacade.update(requireId(identity).userId, params.id, body)), {
      requireOwner: true,
      body: UpdateGymRequest,
    })
    .get("/:id/directions", async ({ params }) => data(await gymFacade.directions(params.id)))
    .post("/:id/favorite", async ({ identity, params }) => {
      await gymFacade.favorite(requireId(identity).userId, params.id);
      return data({ favorited: true });
    }, { requireAuth: true })
    .delete("/:id/favorite", async ({ identity, params }) => {
      await gymFacade.unfavorite(requireId(identity).userId, params.id);
      return data({ favorited: false });
    }, { requireAuth: true });
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/routes/gym.routes.mts
git commit -m "feat(api): gym routes (CRUD, nearby, directions, favorites)"
```

### Task 6.4: OpenMat routes

**Files:**
- Rewrite: `apps/api/src/routes/open-mat.routes.mts`

- [ ] **Step 1: Implement** (replaces the existing seed-era file)

```typescript
import { Elysia } from "elysia";
import {
  CheckinRequest,
  CreateOpenMatRequest,
  OpenMatListQuery,
  RsvpRequest,
  SessionDateQuery,
  UpdateOpenMatRequest,
} from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function openMatRoutes(container: Container) {
  const { openMatFacade, userFacade, checkInFacade } = container;

  return new Elysia({ prefix: "/api/v1/open-mats" })
    .get(
      "/",
      async ({ query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await openMatFacade.list(
          { dayOfWeek: query.dayOfWeek, giType: query.giType, skillLevel: query.skillLevel },
          (page - 1) * limit,
          limit,
        );
        return list(items, { page, limit, total });
      },
      { query: OpenMatListQuery },
    )
    .post("/", async ({ identity, body }) => data(await openMatFacade.create(requireId(identity).userId, body)), {
      requireOwner: true,
      body: CreateOpenMatRequest,
    })
    .get("/nearby", async ({ query }) => {
      const lat = Number(query["lat"]);
      const lng = Number(query["lng"]);
      const radiusKm = query["radiusKm"] ? Number(query["radiusKm"]) : 25;
      const mats = await openMatFacade.nearby(lat, lng, radiusKm);
      return list(mats, { page: 1, limit: mats.length, total: mats.length });
    })
    .get("/:id", async ({ params }) => data(await openMatFacade.detail(params.id)))
    .put("/:id", async ({ identity, params, body }) => data(await openMatFacade.update(requireId(identity).userId, params.id, body)), {
      requireOwner: true,
      body: UpdateOpenMatRequest,
    })
    .post("/:id/rsvp", async ({ identity, params, body }) =>
      data(await openMatFacade.rsvp(params.id, body.sessionDate, requireId(identity).userId)),
      { requireAuth: true, body: RsvpRequest },
    )
    .delete("/:id/rsvp", async ({ identity, params, query }) => {
      const sessionDate = query.sessionDate ?? query.date;
      if (!sessionDate) throw new AppError("bad_request", "sessionDate query param required");
      return data(await openMatFacade.cancelRsvp(params.id, sessionDate, requireId(identity).userId));
    }, { requireAuth: true, query: SessionDateQuery })
    .get("/:id/attendees", async ({ params, query }) => {
      const sessionDate = query.sessionDate ?? query.date;
      if (!sessionDate) throw new AppError("bad_request", "sessionDate query param required");
      const userIds = await openMatFacade.attendeeUserIds(params.id, sessionDate);
      const users = await Promise.all(userIds.map((uid) => userFacade.getById(uid).catch(() => null)));
      const attendees = users
        .filter((u): u is NonNullable<typeof u> => u !== null)
        .map((u) => ({
          userId: u.id,
          name: u.displayName,
          beltRank: u.beltRank ?? "white",
          beltStripes: u.beltStripes,
          skillLevel: "all" as const,
          avatarUrl: u.avatarUrl,
          rsvpAt: "",
        }));
      return list(attendees, { page: 1, limit: attendees.length, total: attendees.length });
    }, { query: SessionDateQuery })
    .post("/:id/checkin", async ({ identity, params, body }) =>
      data(await checkInFacade.checkIn(params.id, requireId(identity).userId, body.sessionDate)),
      { requireAuth: true, body: CheckinRequest },
    )
    .get("/:id/checkins", async ({ params, query }) => {
      const sessionDate = query.sessionDate ?? query.date;
      const checkins = await checkInFacade.listForSession(params.id, sessionDate);
      return list(checkins, { page: 1, limit: checkins.length, total: checkins.length });
    }, { requireOwner: true, query: SessionDateQuery });
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/routes/open-mat.routes.mts
git commit -m "feat(api): open-mat routes (CRUD, rsvp, attendees, checkin, attendance)"
```

### Task 6.5: Check-in + favorite + notification routes

**Files:**
- Create: `apps/api/src/routes/check-in.routes.mts`, `apps/api/src/routes/favorite.routes.mts`, `apps/api/src/routes/notification.routes.mts`

- [ ] **Step 1: `check-in.routes.mts`**

```typescript
import { Elysia } from "elysia";
import { PageQuery, ReviewRequest } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function checkInRoutes(container: Container) {
  const { checkInFacade } = container;

  return new Elysia()
    .post(
      "/api/v1/checkins/:id/review",
      async ({ identity, params, body }) => data(await checkInFacade.review(params.id, requireId(identity).userId, body)),
      { requireAuth: true, body: ReviewRequest },
    )
    .get(
      "/api/v1/users/me/checkins",
      async ({ identity, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await checkInFacade.listForUser(requireId(identity).userId, (page - 1) * limit, limit);
        return list(items, { page, limit, total });
      },
      { requireAuth: true, query: PageQuery },
    );
}
```

- [ ] **Step 2: `favorite.routes.mts`**

```typescript
import { Elysia } from "elysia";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function favoriteRoutes(container: Container) {
  const { gymFacade } = container;

  return new Elysia().get(
    "/api/v1/users/me/favorites",
    async ({ identity }) => {
      const gyms = await gymFacade.listFavorites(requireId(identity).userId);
      return list(gyms, { page: 1, limit: gyms.length, total: gyms.length });
    },
    { requireAuth: true },
  );
}
```

- [ ] **Step 3: `notification.routes.mts`**

```typescript
import { Elysia } from "elysia";
import { NotificationListQuery } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function notificationRoutes(container: Container) {
  const { notificationFacade } = container;

  return new Elysia({ prefix: "/api/v1/notifications" })
    .get(
      "/",
      async ({ identity, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await notificationFacade.list(
          requireId(identity).userId,
          query.unread ?? false,
          (page - 1) * limit,
          limit,
        );
        return list(items, { page, limit, total });
      },
      { requireAuth: true, query: NotificationListQuery },
    )
    .post("/:id/read", async ({ identity, params }) => {
      await notificationFacade.markRead(params.id, requireId(identity).userId);
      return data({ read: true });
    }, { requireAuth: true })
    .post("/read-all", async ({ identity }) => {
      await notificationFacade.markAllRead(requireId(identity).userId);
      return data({ read: true });
    }, { requireAuth: true });
}
```

- [ ] **Step 4: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/routes/check-in.routes.mts apps/api/src/routes/favorite.routes.mts apps/api/src/routes/notification.routes.mts
git commit -m "feat(api): check-in, favorite, notification routes"
```

### Task 6.6: Extend health routes to ping Mongo

**Files:**
- Rewrite: `apps/api/src/routes/health.routes.mts`

- [ ] **Step 1: Implement**

```typescript
import type { HealthResponse, ReadyResponse } from "@bjj/contract";
import { Elysia } from "elysia";
import type { Db } from "mongodb";

const startedAt = Date.now();

// Liveness at /health, readiness at /ready (per project convention — never /healthz).
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function healthRoutes(db: Db) {
  return new Elysia()
    .get("/health", (): HealthResponse => ({ status: "ok", uptimeSeconds: (Date.now() - startedAt) / 1000 }))
    .get("/ready", async (): Promise<ReadyResponse> => {
      let mongoOk = false;
      try {
        await db.command({ ping: 1 });
        mongoOk = true;
      } catch {
        mongoOk = false;
      }
      return { status: mongoOk ? "ready" : "degraded", checks: { mongo: mongoOk } };
    });
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/routes/health.routes.mts
git commit -m "feat(api): /ready pings MongoDB"
```

### Task 6.7: Rewrite app.mts + index.mts

**Files:**
- Rewrite: `apps/api/src/app.mts`, `apps/api/src/index.mts`

- [ ] **Step 1: Rewrite `app.mts`**

```typescript
import { Elysia } from "elysia";
import { authPlugin } from "./auth/auth.middleware.mts";
import type { Container } from "./container.mts";
import { logger } from "./config/logger.mts";
import { registerErrorHandler } from "./http/error-handler.mts";
import { buildOpenApiDocument } from "./openapi.mts";
import { checkInRoutes } from "./routes/check-in.routes.mts";
import { favoriteRoutes } from "./routes/favorite.routes.mts";
import { gymRoutes } from "./routes/gym.routes.mts";
import { healthRoutes } from "./routes/health.routes.mts";
import { notificationRoutes } from "./routes/notification.routes.mts";
import { openMatRoutes } from "./routes/open-mat.routes.mts";
import { userRoutes } from "./routes/user.routes.mts";

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function buildApp(container: Container) {
  const base = registerErrorHandler(new Elysia(), logger);

  return base
    .get("/openapi.json", () => buildOpenApiDocument())
    .use(healthRoutes(container.db))
    .use(authPlugin(container.verifier))
    .use(userRoutes(container))
    .use(gymRoutes(container))
    .use(openMatRoutes(container))
    .use(checkInRoutes(container))
    .use(favoriteRoutes(container))
    .use(notificationRoutes(container));
}
```

> The `authPlugin` runs before the domain route groups so `identity` and the `requireAuth`/`requireOwner` macros are available to them. Health + OpenAPI are mounted before auth (public).

- [ ] **Step 2: Rewrite `index.mts`**

```typescript
import { loadEnv } from "./config/env.mts";
import { logger } from "./config/logger.mts";
import { createMongoContext } from "./db/mongo.mts";
import { createContainer } from "./container.mts";
import { buildApp } from "./app.mts";

const env = loadEnv();
const { client, db } = createMongoContext(env);
await client.connect();

const container = createContainer(db, env);
await container.ensureIndexes();

buildApp(container).listen(env.port, (server) => {
  logger.info(`BJJ Open Mat API listening on http://localhost:${server.port}`);
});
```

- [ ] **Step 3: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/app.mts apps/api/src/index.mts
git commit -m "feat(api): wire app graph with auth, error handler, all routes"
```

---

## PHASE 7 — OpenAPI document + Postman collection

### Task 7.1: Rewrite the OpenAPI document

**Files:**
- Rewrite: `apps/api/src/openapi.mts`

- [ ] **Step 1: Implement** (registers all component schemas + the full path set)

```typescript
import {
  Attendee,
  BeltRank,
  CategoryRatings,
  CheckIn,
  CreateGymRequest,
  CreateOpenMatRequest,
  ErrorResponse,
  Favorite,
  Gym,
  GiType,
  HealthResponse,
  ListMeta,
  Notification,
  NotificationType,
  OpenMat,
  OpenMatDetail,
  ReadyResponse,
  ReviewRequest,
  RsvpRequest,
  SkillLevel,
  UpdateGymRequest,
  UpdateOpenMatRequest,
  UpdateUserRequest,
  User,
  UserRole,
  UserSettings,
} from "@bjj/contract";

export function buildOpenApiDocument(): Record<string, unknown> {
  const ref = (name: string): Record<string, unknown> => ({ $ref: `#/components/schemas/${name}` });
  const dataOf = (name: string): Record<string, unknown> => ({
    type: "object",
    properties: { data: ref(name) },
  });
  const listOf = (name: string): Record<string, unknown> => ({
    type: "object",
    properties: { data: { type: "array", items: ref(name) }, meta: ref("ListMeta") },
  });
  const ok = (schema: Record<string, unknown>): Record<string, unknown> => ({
    "200": { description: "OK", content: { "application/json": { schema } } },
  });
  const idParam = [{ name: "id", in: "path", required: true, schema: { type: "string" } }];

  return {
    openapi: "3.1.0",
    info: { title: "BJJ Open Mat API", version: "0.2.0" },
    servers: [{ url: "/" }],
    paths: {
      "/health": { get: { summary: "Liveness", responses: ok(ref("HealthResponse")) } },
      "/ready": { get: { summary: "Readiness", responses: ok(ref("ReadyResponse")) } },
      "/api/v1/auth/me": { get: { summary: "Get-or-create current user", responses: ok(dataOf("User")) } },
      "/api/v1/users/me": {
        get: { summary: "Current user", responses: ok(dataOf("User")) },
        put: {
          summary: "Update current user",
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateUserRequest") } } },
          responses: ok(dataOf("User")),
        },
      },
      "/api/v1/users/me/settings": {
        get: { summary: "Get settings", responses: ok(dataOf("UserSettings")) },
        put: { summary: "Update settings", responses: ok(dataOf("UserSettings")) },
      },
      "/api/v1/users/{id}": { get: { summary: "Public profile", parameters: idParam, responses: ok(dataOf("User")) } },
      "/api/v1/gyms": {
        get: { summary: "List gyms", responses: ok(listOf("Gym")) },
        post: {
          summary: "Create gym",
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateGymRequest") } } },
          responses: ok(dataOf("Gym")),
        },
      },
      "/api/v1/gyms/nearby": { get: { summary: "Nearby gyms", responses: ok(listOf("Gym")) } },
      "/api/v1/gyms/{id}": {
        get: { summary: "Gym detail", parameters: idParam, responses: ok(dataOf("Gym")) },
        put: {
          summary: "Update gym",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateGymRequest") } } },
          responses: ok(dataOf("Gym")),
        },
      },
      "/api/v1/gyms/{id}/directions": { get: { summary: "Directions", parameters: idParam, responses: ok(dataOf("Gym")) } },
      "/api/v1/gyms/{id}/favorite": {
        post: { summary: "Add favorite", parameters: idParam, responses: ok(dataOf("Gym")) },
        delete: { summary: "Remove favorite", parameters: idParam, responses: ok(dataOf("Gym")) },
      },
      "/api/v1/open-mats": {
        get: { summary: "List/finder open mats", responses: ok(listOf("OpenMat")) },
        post: {
          summary: "Create open mat",
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateOpenMatRequest") } } },
          responses: ok(dataOf("OpenMatDetail")),
        },
      },
      "/api/v1/open-mats/nearby": { get: { summary: "Nearby open mats", responses: ok(listOf("OpenMat")) } },
      "/api/v1/open-mats/{id}": {
        get: { summary: "Open mat detail", parameters: idParam, responses: { ...ok(dataOf("OpenMatDetail")), "404": { description: "Not found" } } },
        put: {
          summary: "Update open mat",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateOpenMatRequest") } } },
          responses: ok(dataOf("OpenMatDetail")),
        },
      },
      "/api/v1/open-mats/{id}/rsvp": {
        post: {
          summary: "RSVP",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("RsvpRequest") } } },
          responses: ok(dataOf("OpenMat")),
        },
        delete: { summary: "Cancel RSVP", parameters: idParam, responses: ok(dataOf("OpenMat")) },
      },
      "/api/v1/open-mats/{id}/attendees": { get: { summary: "Attendees", parameters: idParam, responses: ok(listOf("Attendee")) } },
      "/api/v1/open-mats/{id}/checkin": {
        post: {
          summary: "Check in",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("RsvpRequest") } } },
          responses: ok(dataOf("CheckIn")),
        },
      },
      "/api/v1/open-mats/{id}/checkins": { get: { summary: "Attendance", parameters: idParam, responses: ok(listOf("CheckIn")) } },
      "/api/v1/checkins/{id}/review": {
        post: {
          summary: "Submit review",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ReviewRequest") } } },
          responses: ok(dataOf("CheckIn")),
        },
      },
      "/api/v1/users/me/checkins": { get: { summary: "My check-ins", responses: ok(listOf("CheckIn")) } },
      "/api/v1/users/me/favorites": { get: { summary: "My favorite gyms", responses: ok(listOf("Gym")) } },
      "/api/v1/notifications": { get: { summary: "My notifications", responses: ok(listOf("Notification")) } },
      "/api/v1/notifications/{id}/read": { post: { summary: "Mark read", parameters: idParam, responses: ok(dataOf("Notification")) } },
      "/api/v1/notifications/read-all": { post: { summary: "Mark all read", responses: ok(dataOf("Notification")) } },
    },
    components: {
      schemas: {
        BeltRank,
        SkillLevel,
        GiType,
        UserRole,
        NotificationType,
        User,
        UserSettings,
        Gym,
        OpenMat,
        OpenMatDetail,
        Attendee,
        CheckIn,
        CategoryRatings,
        Favorite,
        Notification,
        ListMeta,
        ErrorResponse,
        CreateGymRequest,
        UpdateGymRequest,
        CreateOpenMatRequest,
        UpdateOpenMatRequest,
        UpdateUserRequest,
        RsvpRequest,
        ReviewRequest,
      },
    },
  };
}
```

- [ ] **Step 2: type-check & commit**

Run (from `apps/api`): `bun run type-check` → clean.
```bash
git add apps/api/src/openapi.mts
git commit -m "feat(api): full OpenAPI 3.1 document"
```

### Task 7.2: Postman collection + environment

**Files:**
- Create: `docs/postman/bjj-open-mat.postman_collection.json`, `docs/postman/bjj-open-mat.postman_environment.json`

- [ ] **Step 1: Write the environment file**

```json
{
  "id": "bjj-open-mat-env",
  "name": "BJJ Open Mat (Local)",
  "values": [
    { "key": "baseUrl", "value": "http://localhost:3100", "enabled": true },
    { "key": "bearerToken", "value": "TopFlightApiSecurity2026+", "enabled": true }
  ],
  "_postman_variable_scope": "environment"
}
```

- [ ] **Step 2: Write the collection file** (collection-level bearer auth + one request per endpoint; folders per domain)

```json
{
  "info": {
    "name": "BJJ Open Mat API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "auth": { "type": "bearer", "bearer": [{ "key": "token", "value": "{{bearerToken}}", "type": "string" }] },
  "variable": [{ "key": "baseUrl", "value": "http://localhost:3100" }],
  "item": [
    {
      "name": "Health",
      "item": [
        { "name": "Liveness", "request": { "method": "GET", "url": "{{baseUrl}}/health" } },
        { "name": "Readiness", "request": { "method": "GET", "url": "{{baseUrl}}/ready" } },
        { "name": "OpenAPI", "request": { "method": "GET", "url": "{{baseUrl}}/openapi.json" } }
      ]
    },
    {
      "name": "Users",
      "item": [
        { "name": "Get-or-create me", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/auth/me" } },
        { "name": "Get me", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/users/me" } },
        { "name": "Update me", "request": { "method": "PUT", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"displayName\": \"New Name\",\n  \"beltRank\": \"purple\"\n}" }, "url": "{{baseUrl}}/api/v1/users/me" } },
        { "name": "Get settings", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/users/me/settings" } },
        { "name": "Update settings", "request": { "method": "PUT", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"theme\": \"glass\"\n}" }, "url": "{{baseUrl}}/api/v1/users/me/settings" } },
        { "name": "Public profile", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/users/u-me" } }
      ]
    },
    {
      "name": "Gyms",
      "item": [
        { "name": "List gyms", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/gyms?page=1&limit=20" } },
        { "name": "Create gym", "request": { "method": "POST", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"name\": \"Atos HQ\",\n  \"address\": \"9587 Distribution Ave\",\n  \"city\": \"San Diego\",\n  \"state\": \"CA\",\n  \"location\": { \"lat\": 32.901, \"lng\": -117.213 }\n}" }, "url": "{{baseUrl}}/api/v1/gyms" } },
        { "name": "Nearby gyms", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/gyms/nearby?lat=32.9&lng=-117.21&radiusKm=25" } },
        { "name": "Gym detail", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/gyms/gym-atos" } },
        { "name": "Update gym", "request": { "method": "PUT", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"phone\": \"555-0100\"\n}" }, "url": "{{baseUrl}}/api/v1/gyms/gym-atos" } },
        { "name": "Directions", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/gyms/gym-atos/directions" } },
        { "name": "Add favorite", "request": { "method": "POST", "url": "{{baseUrl}}/api/v1/gyms/gym-atos/favorite" } },
        { "name": "Remove favorite", "request": { "method": "DELETE", "url": "{{baseUrl}}/api/v1/gyms/gym-atos/favorite" } }
      ]
    },
    {
      "name": "Open Mats",
      "item": [
        { "name": "List/finder", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/open-mats?dayOfWeek=5&giType=gi" } },
        { "name": "Create", "request": { "method": "POST", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"gymId\": \"gym-atos\",\n  \"title\": \"Friday Night Open Mat\",\n  \"startTime\": \"19:00\",\n  \"endTime\": \"21:00\",\n  \"dayOfWeek\": 5,\n  \"giType\": \"gi\",\n  \"skillLevel\": \"all\"\n}" }, "url": "{{baseUrl}}/api/v1/open-mats" } },
        { "name": "Nearby", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/open-mats/nearby?lat=32.9&lng=-117.21&radiusKm=25" } },
        { "name": "Detail", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri" } },
        { "name": "Update", "request": { "method": "PUT", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"isCancelled\": true\n}" }, "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri" } },
        { "name": "RSVP", "request": { "method": "POST", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"sessionDate\": \"2026-06-20\"\n}" }, "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri/rsvp" } },
        { "name": "Cancel RSVP", "request": { "method": "DELETE", "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri/rsvp?sessionDate=2026-06-20" } },
        { "name": "Attendees", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri/attendees?sessionDate=2026-06-20" } },
        { "name": "Check in", "request": { "method": "POST", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"sessionDate\": \"2026-06-20\"\n}" }, "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri/checkin" } },
        { "name": "Attendance (checkins)", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/open-mats/om-atos-fri/checkins?date=2026-06-20" } }
      ]
    },
    {
      "name": "Check-ins & Training",
      "item": [
        { "name": "Submit review", "request": { "method": "POST", "header": [{ "key": "Content-Type", "value": "application/json" }], "body": { "mode": "raw", "raw": "{\n  \"rating\": 5,\n  \"review\": \"Great rolls\",\n  \"categoryRatings\": { \"instruction\": 5, \"cleanliness\": 4, \"variety\": 5, \"worth_returning\": 5, \"overall\": 5 }\n}" }, "url": "{{baseUrl}}/api/v1/checkins/CHECKIN_ID/review" } },
        { "name": "My check-ins", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/users/me/checkins" } }
      ]
    },
    {
      "name": "Favorites",
      "item": [
        { "name": "My favorites", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/users/me/favorites" } }
      ]
    },
    {
      "name": "Notifications",
      "item": [
        { "name": "List", "request": { "method": "GET", "url": "{{baseUrl}}/api/v1/notifications?unread=true" } },
        { "name": "Mark read", "request": { "method": "POST", "url": "{{baseUrl}}/api/v1/notifications/NOTIFICATION_ID/read" } },
        { "name": "Mark all read", "request": { "method": "POST", "url": "{{baseUrl}}/api/v1/notifications/read-all" } }
      ]
    }
  ]
}
```

- [ ] **Step 3: Validate JSON parses**

Run: `bun -e "JSON.parse(await Bun.file('docs/postman/bjj-open-mat.postman_collection.json').text()); JSON.parse(await Bun.file('docs/postman/bjj-open-mat.postman_environment.json').text()); console.log('ok')"`
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add docs/postman
git commit -m "docs: Postman collection + environment for all endpoints"
```

---

## PHASE 8 — Seed, integration boot test, final verify

### Task 8.1: Seed runner

**Files:**
- Create: `apps/api/src/data/seed-runner.mts`
- Modify: `apps/api/src/data/seed.mts` (add `giType` to fixtures; remove `isGiSession`)

- [ ] **Step 1: Update `seed.mts` fixtures**

In each `seedOpenMats` entry, replace `isGiSession: true` → `giType: "gi"` and `isGiSession: false` → `giType: "nogi"`. The three entries become: `om-atos-fri` → `giType: "gi"`, `om-renzo-fri` → `giType: "nogi"`, `om-10p-sat` → `giType: "nogi"`. Update the import type if needed (already `OpenMatDetail`).

- [ ] **Step 2: Implement `seed-runner.mts`**

```typescript
import { loadEnv } from "../config/env.mts";
import { logger } from "../config/logger.mts";
import { createMongoContext } from "../db/mongo.mts";
import { GymRepository } from "../repositories/gym.repository.mts";
import { OpenMatRepository } from "../repositories/open-mat.repository.mts";
import { RsvpRepository } from "../repositories/rsvp.repository.mts";
import { UserRepository } from "../repositories/user.repository.mts";
import { seedAttendees, seedOpenMats } from "./seed.mts";

const env = loadEnv();
const { client, db } = createMongoContext(env);
await client.connect();

const gymRepo = new GymRepository(db);
const matRepo = new OpenMatRepository(db);
const rsvpRepo = new RsvpRepository(db);
const userRepo = new UserRepository(db);

await Promise.all([gymRepo.ensureIndexes(), matRepo.ensureIndexes(), rsvpRepo.ensureIndexes(), userRepo.ensureIndexes()]);

for (const mat of seedOpenMats) {
  await gymRepo.insert({
    id: mat.gymId,
    ownerId: env.demoUser.id,
    name: mat.gymName ?? mat.gymId,
    address: mat.address,
    city: mat.city,
    state: mat.state,
    postalCode: mat.postalCode,
    location: { lat: mat.latitude, lng: mat.longitude },
    amenities: [],
    isVerified: true,
    rating: mat.gymRating,
  }).catch(() => undefined);
  await matRepo.insert(mat).catch(() => undefined);
}

for (const [openMatId, attendees] of Object.entries(seedAttendees)) {
  for (const a of attendees) {
    await userRepo
      .insert({ id: a.userId, email: `${a.userId}@seed.dev`, displayName: a.name, role: "practitioner", beltRank: a.beltRank, beltStripes: a.beltStripes })
      .catch(() => undefined);
    await rsvpRepo.add(openMatId, "2026-06-20", a.userId).catch(() => undefined);
  }
}

logger.info(`Seeded ${seedOpenMats.length} gyms + open mats`);
await client.close();
```

- [ ] **Step 3: Run the seed against local Mongo**

Run (from `apps/api`, with Mongo up and a `.env` present): `bun run seed`
Expected: log `Seeded 3 gyms + open mats`, process exits 0.

- [ ] **Step 4: Commit**

```bash
git add apps/api/src/data/seed-runner.mts apps/api/src/data/seed.mts
git commit -m "feat(api): MongoDB seed runner; migrate fixtures to giType"
```

### Task 8.2: Integration boot test

**Files:**
- Rewrite: `apps/api/test/boot.test.mts`

- [ ] **Step 1: Write the test** (socket-bound, real Mongo, auth bypass, validation 400, ownership happy path)

```typescript
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_boot";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });

const env = {
  ...loadEnv({
    MONGODB_URI: uri,
    MONGODB_DB: TEST_DB,
    AUTH_BYPASS_SECRET: "TopFlightApiSecurity2026+",
    DEMO_USER_ID: "u-me",
    DEMO_USER_ROLE: "gym_owner",
    DEMO_USER_EMAIL: "demo@test.dev",
  }),
};

let app: ReturnType<typeof buildApp>;
let base: string;
const auth = { Authorization: "Bearer TopFlightApiSecurity2026+" };

beforeAll(async () => {
  await client.connect();
  const container = createContainer(client.db(TEST_DB), env);
  await container.ensureIndexes();
  app = buildApp(container).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("API boot (MongoDB-backed)", () => {
  it("serves health, ready, openapi", async () => {
    expect((await fetch(`${base}/health`)).status).toBe(200);
    const ready = await fetch(`${base}/ready`);
    expect(ready.status).toBe(200);
    expect((await ready.json()).status).toBe("ready");
    const openapi = await fetch(`${base}/openapi.json`);
    expect((await openapi.json()).openapi).toBe("3.1.0");
  });

  it("requires auth on protected routes", async () => {
    expect((await fetch(`${base}/api/v1/users/me`)).status).toBe(401);
  });

  it("runs a full owner flow with the bypass token", async () => {
    // get-or-create the demo user
    const me = await fetch(`${base}/api/v1/auth/me`, { headers: auth });
    expect(me.status).toBe(200);

    // create gym
    const gymRes = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Atos", address: "9587 Distribution Ave", location: { lat: 32.901, lng: -117.213 } }),
    });
    expect(gymRes.status).toBe(200);
    const gymId = (await gymRes.json()).data.id;

    // create open mat
    const omRes = await fetch(`${base}/api/v1/open-mats`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ gymId, title: "Fri", startTime: "19:00", endTime: "21:00", dayOfWeek: 5, giType: "gi" }),
    });
    expect(omRes.status).toBe(200);
    const omId = (await omRes.json()).data.id;

    // list finds it
    const listRes = await fetch(`${base}/api/v1/open-mats?dayOfWeek=5`);
    expect((await listRes.json()).meta.total).toBeGreaterThan(0);

    // rsvp
    const rsvp = await fetch(`${base}/api/v1/open-mats/${omId}/rsvp`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ sessionDate: "2026-06-20" }),
    });
    expect((await rsvp.json()).data.attending).toBe(true);

    // nearby gyms
    const near = await fetch(`${base}/api/v1/gyms/nearby?lat=32.9&lng=-117.21&radiusKm=25`);
    expect((await near.json()).data.length).toBeGreaterThan(0);
  });

  it("returns 404 for a missing open mat", async () => {
    expect((await fetch(`${base}/api/v1/open-mats/does-not-exist`)).status).toBe(404);
  });

  it("returns 400 with error envelope on bad body", async () => {
    const res = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "" }),
    });
    expect(res.status).toBe(400);
    expect((await res.json()).error.code).toBe("bad_request");
  });
});
```

- [ ] **Step 2: Run, verify pass**

Run (from `apps/api`, Mongo up): `bun test test/boot.test.mts`
Expected: all assertions PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/api/test/boot.test.mts
git commit -m "test(api): MongoDB-backed socket boot test (auth, CRUD, geo, validation)"
```

### Task 8.3: Full verify gate

**Files:** none (verification only)

- [ ] **Step 1: Run the whole suite**

Run (from `apps/api`): `bun test`
Expected: every test file passes.

- [ ] **Step 2: type-check + lint**

Run (from repo root): `bun run type-check && bun run lint`
Expected: both clean across `@bjj/contract` and `@bjj/api`.

- [ ] **Step 3: Boot the real entrypoint**

Run (from `apps/api`, `.env` present, Mongo up): `bun run start`
Expected: logs `BJJ Open Mat API listening on http://localhost:3100`. Then in another shell: `curl localhost:3100/health` → `{"status":"ok",...}`, `curl localhost:3100/ready` → `{"status":"ready",...}`. Stop the server.

- [ ] **Step 4: Update README + decision doc references**

Add to `README.md` under common commands: `bun run --filter @bjj/api seed` and `docker compose up -d`. Note the bypass token usage for Postman. Keep it brief.

- [ ] **Step 5: Final commit**

```bash
git add README.md
git commit -m "docs: document seed + docker-compose + Postman bypass token"
```

---

## Self-Review (completed during authoring)

- **Spec coverage:** Layering (Phases 4–6), contract split + enums incl. `giType` (Phase 1), `VALIDATION:` logging (Task 3.2), auth + bypass (Tasks 3.3–3.4), Mongo env/connection + docker-compose + seed (Phases 0, 2, 8.1), all endpoints incl. notifications/settings (Phase 6), envelope (Tasks 3.1, 6.x), Postman (Task 7.2), `/ready` Mongo ping (Task 6.6), 48h review window (Task 5.4), `attendeeCount` computed (Task 5.3), geo 2dsphere (Tasks 4.3–4.4). All spec sections map to tasks.
- **Placeholder scan:** No placeholders, TODOs, or "similar to" references — every code step shows complete code.
- **Type consistency:** Facade method names referenced by routes match their definitions (`getOrCreate`, `getById`, `updateProfile`, `getSettings`, `updateSettings`, `create`, `update`, `list`, `nearby`, `directions`, `favorite`, `unfavorite`, `listFavorites`, `detail`, `rsvp`, `cancelRsvp`, `attendeeUserIds`, `checkIn`, `review`, `listForUser`, `listForSession`, `markRead`, `markAllRead`). Repository method names match facade calls. Envelope `{ data }` / `{ data, meta }` consistent across routes and OpenAPI.

## Notes for implementers

- Mongo must be running for repository/boot tests (`docker compose up -d`). A connection failure is a blocker to report, not a skip.
- The facade unit tests (Phase 5) use in-memory fakes and need no Mongo.
- The `requireAuth` / `requireOwner` Elysia macros must be registered (Task 3.4) before route groups consume them (Task 6.7 mounts `authPlugin` before domain routes).
- Frontend follow-ups (separate effort): update Flutter `OpenMat` model `isGiSession` → `giType`; wire screens to the now-real endpoints.
