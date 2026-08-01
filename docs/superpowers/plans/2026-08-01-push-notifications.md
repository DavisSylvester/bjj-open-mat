# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver push notifications to iOS + Android devices for new messages and all existing in-app notification events, via Firebase Cloud Messaging.

**Architecture:** A `deviceTokens` collection + register/unregister routes capture each device's FCM token. A `PushService` fans a payload out to a user's tokens through a `PushSender` port (real adapter = `FcmPushSender` calling FCM HTTP v1, credentials from AWS Secrets Manager). `NotificationFacade.create` and `MessagingFacade.sendMessage` call `PushService` after their existing work; message pushes are transient (no persisted notification row). The Flutter client registers its token on login, handles foreground/background/tap, and deep-links via `go_router`.

**Tech Stack:** Bun + Elysia + MongoDB (driver v7) + TypeBox on the API; Flutter/Riverpod + go_router on mobile; `firebase_core`, `firebase_messaging`, `flutter_local_notifications`; FCM HTTP v1 + `google-auth-library`.

**Spec:** `docs/superpowers/specs/2026-08-01-push-notifications-design.md`

## Global Constraints

- TypeScript strict; no `any`; explicit return types + access modifiers; `.mjs` import specifiers; TypeBox (not Zod). `console.*` only in `apps/api/scripts/`.
- One TypeBox schema per file in `packages/contract/src/schemas/`, barrelled via `packages/contract/src/index.mts`.
- Mongo: latest driver (`mongodb@^7`); string-`_id` collections typed `Collection<{ _id: string; … }>`; repositories extend `BaseRepository`; register collection name in `apps/api/src/db/collections.mts`.
- API tests: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`. In facade/db tests assert with direct `await`, never `expect(promise).resolves` (Bun CSOT hang).
- Push failures must NEVER fail the originating request — `PushService` swallows all errors.
- Correctness rules for who receives a push: never the message's own sender; skip blocked (either direction); skip a muted conversation/channel; skip users with no tokens.
- Mobile: Flutter/Riverpod; standalone patterns; `flutter analyze` clean on changed files; `flutter test` on host. `.env`/secrets never committed.
- Auth0: public clients use Authorization Code + PKCE, no secret.
- No `Co-Authored-By` lines. Gitflow + Conventional Commits. Never merge to `main` without explicit user go-ahead.
- Bundle id `com.davissylvester.bjjopenmat`. CI marketing version from `build_name`, build number = `run_number + 100`.

---

## Prerequisites (user-provisioned — see spec §5)

These are **inputs** the implementation consumes; they are not tasks. Tasks that need them note it.

- `GoogleService-Info.plist` (iOS) and `google-services.json` (Android) from the Firebase project.
- APNs Auth Key uploaded to Firebase (enables iOS delivery).
- Firebase **service-account JSON** stored in AWS Secrets Manager; the secret ARN + **Firebase project id** available to the Lambda as env (`FCM_SECRET_ARN`, `FCM_PROJECT_ID`).

---

## File structure

**Contract (`packages/contract/src`)**
- Create `schemas/device-token.mts` — `DeviceToken` schema + type.
- Create `schemas/requests/register-device-request.mts` — `RegisterDeviceRequest`.
- Modify `index.mts` — barrel exports.

**API (`apps/api/src`)**
- Modify `db/collections.mts` — add `deviceTokens`.
- Create `repositories/device-token.repository.mts` — `DeviceTokenRepository`.
- Create `push/push.types.mts` — `PushPayload`, `PushSendResult`, `PushSender`, `PushService` port.
- Create `push/push.service.mts` — `PushService` (fan-out + prune).
- Create `push/fcm-push-sender.mts` — `FcmPushSender` adapter.
- Create `routes/device.routes.mts` — register/unregister.
- Modify `facades/notification.facade.mts` — emit push after `create`.
- Modify `facades/messaging.facade.mts` — emit push after `sendMessage`.
- Modify `container.mts`, `app.mts`, `env` — wiring.

**Mobile (`apps/mobile/lib`)**
- Create `features/push/data/device_repository.dart` — register/unregister API client.
- Create `features/push/data/push_messaging.dart` — thin wrapper over `FirebaseMessaging` (an interface + real impl) for testability.
- Create `features/push/push_routing.dart` — pure `routeForPushData(Map)` deep-link resolver.
- Create `features/push/push_controller.dart` — Riverpod controller: permission, token lifecycle, handlers.
- Modify `main.dart` / app bootstrap — Firebase init + background handler + controller start.
- Modify `core/api/endpoints.dart` — device endpoints.

**Platform/CI**
- Modify `apps/mobile/ios/*` — entitlements, capabilities, `AppDelegate`, `GoogleService-Info.plist`.
- Modify `apps/mobile/android/*` — `google-services.json`, gradle plugin.
- Modify `.github/workflows/mobile-release.yml` — inject Firebase config files from secrets.

---

## Task 1: `DeviceToken` + `RegisterDeviceRequest` contract schemas

**Files:**
- Create: `packages/contract/src/schemas/device-token.mts`
- Create: `packages/contract/src/schemas/requests/register-device-request.mts`
- Modify: `packages/contract/src/index.mts`
- Test: `packages/contract/test/device-token-schema.test.mts`

**Interfaces:**
- Produces: `DeviceToken = { id: string; userId: string; token: string; platform: 'ios'|'android'; createdAt: string; lastSeenAt?: string }`; `RegisterDeviceRequest = { token: string; platform: 'ios'|'android' }`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/device-token-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { DeviceToken, RegisterDeviceRequest } from "../src/index.mts";

describe("device token schemas", () => {
  it("DeviceToken parses a valid ios token", () => {
    const d = Value.Parse(DeviceToken, {
      id: "d1", userId: "u1", token: "abc", platform: "ios", createdAt: "t",
    });
    expect(d.platform).toBe("ios");
  });

  it("RegisterDeviceRequest rejects an unknown platform", () => {
    expect(Value.Check(RegisterDeviceRequest, { token: "abc", platform: "web" })).toBe(false);
    expect(Value.Check(RegisterDeviceRequest, { token: "abc", platform: "android" })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/device-token-schema.test.mts`
Expected: FAIL — `DeviceToken`/`RegisterDeviceRequest` not exported.

- [ ] **Step 3: Write the schemas**

```ts
// packages/contract/src/schemas/device-token.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const DevicePlatform = t.Union([t.Literal("ios"), t.Literal("android")], { $id: "DevicePlatform" });
export type DevicePlatform = Static<typeof DevicePlatform>;

export const DeviceToken = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    token: t.String(),
    platform: DevicePlatform,
    createdAt: t.String(),
    lastSeenAt: t.Optional(t.String()),
  },
  { $id: "DeviceToken" },
);
export type DeviceToken = Static<typeof DeviceToken>;
```

```ts
// packages/contract/src/schemas/requests/register-device-request.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { DevicePlatform } from "../device-token.mjs";

export const RegisterDeviceRequest = t.Object(
  { token: t.String({ minLength: 1 }), platform: DevicePlatform },
  { $id: "RegisterDeviceRequest" },
);
export type RegisterDeviceRequest = Static<typeof RegisterDeviceRequest>;
```

- [ ] **Step 4: Add barrel exports**

In `packages/contract/src/index.mts`, add (matching the file's existing export style):
```ts
export * from "./schemas/device-token.mjs";
export * from "./schemas/requests/register-device-request.mjs";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/contract && bun test test/device-token-schema.test.mts`
Expected: PASS. Also run `bun test` (whole contract package) — all green.

- [ ] **Step 6: Commit**

```bash
git add packages/contract/src/schemas/device-token.mts packages/contract/src/schemas/requests/register-device-request.mts packages/contract/src/index.mts packages/contract/test/device-token-schema.test.mts
git commit -m "feat(contract): DeviceToken + RegisterDeviceRequest schemas"
```

---

## Task 2: `DeviceTokenRepository`

**Files:**
- Modify: `apps/api/src/db/collections.mts` (add `deviceTokens: "deviceTokens"`)
- Create: `apps/api/src/repositories/device-token.repository.mts`
- Test: `apps/api/test/device-token.repository.test.mts`

**Interfaces:**
- Consumes: `DeviceToken` (Task 1), `BaseRepository`, `COLLECTIONS`.
- Produces: `DeviceTokenRepository` with:
  - `ensureIndexes(): Promise<void>` — unique index on `token`, index on `userId`.
  - `upsertByToken(d: DeviceToken): Promise<DeviceToken>` — upsert keyed by `token`; re-points `userId`/`platform`, sets `lastSeenAt`.
  - `listByUser(userId: string): Promise<DeviceToken[]>`
  - `deleteByToken(token: string): Promise<void>`
  - `pruneTokens(tokens: string[]): Promise<void>` — delete all rows whose `token` is in the list.
  - `deleteByUserId(userId: string): Promise<void>` — for account-deletion parity.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/device-token.repository.test.mts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoMemoryServer } from "mongodb-memory-server";
import { MongoClient, type Db } from "mongodb";
import { DeviceTokenRepository } from "../src/repositories/device-token.repository.mts";
import type { DeviceToken } from "@bjj/contract";

let mongod: MongoMemoryServer;
let client: MongoClient;
let db: Db;
let repo: DeviceTokenRepository;

const tok = (id: string, userId: string, token: string): DeviceToken => ({
  id, userId, token, platform: "ios", createdAt: "t",
});

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  client = new MongoClient(mongod.getUri());
  await client.connect();
  db = client.db("test");
  repo = new DeviceTokenRepository(db);
  await repo.ensureIndexes();
});

afterAll(async () => { await client.close(); await mongod.stop(); });

describe("DeviceTokenRepository", () => {
  it("upsertByToken re-points an existing token to a new user", async () => {
    await repo.upsertByToken(tok("d1", "u1", "same-token"));
    await repo.upsertByToken(tok("d2", "u2", "same-token"));
    const forU1 = await repo.listByUser("u1");
    const forU2 = await repo.listByUser("u2");
    expect(forU1).toHaveLength(0);
    expect(forU2).toHaveLength(1);
    expect(forU2[0].token).toBe("same-token");
  });

  it("pruneTokens removes only listed tokens", async () => {
    await repo.upsertByToken(tok("d3", "u3", "keep"));
    await repo.upsertByToken(tok("d4", "u3", "drop"));
    await repo.pruneTokens(["drop"]);
    const rows = await repo.listByUser("u3");
    expect(rows.map((r) => r.token)).toEqual(["keep"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/device-token.repository.test.mts`
Expected: FAIL — `DeviceTokenRepository` not found.

- [ ] **Step 3: Add the collection name**

In `apps/api/src/db/collections.mts`, add inside `COLLECTIONS`: `deviceTokens: "deviceTokens",`.

- [ ] **Step 4: Write the repository (follow `notification.repository.mts`)**

```ts
// apps/api/src/repositories/device-token.repository.mts
import type { Db } from "mongodb";
import type { DeviceToken } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface DeviceTokenDoc extends DeviceToken {
  _id: string;
}

export class DeviceTokenRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens);
    await col.createIndex({ token: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
  }

  public async upsertByToken(d: DeviceToken): Promise<DeviceToken> {
    const col = this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens);
    await col.updateOne(
      { token: d.token },
      { $set: { userId: d.userId, platform: d.platform, lastSeenAt: d.createdAt }, $setOnInsert: { _id: d.id, token: d.token, createdAt: d.createdAt } },
      { upsert: true },
    );
    return d;
  }

  public async listByUser(userId: string): Promise<DeviceToken[]> {
    const docs = await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).find({ userId }).toArray();
    return docs.map((d) => stripId<DeviceToken>(d) as DeviceToken);
  }

  public async deleteByToken(token: string): Promise<void> {
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteOne({ token });
  }

  public async pruneTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteMany({ token: { $in: tokens } });
  }

  public async deleteByUserId(userId: string): Promise<void> {
    await this.collection<DeviceTokenDoc>(COLLECTIONS.deviceTokens).deleteMany({ userId });
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/device-token.repository.test.mts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/db/collections.mts apps/api/src/repositories/device-token.repository.mts apps/api/test/device-token.repository.test.mts
git commit -m "feat(api): DeviceTokenRepository with upsert-by-token + prune"
```

---

## Task 3: `PushService` + `PushSender` port (fan-out + prune)

**Files:**
- Create: `apps/api/src/push/push.types.mts`
- Create: `apps/api/src/push/push.service.mts`
- Test: `apps/api/test/push.service.test.mts`

**Interfaces:**
- Consumes: `DeviceTokenRepository.listByUser`, `.pruneTokens` (Task 2).
- Produces:
  ```ts
  interface PushPayload { title: string; body: string; data: Record<string, string>; }
  interface PushSendResult { unregistered: string[]; }
  interface PushSender { send(tokens: string[], payload: PushPayload): Promise<PushSendResult>; }
  interface PushNotifier { pushToUsers(userIds: string[], payload: PushPayload): Promise<void>; }
  class PushService implements PushNotifier { constructor(tokens, sender: PushSender) }
  ```
  `pushToUsers` loads each user's tokens (deduped), sends once, prunes returned unregistered tokens, and **never throws**.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/push.service.test.mts
import { describe, expect, it } from "bun:test";
import { PushService } from "../src/push/push.service.mts";
import type { PushPayload, PushSender, PushSendResult } from "../src/push/push.types.mts";
import type { DeviceToken } from "@bjj/contract";

function fakeTokens(rows: DeviceToken[]) {
  const pruned: string[][] = [];
  return {
    repo: {
      listByUser: async (userId: string) => rows.filter((r) => r.userId === userId),
      pruneTokens: async (tokens: string[]) => { pruned.push(tokens); },
    },
    pruned,
  };
}

const payload: PushPayload = { title: "T", body: "B", data: { type: "message" } };
const tok = (userId: string, token: string): DeviceToken => ({ id: token, userId, token, platform: "ios", createdAt: "t" });

describe("PushService", () => {
  it("sends to all of the users' tokens", async () => {
    const { repo } = fakeTokens([tok("u1", "a"), tok("u1", "b"), tok("u2", "c")]);
    const sent: string[][] = [];
    const sender: PushSender = { send: async (tokens) => { sent.push(tokens); return { unregistered: [] }; } };
    await new PushService(repo, sender).pushToUsers(["u1", "u2"], payload);
    expect(sent[0].sort()).toEqual(["a", "b", "c"]);
  });

  it("prunes tokens the sender reports unregistered", async () => {
    const { repo, pruned } = fakeTokens([tok("u1", "a"), tok("u1", "dead")]);
    const sender: PushSender = { send: async (): Promise<PushSendResult> => ({ unregistered: ["dead"] }) };
    await new PushService(repo, sender).pushToUsers(["u1"], payload);
    expect(pruned).toEqual([["dead"]]);
  });

  it("no tokens -> does not call the sender", async () => {
    const { repo } = fakeTokens([]);
    let called = false;
    const sender: PushSender = { send: async () => { called = true; return { unregistered: [] }; } };
    await new PushService(repo, sender).pushToUsers(["nobody"], payload);
    expect(called).toBe(false);
  });

  it("swallows sender errors (never throws)", async () => {
    const { repo } = fakeTokens([tok("u1", "a")]);
    const sender: PushSender = { send: async () => { throw new Error("fcm down"); } };
    // Direct await — must resolve, not reject.
    await new PushService(repo, sender).pushToUsers(["u1"], payload);
    expect(true).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/push.service.test.mts`
Expected: FAIL — `PushService`/types not found.

- [ ] **Step 3: Write the types**

```ts
// apps/api/src/push/push.types.mts
export interface PushPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface PushSendResult {
  unregistered: string[];
}

export interface PushSender {
  send(tokens: string[], payload: PushPayload): Promise<PushSendResult>;
}

export interface PushNotifier {
  pushToUsers(userIds: string[], payload: PushPayload): Promise<void>;
}
```

- [ ] **Step 4: Write the service**

```ts
// apps/api/src/push/push.service.mts
import type { DeviceToken } from "@bjj/contract";
import { logger } from "../logging/logger.mts";
import type { PushNotifier, PushPayload, PushSender } from "./push.types.mts";

interface TokenReader {
  listByUser(userId: string): Promise<DeviceToken[]>;
  pruneTokens(tokens: string[]): Promise<void>;
}

export class PushService implements PushNotifier {

  public constructor(
    private readonly tokens: TokenReader,
    private readonly sender: PushSender,
  ) {}

  public async pushToUsers(userIds: string[], payload: PushPayload): Promise<void> {
    try {
      const rows = await Promise.all([...new Set(userIds)].map((u) => this.tokens.listByUser(u)));
      const tokens = [...new Set(rows.flat().map((r) => r.token))];
      if (tokens.length === 0) return;
      const { unregistered } = await this.sender.send(tokens, payload);
      if (unregistered.length > 0) await this.tokens.pruneTokens(unregistered);
    } catch (err) {
      logger.warn({ err }, "push send failed (swallowed)");
    }
  }
}
```

> Note: use the project's existing Winston `logger` import path — check `apps/api/src/**` for the logger module and match it. If the exact path differs, adjust the import; do not add `console.*`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/push.service.test.mts`
Expected: PASS (all 4).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/push/push.types.mts apps/api/src/push/push.service.mts apps/api/test/push.service.test.mts
git commit -m "feat(api): PushService fan-out with token pruning + error swallowing"
```

---

## Task 4: Device register/unregister routes

**Files:**
- Create: `apps/api/src/routes/device.routes.mts`
- Modify: `apps/api/src/container.mts` (construct `deviceTokenRepo`, expose on container; call `ensureIndexes`)
- Modify: `apps/api/src/app.mts` (mount `deviceRoutes`)
- Test: `apps/api/test/device.routes.test.mts`

**Interfaces:**
- Consumes: `DeviceTokenRepository` (Task 2), `RegisterDeviceRequest` (Task 1), `authPlugin`, `data` envelope, `requireId` pattern (copy from `notification.routes.mts`).
- Produces: `POST /api/v1/devices` (body `RegisterDeviceRequest` → upsert token for `identity.userId`, returns `data({ registered: true })`); `DELETE /api/v1/devices/:token` → `deleteByToken`, returns `data({ registered: false })`.

- [ ] **Step 1: Write the failing test** (mount the real route on Elysia; follow the existing route-test harness in `apps/api/test/*.routes.test.mts` for auth stubbing)

```ts
// apps/api/test/device.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { deviceRoutes } from "../src/routes/device.routes.mts";
// Reuse the shared route-test container/auth stub used by other *.routes.test.mts files.
import { testContainer, authHeader } from "./helpers/route-test-harness.mts";

describe("device routes", () => {
  it("POST /api/v1/devices upserts a token for the caller", async () => {
    const container = testContainer();
    const app = new Elysia().use(deviceRoutes(container));
    const res = await app.handle(new Request("http://x/api/v1/devices", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeader("u1") },
      body: JSON.stringify({ token: "abc", platform: "ios" }),
    }));
    expect(res.status).toBe(200);
    const rows = await container.deviceTokenRepo.listByUser("u1");
    expect(rows.map((r) => r.token)).toContain("abc");
  });

  it("POST rejects an invalid platform with 422", async () => {
    const container = testContainer();
    const app = new Elysia().use(deviceRoutes(container));
    const res = await app.handle(new Request("http://x/api/v1/devices", {
      method: "POST",
      headers: { "content-type": "application/json", ...authHeader("u1") },
      body: JSON.stringify({ token: "abc", platform: "web" }),
    }));
    expect(res.status).toBe(422);
  });
});
```

> If no shared `route-test-harness.mts` exists, inspect an existing `*.routes.test.mts` (e.g. `notification.routes.test.mts` if present, else `report.routes.test.mts`) and mirror however it builds a container + injects an authed identity. Do NOT invent a new auth-stub pattern.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/device.routes.test.mts`
Expected: FAIL — `deviceRoutes`/`deviceTokenRepo` not defined.

- [ ] **Step 3: Write the route (follow `notification.routes.mts`)**

```ts
// apps/api/src/routes/device.routes.mts
import { Elysia } from "elysia";
import { RegisterDeviceRequest } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function deviceRoutes(container: Container) {
  const { deviceTokenRepo, id } = container;
  return new Elysia({ prefix: "/api/v1/devices" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/",
      async ({ identity, body }) => {
        const userId = requireId(identity).userId;
        await deviceTokenRepo.upsertByToken({
          id: id(), userId, token: body.token, platform: body.platform, createdAt: new Date().toISOString(),
        });
        return data({ registered: true });
      },
      { requireAuth: true, body: RegisterDeviceRequest },
    )
    .delete(
      "/:token",
      async ({ identity, params }) => {
        requireId(identity);
        await deviceTokenRepo.deleteByToken(params.token);
        return data({ registered: false });
      },
      { requireAuth: true },
    );
}
```

> `container.id` is the id factory used elsewhere (see how other routes/facades get `id`). If the container exposes it under a different name, match that.

- [ ] **Step 4: Wire the container + mount the route**

In `apps/api/src/container.mts`:
- After the other `const …Repo = new …Repository(db);` lines: `const deviceTokenRepo = new DeviceTokenRepository(db);`
- Add `deviceTokenRepo,` to the returned container object (so routes/tests can reach it).
- Wherever repos' `ensureIndexes()` are invoked at startup, include `deviceTokenRepo.ensureIndexes()`.

In `apps/api/src/app.mts`: `import { deviceRoutes } from "./routes/device.routes.mts";` and add `.use(deviceRoutes(container))` alongside the other `.use(...)` calls.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/device.routes.test.mts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/routes/device.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/device.routes.test.mts
git commit -m "feat(api): device register/unregister routes"
```

---

## Task 5: `FcmPushSender` adapter (FCM HTTP v1)

**Files:**
- Create: `apps/api/src/push/fcm-push-sender.mts`
- Modify: `apps/api/src/env` (add `FCM_SECRET_ARN`, `FCM_PROJECT_ID` to the env schema/loader)
- Modify: `apps/api/src/container.mts` (construct the sender + `PushService`, expose `pushService`)
- Test: `apps/api/test/fcm-push-sender.test.mts`
- Add dep: `google-auth-library` (in `apps/api`)

**Interfaces:**
- Consumes: `PushSender`, `PushPayload`, `PushSendResult` (Task 3).
- Produces: `FcmPushSender implements PushSender`. Constructor takes `{ projectId: string; accessToken: () => Promise<string>; fetchImpl?: typeof fetch }` so tests inject a fake `fetch` + token. `send()` POSTs one message per token to `https://fcm.googleapis.com/v1/projects/{projectId}/messages:send`, collects tokens whose response error status is `UNREGISTERED` or `NOT_FOUND` (or HTTP 404) into `unregistered`.

- [ ] **Step 1: Write the failing test** (inject a fake fetch — no real network)

```ts
// apps/api/test/fcm-push-sender.test.mts
import { describe, expect, it } from "bun:test";
import { FcmPushSender } from "../src/push/fcm-push-sender.mts";
import type { PushPayload } from "../src/push/push.types.mts";

const payload: PushPayload = { title: "T", body: "B", data: { type: "message", conversationId: "c1" } };

describe("FcmPushSender", () => {
  it("marks a token unregistered when FCM returns UNREGISTERED", async () => {
    const calls: string[] = [];
    const fetchImpl = (async (_url: string, init: RequestInit) => {
      const parsed = JSON.parse(init.body as string) as { message: { token: string } };
      calls.push(parsed.message.token);
      if (parsed.message.token === "dead") {
        return new Response(JSON.stringify({ error: { status: "UNREGISTERED" } }), { status: 404 });
      }
      return new Response(JSON.stringify({ name: "ok" }), { status: 200 });
    }) as unknown as typeof fetch;

    const sender = new FcmPushSender({ projectId: "p1", accessToken: async () => "tok", fetchImpl });
    const res = await sender.send(["live", "dead"], payload);

    expect(calls.sort()).toEqual(["dead", "live"]);
    expect(res.unregistered).toEqual(["dead"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/fcm-push-sender.test.mts`
Expected: FAIL — `FcmPushSender` not found.

- [ ] **Step 3: Write the adapter**

```ts
// apps/api/src/push/fcm-push-sender.mts
import type { PushPayload, PushSender, PushSendResult } from "./push.types.mts";

interface FcmOptions {
  projectId: string;
  accessToken: () => Promise<string>;
  fetchImpl?: typeof fetch;
}

export class FcmPushSender implements PushSender {

  private readonly projectId: string;
  private readonly accessToken: () => Promise<string>;
  private readonly fetchImpl: typeof fetch;

  public constructor(opts: FcmOptions) {
    this.projectId = opts.projectId;
    this.accessToken = opts.accessToken;
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  public async send(tokens: string[], payload: PushPayload): Promise<PushSendResult> {
    if (tokens.length === 0) return { unregistered: [] };
    const token = await this.accessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`;
    const unregistered: string[] = [];
    await Promise.all(tokens.map(async (t) => {
      const res = await this.fetchImpl(url, {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title: payload.title, body: payload.body },
            data: payload.data,
          },
        }),
      });
      if (!res.ok) {
        const parsed = (await res.json().catch(() => ({}))) as { error?: { status?: string } };
        const status = parsed.error?.status;
        if (status === "UNREGISTERED" || status === "NOT_FOUND" || res.status === 404) unregistered.push(t);
      }
    }));
    return { unregistered };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/fcm-push-sender.test.mts`
Expected: PASS.

- [ ] **Step 5: Wire env + container**

- `bun add google-auth-library` in `apps/api`.
- Add `FCM_SECRET_ARN` (optional string) and `FCM_PROJECT_ID` (optional string) to the env schema/loader (`apps/api/src/env` — match the existing TypeBox `Value.Parse` env pattern; keep them optional so local/dev runs without FCM still boot).
- In `container.mts`: build the access-token function using `google-auth-library`'s `GoogleAuth` with the service-account JSON read from Secrets Manager (reuse the existing Secrets Manager access used for `APP_SECRET_ARN`; scope: `https://www.googleapis.com/auth/firebase.messaging`). Construct `const pushSender = new FcmPushSender({ projectId: env.fcmProjectId, accessToken });` and `const pushService = new PushService(deviceTokenRepo, pushSender);`. Expose `pushService` on the container.
- **Guard:** if `FCM_SECRET_ARN`/`FCM_PROJECT_ID` are absent (local/dev), construct `pushService` with a no-op sender (`{ send: async () => ({ unregistered: [] }) }`) so the app boots and nothing is sent. Log one info line that push is disabled.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/push/fcm-push-sender.mts apps/api/src/env apps/api/src/container.mts apps/api/package.json apps/api/test/fcm-push-sender.test.mts
git commit -m "feat(api): FcmPushSender (HTTP v1) + container/env wiring with local no-op guard"
```

---

## Task 6: Emit push on in-app notifications (`NotificationFacade.create`)

**Files:**
- Modify: `apps/api/src/facades/notification.facade.mts`
- Modify: `apps/api/src/container.mts` (pass `pushService` into `NotificationFacade`)
- Test: `apps/api/test/notification.facade.test.mts` (extend/create)

**Interfaces:**
- Consumes: `PushNotifier` (Task 3), `pushService` (Task 5).
- Produces: `NotificationFacade` now takes a `PushNotifier` and, after persisting, calls `push.pushToUsers([userId], { title, body, data: { type } })`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/notification.facade.test.mts  (add this test; create file if absent)
import { describe, expect, it } from "bun:test";
import { NotificationFacade } from "../src/facades/notification.facade.mts";
import type { Notification } from "@bjj/contract";
import type { PushPayload } from "../src/push/push.types.mts";

function harness() {
  const inserted: Notification[] = [];
  const notifRepo = {
    insert: async (n: Notification) => { inserted.push(n); return n; },
    listByUser: async () => ({ items: [], total: 0 }),
    markRead: async () => {},
    markAllRead: async () => {},
  };
  const pushes: { userIds: string[]; payload: PushPayload }[] = [];
  const push = { pushToUsers: async (userIds: string[], payload: PushPayload) => { pushes.push({ userIds, payload }); } };
  let n = 0;
  return { f: new NotificationFacade(notifRepo, push, () => `id-${n++}`), pushes };
}

describe("NotificationFacade.create push", () => {
  it("pushes to the notified user after persisting", async () => {
    const { f, pushes } = harness();
    await f.create("u9", "forum_answer", "New answer", "Someone answered");
    expect(pushes).toHaveLength(1);
    expect(pushes[0].userIds).toEqual(["u9"]);
    expect(pushes[0].payload.title).toBe("New answer");
    expect(pushes[0].payload.data.type).toBe("forum_answer");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/notification.facade.test.mts`
Expected: FAIL — constructor arity / `pushToUsers` not called.

- [ ] **Step 3: Modify the facade**

```ts
// apps/api/src/facades/notification.facade.mts — add import + param + call
import type { PushNotifier } from "../push/push.types.mts";
// ...
public constructor(
  private readonly notifications: Pick<NotificationRepository, "insert" | "listByUser" | "markRead" | "markAllRead">,
  private readonly push: PushNotifier,
  private readonly newId: IdFactory,
) {}

public async create(userId: string, type: NotificationType, title: string, body: string): Promise<Notification> {
  const n = await this.notifications.insert({
    id: this.newId(), userId, type, title, body, read: false, createdAt: new Date().toISOString(),
  });
  await this.push.pushToUsers([userId], { title, body, data: { type } });
  return n;
}
```

- [ ] **Step 4: Wire container**

In `container.mts`, change `new NotificationFacade(notificationRepo, id)` → `new NotificationFacade(notificationRepo, pushService, id)`. Ensure `pushService` is declared before this line.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/notification.facade.test.mts`
Then the whole API suite: `TEST_MONGODB_URI="mongodb://localhost:27021" bun test`. Fix any other facade tests that construct `NotificationFacade` (forum, gym-claim harnesses) by passing a no-op `{ pushToUsers: async () => {} }`.
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/notification.facade.mts apps/api/src/container.mts apps/api/test
git commit -m "feat(api): push in-app notifications to devices on create"
```

---

## Task 7: Emit push on new message (`MessagingFacade.sendMessage`)

**Files:**
- Modify: `apps/api/src/facades/messaging.facade.mts`
- Modify: `apps/api/src/container.mts` (pass `pushService`)
- Modify: `apps/api/test/messaging.facade.test.mts` (harness passes a capturing push fake; add a test)

**Interfaces:**
- Consumes: `PushNotifier` (Task 3), plus existing `otherParticipantIds`, participant `muted`, block checks, and display-name resolution (`users.findById`, from PR #46).
- Produces: after a message is persisted, `sendMessage` computes recipients = other active participants, **excluding** blocked (either way) and **muted** participants, and calls `push.pushToUsers(recipientIds, { title: senderDisplayName, body: preview, data: { type: "message", conversationId } })`.

- [ ] **Step 1: Write the failing test** (extend the existing messaging harness to capture pushes)

Add to `apps/api/test/messaging.facade.test.mts`:
```ts
it("sendMessage pushes to other participants but not muted or the sender", async () => {
  const seed = {
    memberships: [member("u1"), member("u2"), member("u3")],
    users: [user("u1", "Alice"), user("u2", "Bob"), user("u3", "Cara")],
    conversations: [{ id: "c1", kind: "group" as const, gymId: "g1", title: "Squad", createdBy: "u1" }],
    participants: [
      { id: "p1", conversationId: "c1", userId: "u1", role: "member" as const, muted: false },
      { id: "p2", conversationId: "c1", userId: "u2", role: "member" as const, muted: false },
      { id: "p3", conversationId: "c1", userId: "u3", role: "member" as const, muted: true },
    ],
  };
  const { f, pushes } = facade(seed);           // harness now returns `pushes`
  await f.sendMessage("u1", "c1", { body: "hello team" }, "practitioner");
  expect(pushes).toHaveLength(1);
  expect(pushes[0].userIds.sort()).toEqual(["u2"]);   // u1 = sender, u3 = muted
  expect(pushes[0].payload.title).toBe("Alice");
  expect(pushes[0].payload.data).toMatchObject({ type: "message", conversationId: "c1" });
});
```
And extend the harness: add a capturing `push = { pushToUsers: async (userIds, payload) => { pushes.push({ userIds, payload }); } }`, pass it into `new MessagingFacade(...)` in the correct position, and return `pushes` from `facade()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/messaging.facade.test.mts`
Expected: FAIL — `pushes` empty / constructor arity.

- [ ] **Step 3: Modify the facade**

- Add `import type { PushNotifier } from "../push/push.types.mts";`
- Add `private readonly push: PushNotifier,` to the constructor (place consistently, e.g. after `users`, before `newId`).
- In `sendMessage`, after the message is persisted and `updateLastMessage` is done, compute and fire the push:

```ts
// recipients = active participants except sender, blocked, or muted
const parts = await this.participants.listByConversation(conversationId);
const recipientIds: string[] = [];
for (const p of parts) {
  if (p.userId === userId || p.leftAt || p.muted) continue;
  if (await this.blocks.existsEitherWay(userId, p.userId)) continue;
  recipientIds.push(p.userId);
}
if (recipientIds.length > 0) {
  const sender = await this.users.findById(userId);
  await this.push.pushToUsers(recipientIds, {
    title: sender?.displayName ?? "New message",
    body: req.body,
    data: { type: "message", conversationId },
  });
}
```
> Match the actual variable names in `sendMessage` (the persisted message, the request field holding the text). Read the method first.

- [ ] **Step 4: Wire container**

Pass `pushService` into `new MessagingFacade(...)` in the same position as the constructor param.

- [ ] **Step 5: Run tests to verify they pass**

Run the messaging facade test, then the whole API suite:
`cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/messaging.facade.mts apps/api/src/container.mts apps/api/test/messaging.facade.test.mts
git commit -m "feat(api): push new messages to participants (skip sender/muted/blocked)"
```

---

## Task 8: Mobile — device registration API client

**Files:**
- Create: `apps/mobile/lib/features/push/data/device_repository.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart` (add `devices` + `deviceByToken`)
- Test: `apps/mobile/test/push/device_repository_test.dart`

**Interfaces:**
- Consumes: `Dio` client (follow `ApiMessagingRepository`), `Endpoints`.
- Produces: `abstract class DeviceRepository { Future<void> registerDevice(String token, String platform); Future<void> unregisterDevice(String token); }` + `ApiDeviceRepository(Dio)`; Riverpod `deviceRepositoryProvider`.

- [ ] **Step 1: Write the failing test** (mock Dio like `messaging_repository_test.dart` does)

```dart
// apps/mobile/test/push/device_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/data/device_repository.dart';
import 'package:bjj_open_mat/core/api/endpoints.dart';

// Reuse the same Dio-mock approach as messaging_repository_test.dart.
void main() {
  test('registerDevice POSTs token + platform to /devices', () async {
    late RequestOptions captured;
    final dio = Dio()..httpClientAdapter = _CapturingAdapter((opts) => captured = opts);
    final repo = ApiDeviceRepository(dio);
    await repo.registerDevice('abc', 'ios');
    expect(captured.path, Endpoints.devices);
    expect(captured.data['token'], 'abc');
    expect(captured.data['platform'], 'ios');
  });
}
```
> Copy `_CapturingAdapter` (or the equivalent mock) from `messaging_repository_test.dart`; do not invent a new HTTP mock.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/push/device_repository_test.dart`
Expected: FAIL — `ApiDeviceRepository`/`Endpoints.devices` missing.

- [ ] **Step 3: Add endpoints + repository**

In `endpoints.dart`: `static const String devices = '/api/v1/devices';` and `static String deviceByToken(String token) => '/api/v1/devices/$token';`.

```dart
// apps/mobile/lib/features/push/data/device_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

abstract class DeviceRepository {
  Future<void> registerDevice(String token, String platform);
  Future<void> unregisterDevice(String token);
}

class ApiDeviceRepository implements DeviceRepository {
  final Dio _dio;
  ApiDeviceRepository(this._dio);

  @override
  Future<void> registerDevice(String token, String platform) async {
    await _dio.post(Endpoints.devices, data: {'token': token, 'platform': platform});
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _dio.delete(Endpoints.deviceByToken(token));
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => ApiDeviceRepository(ref.read(dioProvider)),
);
```
> Match the actual Dio provider name (`dioProvider`/`apiClientProvider`) used by `messaging_repository.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/push/device_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/push/data/device_repository.dart apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/push/device_repository_test.dart
git commit -m "feat(mobile): device registration API client"
```

---

## Task 9: Mobile — push deep-link routing (pure function)

**Files:**
- Create: `apps/mobile/lib/features/push/push_routing.dart`
- Test: `apps/mobile/test/push/push_routing_test.dart`

**Interfaces:**
- Produces: `String? routeForPushData(Map<String, dynamic> data)` — returns `/messages/<conversationId>` when `data['type'] == 'message'` and a `conversationId` is present; returns `/notifications` for other known types; returns `null` when it can't resolve.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/push/push_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/push_routing.dart';

void main() {
  test('message payload routes to the conversation', () {
    expect(routeForPushData({'type': 'message', 'conversationId': 'c1'}), '/messages/c1');
  });
  test('non-message known type routes to notifications', () {
    expect(routeForPushData({'type': 'forum_answer'}), '/notifications');
  });
  test('unknown/empty payload returns null', () {
    expect(routeForPushData({}), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/push/push_routing_test.dart`
Expected: FAIL — `routeForPushData` missing.

- [ ] **Step 3: Implement**

```dart
// apps/mobile/lib/features/push/push_routing.dart
String? routeForPushData(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == null) return null;
  if (type == 'message') {
    final id = data['conversationId'] as String?;
    return (id != null && id.isNotEmpty) ? '/messages/$id' : null;
  }
  return '/notifications';
}
```
> Confirm `/notifications` is a real route in the mobile `go_router` config; if the notifications screen lives at a different path, use that path.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/push/push_routing_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/push/push_routing.dart apps/mobile/test/push/push_routing_test.dart
git commit -m "feat(mobile): push deep-link routing resolver"
```

---

## Task 10: Mobile — `PushController` (permission + token lifecycle)

**Files:**
- Create: `apps/mobile/lib/features/push/data/push_messaging.dart` (interface + real Firebase impl)
- Create: `apps/mobile/lib/features/push/push_controller.dart`
- Test: `apps/mobile/test/push/push_controller_test.dart`

**Interfaces:**
- `abstract class PushMessaging { Future<bool> requestPermission(); Future<String?> getToken(); Stream<String> get onTokenRefresh; }` — the real impl wraps `FirebaseMessaging.instance`; tests use a fake.
- `class PushController` (constructed with `PushMessaging` + `DeviceRepository`): `Future<void> start()` (request permission; if granted, get token + `registerDevice`; subscribe to refresh → re-register), `Future<void> stop(String? token)` (unregister). Platform string derived from `Platform.isIOS ? 'ios' : 'android'` — inject it for testability.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/push/push_controller_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/data/push_messaging.dart';
import 'package:bjj_open_mat/features/push/data/device_repository.dart';
import 'package:bjj_open_mat/features/push/push_controller.dart';

class _FakeMessaging implements PushMessaging {
  final bool granted;
  final String? token;
  final _refresh = StreamController<String>.broadcast();
  _FakeMessaging({this.granted = true, this.token = 'tok-1'});
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => _refresh.stream;
  void emit(String t) => _refresh.add(t);
}

class _FakeDeviceRepo implements DeviceRepository {
  final registered = <String>[];
  final unregistered = <String>[];
  @override
  Future<void> registerDevice(String token, String platform) async => registered.add('$token:$platform');
  @override
  Future<void> unregisterDevice(String token) async => unregistered.add(token);
}

void main() {
  test('start registers the token when permission granted', () async {
    final repo = _FakeDeviceRepo();
    final c = PushController(_FakeMessaging(), repo, platform: 'ios');
    await c.start();
    expect(repo.registered, ['tok-1:ios']);
  });

  test('start does nothing when permission denied', () async {
    final repo = _FakeDeviceRepo();
    final c = PushController(_FakeMessaging(granted: false), repo, platform: 'ios');
    await c.start();
    expect(repo.registered, isEmpty);
  });

  test('token refresh re-registers', () async {
    final repo = _FakeDeviceRepo();
    final msg = _FakeMessaging();
    final c = PushController(msg, repo, platform: 'android');
    await c.start();
    msg.emit('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(repo.registered, ['tok-1:android', 'tok-2:android']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/push/push_controller_test.dart`
Expected: FAIL — classes missing.

- [ ] **Step 3: Implement `PushMessaging` interface + `PushController`**

```dart
// apps/mobile/lib/features/push/data/push_messaging.dart
abstract class PushMessaging {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}
```
(The real `FirebaseMessaging`-backed implementation is added in Task 12 with the SDK.)

```dart
// apps/mobile/lib/features/push/push_controller.dart
import 'dart:async';
import 'data/push_messaging.dart';
import 'data/device_repository.dart';

class PushController {
  final PushMessaging _messaging;
  final DeviceRepository _devices;
  final String platform;
  StreamSubscription<String>? _sub;

  PushController(this._messaging, this._devices, {required this.platform});

  Future<void> start() async {
    final granted = await _messaging.requestPermission();
    if (!granted) return;
    final token = await _messaging.getToken();
    if (token != null) await _devices.registerDevice(token, platform);
    _sub ??= _messaging.onTokenRefresh.listen((t) {
      _devices.registerDevice(t, platform);
    });
  }

  Future<void> stop(String? token) async {
    await _sub?.cancel();
    _sub = null;
    if (token != null) await _devices.unregisterDevice(token);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/push/push_controller_test.dart`
Expected: PASS (all 3).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/push/data/push_messaging.dart apps/mobile/lib/features/push/push_controller.dart apps/mobile/test/push/push_controller_test.dart
git commit -m "feat(mobile): PushController token lifecycle (fake-messaging tested)"
```

---

## Task 11: Mobile — Firebase SDK + bootstrap wiring

**Files:**
- Modify: `apps/mobile/pubspec.yaml` (add `firebase_core`, `firebase_messaging`, `flutter_local_notifications`)
- Create: `apps/mobile/lib/features/push/data/firebase_push_messaging.dart` (real `PushMessaging` impl)
- Modify: `apps/mobile/lib/main.dart` (or the app bootstrap): `Firebase.initializeApp`, register the top-level background handler, start `PushController` after auth, and wire foreground `onMessage` → local banner + `onMessageOpenedApp`/`getInitialMessage` → `routeForPushData` → `router.go(...)`.

**Interfaces:**
- Consumes: `PushController` (Task 10), `routeForPushData` (Task 9), the app's `go_router` instance and auth state.
- Produces: `FirebasePushMessaging implements PushMessaging`; a `pushControllerProvider`; bootstrap that starts push on authenticated and calls `stop` on logout.

- [ ] **Step 1: Add deps**

`cd apps/mobile && flutter pub add firebase_core firebase_messaging flutter_local_notifications`

- [ ] **Step 2: Implement the real `PushMessaging`**

```dart
// apps/mobile/lib/features/push/data/firebase_push_messaging.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'push_messaging.dart';

class FirebasePushMessaging implements PushMessaging {
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _fm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;
}
```

- [ ] **Step 3: Bootstrap wiring** (in `main.dart` / app root)

- Before `runApp`: `await Firebase.initializeApp();` and register a top-level background handler:
  ```dart
  @pragma('vm:entry-point')
  Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}
  // in main(): FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  ```
- After the user is authenticated, resolve `pushControllerProvider` and call `start()`. On logout, call `stop(currentToken)`.
- Foreground: `FirebaseMessaging.onMessage.listen(...)` → show a banner via `flutter_local_notifications` (init a default Android channel + iOS settings).
- Tap: `FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data))` and, at startup, `final initial = await FirebaseMessaging.instance.getInitialMessage(); if (initial != null) _open(initial.data);` where `_open(data)` does `final r = routeForPushData(Map<String,dynamic>.from(data)); if (r != null) router.go(r);`.

- [ ] **Step 4: Verify build + analyze**

Run: `cd apps/mobile && flutter analyze lib/features/push lib/main.dart`
Expected: no issues. (A full Android build is broken locally per the known gotcha — rely on CI + `flutter analyze` + the unit tests from Tasks 8–10.)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/lib/features/push/data/firebase_push_messaging.dart apps/mobile/lib/main.dart
git commit -m "feat(mobile): Firebase Messaging bootstrap + foreground/tap handlers"
```

---

## Task 12: Platform config + CI (iOS entitlements, Android google-services, secrets)

**Files:**
- Add (from secrets, NOT committed if treated as secret): `apps/mobile/ios/Runner/GoogleService-Info.plist`, `apps/mobile/android/app/google-services.json`
- Modify: `apps/mobile/android/build.gradle` + `apps/mobile/android/app/build.gradle` (google-services gradle plugin)
- Modify: `apps/mobile/ios/Runner/Runner.entitlements` (`aps-environment`), `ios/Runner/Info.plist` (Background Modes → remote-notification), `ios/Runner/AppDelegate.swift` (`registerForRemoteNotifications` if needed by the plugin)
- Modify: `.github/workflows/mobile-release.yml` (write the two Firebase config files from CI secrets before the build)

**Interfaces:** none (build config).

- [ ] **Step 1: Android google-services**
- Place `google-services.json` at `apps/mobile/android/app/`.
- In `android/build.gradle`, add the classpath `com.google.gms:google-services:<current>`; in `android/app/build.gradle`, apply `plugin: 'com.google.gms.google-services'`. (Follow FlutterFire docs for the exact current versions at implementation time.)

- [ ] **Step 2: iOS capabilities**
- Add Push Notifications + Background Modes (Remote notifications) to the Runner target; ensure `Runner.entitlements` has `aps-environment` and `Info.plist` includes `UIBackgroundModes → remote-notification`.
- Place `GoogleService-Info.plist` in `ios/Runner/` and ensure it's added to the Runner target in the Xcode project.

- [ ] **Step 3: CI secret injection**
- In `mobile-release.yml`, before the Flutter build steps, decode two new repo secrets (e.g. `GOOGLE_SERVICES_JSON_BASE64`, `GOOGLE_SERVICE_INFO_PLIST_BASE64`) to their target paths. Mirror however the workflow already injects signing secrets. Document the two new secrets in the PR body.
- Add `FCM_SECRET_ARN` + `FCM_PROJECT_ID` to the API Lambda's environment in `infra/` (Terraform/CDK — match the existing `APP_SECRET_ARN` wiring) so the deployed API can send.

- [ ] **Step 4: Verify**
- `cd apps/mobile && flutter analyze` (clean).
- Confirm a CI mobile-release run builds successfully (this is the real build gate; local Android build is known-broken).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/android apps/mobile/ios .github/workflows/mobile-release.yml infra
git commit -m "chore(mobile): FCM/APNs platform config + CI secret injection"
```

> Do NOT commit real secret files if they contain sensitive keys; prefer CI injection. `GoogleService-Info.plist`/`google-services.json` are generally shippable in the app bundle but confirm with the user before committing them.

---

## Task 13: End-to-end verification (manual, build 120+)

**Files:** none (verification).

- [ ] **Step 1:** Merge the feature to `main` (explicit user go-ahead), let `api-deploy.yml` redeploy the API with `FCM_*` env set.
- [ ] **Step 2:** Run `mobile-release.yml` to produce a new build (≥120) with the Firebase config; install the release APK on the emulator/device (`adb install -r`) and, for iOS, TestFlight on a real device (APNs does not work on the iOS simulator).
- [ ] **Step 3:** From a second account that shares a gym, send a direct message to the test user.
- [ ] **Step 4:** Confirm: (a) foreground → in-app banner with the sender's name; (b) background → OS notification; (c) tap → opens the correct conversation; (d) a muted conversation produces no push; (e) messaging yourself produces no push.
- [ ] **Step 5:** Trigger an in-app event (e.g., a forum answer) and confirm it also pushes.

---

## Self-review notes

- **Spec coverage:** §3 components → Tasks 1–12; §4 data flow A/B/C → Tasks 8/10 (register), 3/5/6/7 (send), 9/11 (receive+tap); §5 external setup → Prerequisites + Task 12; §6 testing → per-task tests + Task 13; §7 scope (no prefs UI) → honored (no settings screen tasks).
- **Type consistency:** `PushPayload{title,body,data}`, `PushSender.send(tokens,payload)→{unregistered}`, `PushNotifier.pushToUsers(userIds,payload)`, `DeviceToken{...platform:'ios'|'android'}` used identically across Tasks 1/3/5/6/7 and mobile `routeForPushData`/`PushMessaging`/`PushController` across 9/10/11.
- **Message push-only:** Task 7 pushes without persisting a `notifications` row; Task 6 covers the persisted in-app events. Consistent with the spec decision.
