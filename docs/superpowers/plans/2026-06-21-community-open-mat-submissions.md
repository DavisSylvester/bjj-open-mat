# Community Open-Mat Submissions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any authenticated user submit an open-mat session (creating the gym inline if needed); submissions are live immediately but unverified, and the gym owner or an admin can verify or hide them. Make "Add open mat" a first-class CTA.

**Architecture:** Add `verified`/`status` flags to the open-mat model (no hard pending-gate). Open `POST /open-mats` to any authed user; the facade creates an unverified gym when `newGym` is supplied and computes `verified` from the caller's relationship to the gym. Public lists exclude `hidden`. A new `admin` role plus owner-or-admin guards back verify/hide endpoints. Mobile gets a center-nav "+" entry, an all-gyms-search create form with inline gym add, unverified badges, owner verify/hide, and an admin review screen.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (API); Flutter + Riverpod + go_router + Dio (mobile). Spec: `docs/superpowers/specs/2026-06-21-community-open-mat-submissions-design.md`.

**Git note:** Per project policy, commits are authored by the user. Treat each "Commit" step as a checkpoint; run it only if the executing context is authorized to commit, otherwise leave changes staged for the user.

---

## File Structure

**Contract (`packages/contract/src`)**
- `schemas/open-mat.mts` — add `verified`, `status`.
- `schemas/requests/open-mat-requests.mts` — `NewGymInput`, optional `gymId`+`newGym`, extra list-query filters.
- `enums/user-role.mts` — add `admin`.

**API (`apps/api/src`)**
- `auth/auth.middleware.mts` — `requireAdmin` macro.
- `repositories/open-mat.repository.mts` — persist+filter `verified`/`status`/`hostId`; allow ownerless insert.
- `facades/open-mat.facade.mts` — open create, inline gym, `verified` logic, `verify`/`setHidden`/`assertOwnerOrAdmin`.
- `routes/open-mat.routes.mts` — `requireAuth` create, list filters, verify/hide endpoints.

**Mobile (`apps/mobile/lib`)**
- `features/open_mats/models/open_mat.dart` — `verified`, `status`.
- `features/open_mats/data/session_requests.dart` — `newGym`, optional gymId.
- `features/open_mats/data/session_repository.dart` — `verify`/`hide`/`listUnverified`; create supports newGym.
- `features/gyms/data/gym_repository.dart` — `searchAll(query)` (reuse list).
- `features/admin/screens/create_session_screen.dart` — all-gyms search + inline new gym; works for any role.
- `app/router.dart` — top-level `/add-session` route; admin review route.
- `shared/widgets/app_bottom_nav.dart`, `shared/widgets/om_widgets.dart` — center "+" button.
- `shared/widgets/session_row.dart` — "Unverified" badge.
- `features/admin/screens/session_mgmt_screen.dart` — Verify/Hide row actions.
- `features/admin/screens/admin_review_screen.dart` — NEW global review.

---

## Phase A — Contract

### Task 1: Add `verified` + `status` to OpenMat, `admin` role, and `newGym` create input

**Files:**
- Modify: `packages/contract/src/schemas/open-mat.mts`
- Modify: `packages/contract/src/enums/user-role.mts`
- Modify: `packages/contract/src/schemas/requests/open-mat-requests.mts`
- Test: `packages/contract/test/open-mat-request.test.mts` (create if `test/` exists; otherwise put under `apps/api/test/contract-open-mat.test.mts` and import from `@bjj/contract`)

- [ ] **Step 1: Write the failing test**

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CreateOpenMatRequest, OpenMat, UserRole } from "@bjj/contract";

describe("contract: community submissions", () => {
  it("UserRole accepts admin", () => {
    expect(Value.Check(UserRole, "admin")).toBe(true);
  });

  it("OpenMat carries verified + status", () => {
    const om = Value.Create(OpenMat);
    expect(om).toHaveProperty("verified");
    expect(om).toHaveProperty("status");
  });

  it("CreateOpenMatRequest allows newGym instead of gymId", () => {
    const req = { newGym: { name: "New BJJ", address: "1 Main St" }, title: "Open Mat", startTime: "19:00", endTime: "21:00" };
    expect(Value.Check(CreateOpenMatRequest, req)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/contract-open-mat.test.mts` (or the contract test path)
Expected: FAIL — `admin` not in union / `verified` missing / `newGym` unknown property.

- [ ] **Step 3: Edit `enums/user-role.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const UserRole = t.Union(
  [t.Literal("practitioner"), t.Literal("gym_owner"), t.Literal("admin")],
  { $id: "UserRole" },
);
export type UserRole = Static<typeof UserRole>;
```

- [ ] **Step 4: Edit `schemas/open-mat.mts`** — add these two properties to the `OpenMat` object (after `isCancelled`):

```typescript
    isCancelled: t.Boolean({ default: false }),
    verified: t.Boolean({ default: false }),
    status: t.Union([t.Literal("live"), t.Literal("hidden")], { default: "live" }),
```

- [ ] **Step 5: Edit `schemas/requests/open-mat-requests.mts`** — add `NewGymInput`, make `gymId` optional, add `newGym`, and extend `OpenMatListQuery`:

```typescript
export const NewGymInput = t.Object(
  {
    name: t.String({ minLength: 1 }),
    address: t.String({ minLength: 1 }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    country: t.Optional(t.String()),
  },
  { $id: "NewGymInput" },
);
export type NewGymInput = Static<typeof NewGymInput>;

export const CreateOpenMatRequest = t.Object(
  {
    gymId: t.Optional(t.String()),
    newGym: t.Optional(NewGymInput),
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
```

Add to `OpenMatListQuery` object:

```typescript
    status: t.Optional(t.Union([t.Literal("live"), t.Literal("hidden")])),
    verified: t.Optional(t.Boolean()),
    submittedByMe: t.Optional(t.Boolean()),
```

Export `NewGymInput` from the contract barrel (`packages/contract/src/schemas/requests/index.mts` and root `index.mts`) following the existing export pattern.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd apps/api && bun test test/contract-open-mat.test.mts`
Expected: PASS. Then `cd packages/contract && bunx tsc --noEmit` (or repo `bun run type-check`) — no type errors.

- [ ] **Step 7: Commit**

```bash
git add packages/contract apps/api/test/contract-open-mat.test.mts
git commit -m "feat(contract): add open-mat verified/status, admin role, newGym create input"
```

---

## Phase B — API

### Task 2: Open-mat repository persists/filters verified, status, hostId; allows ownerless insert

**Files:**
- Modify: `apps/api/src/repositories/open-mat.repository.mts`
- Test: `apps/api/test/open-mat.repository.test.mts` (extend existing)

- [ ] **Step 1: Write the failing test** (append to the existing describe block; mirror its MongoDB setup)

```typescript
it("list excludes hidden and filters by verified + hostId", async () => {
  const repo = new OpenMatRepository(db); // `db` from existing test setup
  const base = { startTime: "19:00", endTime: "21:00", isRecurring: true, skillLevel: "all", giType: "both", isCancelled: false, address: "x", city: "SD", state: "CA" } as const;
  await repo.insert({ ...base, id: "v1", gymId: "g1", title: "V", verified: true, status: "live", hostId: "u1" } as any, "owner1");
  await repo.insert({ ...base, id: "u2", gymId: "g1", title: "U", verified: false, status: "live", hostId: "u2" } as any, undefined as any);
  await repo.insert({ ...base, id: "h1", gymId: "g1", title: "H", verified: true, status: "hidden", hostId: "u1" } as any, "owner1");

  const live = await repo.list({}, 0, 50);
  expect(live.items.find((m) => m.id === "h1")).toBeUndefined(); // hidden excluded
  expect(live.items.length).toBe(2);

  const unverified = await repo.list({ verified: false }, 0, 50);
  expect(unverified.items.every((m) => m.verified === false)).toBe(true);

  const mine = await repo.list({ hostId: "u2" }, 0, 50);
  expect(mine.items.map((m) => m.id)).toEqual(["u2"]);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/api && bun test test/open-mat.repository.test.mts`
Expected: FAIL — hidden not excluded / `verified`/`hostId` filters unknown. (Requires MongoDB on 27017.)

- [ ] **Step 3: Implement** — in `open-mat.repository.mts`:

Extend `OpenMatFilter`:
```typescript
export interface OpenMatFilter {
  dayOfWeek?: number;
  giType?: GiType;
  skillLevel?: SkillLevel;
  gymOwnerId?: string;
  hostId?: string;
  verified?: boolean;
  status?: "live" | "hidden";
}
```

Make `gymOwnerId` optional on the doc + insert:
```typescript
interface OpenMatDoc extends OpenMatDetail {
  _id: string;
  gymOwnerId?: string;
  geo?: { type: "Point"; coordinates: [number, number] };
}
```
```typescript
public async insert(detail: OpenMatDetail, gymOwnerId: string | undefined): Promise<OpenMatDetail> {
  const doc: OpenMatDoc = { ...detail, _id: detail.id, gymOwnerId };
  if (detail.latitude !== undefined && detail.longitude !== undefined) {
    doc.geo = { type: "Point", coordinates: [detail.longitude, detail.latitude] };
  }
  await this.collection<OpenMatDoc>(COLLECTIONS.openMats).insertOne(doc);
  return detail;
}
```

In `list`, after the existing clauses add:
```typescript
  if (filter.gymOwnerId) q.gymOwnerId = filter.gymOwnerId;
  if (filter.hostId) q.hostId = filter.hostId;
  if (filter.verified !== undefined) q.verified = filter.verified;
  // Default to live-only unless a status is explicitly requested.
  q.status = filter.status ?? "live";
```
Note: existing docs may lack `status`; backfill is handled by treating missing as live — change the clause to:
```typescript
  if (filter.status) q.status = filter.status;
  else q.status = { $ne: "hidden" };
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/api && bun test test/open-mat.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/open-mat.repository.mts apps/api/test/open-mat.repository.test.mts
git commit -m "feat(api): open-mat repo filters verified/status/hostId, allows ownerless insert"
```

### Task 3: Facade — anyone can create; inline gym; verified logic

**Files:**
- Modify: `apps/api/src/facades/open-mat.facade.mts`
- Test: `apps/api/test/open-mat.facade.test.mts` (update existing calls + add new)

- [ ] **Step 1: Update the failing tests** — the `create` signature gains `role`. Update existing `deps()` to add `insert` to the gym fake and update all `facade.create("owner-1", {...})` calls to `facade.create("owner-1", "gym_owner", {...})`. Then add:

```typescript
it("non-owner submission is live but unverified", async () => {
  const d = deps();
  const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-x");
  const created = await facade.create("stranger", "practitioner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
  expect(created.verified).toBe(false);
  expect(created.status).toBe("live");
  expect(created.hostId).toBe("stranger");
});

it("gym owner submission to own gym is verified", async () => {
  const d = deps();
  const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-y");
  const created = await facade.create("owner-1", "gym_owner", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
  expect(created.verified).toBe(true);
});

it("admin submission is verified", async () => {
  const d = deps();
  const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-z");
  const created = await facade.create("anyadmin", "admin", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
  expect(created.verified).toBe(true);
});

it("newGym creates an unverified ownerless gym", async () => {
  const d = deps();
  const facade = new OpenMatFacade(d.matRepo, d.gymRepo, d.rsvpRepo, () => "om-n");
  const created = await facade.create("stranger", "practitioner", { newGym: { name: "Fresh BJJ", address: "9 St" }, title: "Fri", startTime: "19:00", endTime: "21:00" });
  expect(created.gymName).toBe("Fresh BJJ");
  expect(created.verified).toBe(false);
  expect(d.insertedGyms.length).toBe(1);
  expect(d.insertedGyms[0].isVerified).toBe(false);
  expect(d.insertedGyms[0].ownerId).toBeUndefined();
});
```

Update `deps()` gym fake to capture inserts:
```typescript
const insertedGyms: Gym[] = [];
// ...
gymRepo: {
  findById: async (id: string): Promise<Gym | null> => (id === "g-1" ? gym : null),
  insert: async (g: Gym): Promise<Gym> => { insertedGyms.push(g); return g; },
},
// ...
return { matRepo, gymRepo, rsvpRepo, counts, insertedGyms };
```
and `type FakeGymRepo = Pick<GymRepository, "findById" | "insert">;`

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/api && bun test test/open-mat.facade.test.mts`
Expected: FAIL — arity/`role`/`verified`/`insert` errors.

- [ ] **Step 3: Implement facade changes**

Update constructor dep type and `create`:
```typescript
import type { CreateOpenMatRequest, Gym, OpenMat, OpenMatDetail, UpdateOpenMatRequest, UserRole } from "@bjj/contract";
// ...
public constructor(
  private readonly mats: Pick<OpenMatRepository, "insert" | "findById" | "update" | "list" | "findNearby" | "setAttendeeCount">,
  private readonly gyms: Pick<GymRepository, "findById" | "insert">,
  private readonly rsvps: Pick<RsvpRepository, "add" | "remove" | "count" | "userIds">,
  private readonly newId: IdFactory,
) {}

public async create(submitterId: string, role: UserRole, req: CreateOpenMatRequest): Promise<OpenMatDetail> {
  let gym: Gym | null;
  if (req.gymId) {
    gym = await this.gyms.findById(req.gymId);
    if (!gym) throw new AppError("not_found", `Gym ${req.gymId} not found`);
  } else if (req.newGym) {
    gym = await this.gyms.insert({
      id: this.newId(),
      name: req.newGym.name,
      address: req.newGym.address,
      city: req.newGym.city,
      state: req.newGym.state,
      postalCode: req.newGym.postalCode,
      country: req.newGym.country,
      amenities: [],
      isVerified: false,
      createdAt: new Date().toISOString(),
    });
  } else {
    throw new AppError("bad_request", "Provide gymId or newGym");
  }

  const verified = role === "admin" || (gym.ownerId !== undefined && gym.ownerId === submitterId);
  const detail: OpenMatDetail = {
    id: this.newId(),
    gymId: gym.id,
    hostId: submitterId,
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
    verified,
    status: "live",
    feeCents: req.feeCents,
    attendeeCount: 0,
    gymName: gym.name,
    latitude: gym.location?.lat,
    longitude: gym.location?.lng,
    address: gym.address,
    city: gym.city ?? "",
    state: gym.state ?? "",
    postalCode: gym.postalCode,
    gymRating: gym.rating,
    createdAt: new Date().toISOString(),
  };
  return this.mats.insert(detail, gym.ownerId);
}
```

Add owner-or-admin helpers + verify/hide:
```typescript
public async assertOwnerOrAdmin(callerId: string, role: UserRole, openMatId: string): Promise<OpenMatDetail> {
  const mat = await this.mats.findById(openMatId);
  if (!mat) throw new AppError("not_found", `Open mat ${openMatId} not found`);
  if (role === "admin") return mat;
  const gym = await this.gyms.findById(mat.gymId);
  if (!gym || gym.ownerId !== callerId) throw new AppError("forbidden", "Not the gym owner or an admin");
  return mat;
}

public async verify(callerId: string, role: UserRole, id: string): Promise<OpenMatDetail> {
  await this.assertOwnerOrAdmin(callerId, role, id);
  return (await this.mats.update(id, { verified: true })) as OpenMatDetail;
}

public async setHidden(callerId: string, role: UserRole, id: string, hidden: boolean): Promise<OpenMatDetail> {
  await this.assertOwnerOrAdmin(callerId, role, id);
  return (await this.mats.update(id, { status: hidden ? "hidden" : "live" })) as OpenMatDetail;
}
```

Keep the existing `assertOwner` (used by check-ins route) unchanged.

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/api && bun test test/open-mat.facade.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/open-mat.facade.mts apps/api/test/open-mat.facade.test.mts
git commit -m "feat(api): open-mat facade allows anyone to submit; verify/hide; inline gym"
```

### Task 4: Routes — requireAuth create, verify/hide endpoints, list filters; requireAdmin macro

**Files:**
- Modify: `apps/api/src/auth/auth.middleware.mts`
- Modify: `apps/api/src/routes/open-mat.routes.mts`
- Test: `apps/api/test/open-mat.routes.test.mts` (create; MongoDB-backed, mirror `boot.test.mts` setup)

- [ ] **Step 1: Write the failing test** (new file; reuse the boot.test.mts harness shape — `loadEnv`, `buildApp`, `.listen(0)`, bypass `Authorization` header). `DEMO_USER_ROLE` defaults to `gym_owner`; for a practitioner caller, post to a gym the demo user does NOT own via `newGym`.

```typescript
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_om_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: TEST_DB, AUTH_BYPASS_SECRET: "secret-x", DEMO_USER_ID: "demo", DEMO_USER_ROLE: "gym_owner", DEMO_USER_EMAIL: "d@d.dev" });
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>; let base: string;

beforeAll(async () => { await client.connect(); const c = createContainer(client.db(TEST_DB), env); await c.ensureIndexes(); app = buildApp(c).listen(0); base = `http://localhost:${app.server?.port}`; });
afterAll(async () => { app.stop(); await client.db(TEST_DB).dropDatabase(); await client.close(); });

describe("open-mat routes: community submissions", () => {
  it("authed user creates via newGym -> live + verified(owner-by-demo? no) ", async () => {
    const res = await fetch(`${base}/api/v1/open-mats`, { method: "POST", headers: auth, body: JSON.stringify({ newGym: { name: "Routes Gym", address: "1 A St" }, title: "OM", startTime: "19:00", endTime: "21:00" }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.status).toBe("live");
    // demo user does not own the freshly created ownerless gym -> unverified
    expect(json.data.verified).toBe(false);
    const id = json.data.id;

    // public list includes it
    const listed = await (await fetch(`${base}/api/v1/open-mats`, { headers: auth })).json();
    expect(listed.data.items.some((m: { id: string }) => m.id === id)).toBe(true);

    // verify (demo is gym_owner but not this gym's owner -> 403)
    const vRes = await fetch(`${base}/api/v1/open-mats/${id}/verify`, { method: "POST", headers: auth });
    expect(vRes.status).toBe(403);

    // hide also 403 for non-owner gym_owner
    const hRes = await fetch(`${base}/api/v1/open-mats/${id}/hide`, { method: "POST", headers: auth });
    expect(hRes.status).toBe(403);
  });
});
```

(Admin-path verify/hide is covered by the facade tests in Task 3; route-level admin can be added later with an admin bypass token if desired.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/api && bun test test/open-mat.routes.test.mts`
Expected: FAIL — create returns 403 (still `requireOwner`) / verify+hide endpoints 404.

- [ ] **Step 3: Add `requireAdmin` macro** in `auth.middleware.mts` `.macro({ ... })` block (next to `requireOwner`):

```typescript
      requireAdmin(enabled: boolean) {
        return {
          beforeHandle({ identity }): void {
            if (!enabled) return;
            if (!identity) throw new AppError("unauthorized", "Authentication required");
            if (identity.role !== "admin") throw new AppError("forbidden", "Admin role required");
          },
        };
      },
```

- [ ] **Step 4: Edit `open-mat.routes.mts`**

Change the POST and pass role; add verify/hide; extend list filter:
```typescript
.post(
  "/",
  async ({ identity, body }) => {
    const id = requireId(identity);
    return data(await openMatFacade.create(id.userId, id.role, body));
  },
  { requireAuth: true, body: CreateOpenMatRequest },
)
```
In `GET "/"` handler, extend the filter:
```typescript
const filter: OpenMatFilter = {
  dayOfWeek: query.dayOfWeek,
  giType: query.giType,
  skillLevel: query.skillLevel,
  status: query.status,
  verified: query.verified,
};
if (query.mine) filter.gymOwnerId = requireId(identity).userId;
if (query.submittedByMe) filter.hostId = requireId(identity).userId;
```
Add endpoints (place after the `:id` GET):
```typescript
.post(
  "/:id/verify",
  async ({ identity, params }) => {
    const id = requireId(identity);
    return data(await openMatFacade.verify(id.userId, id.role, params.id));
  },
  { requireAuth: true },
)
.post(
  "/:id/hide",
  async ({ identity, params }) => {
    const id = requireId(identity);
    return data(await openMatFacade.setHidden(id.userId, id.role, params.id, true));
  },
  { requireAuth: true },
)
.post(
  "/:id/unhide",
  async ({ identity, params }) => {
    const id = requireId(identity);
    return data(await openMatFacade.setHidden(id.userId, id.role, params.id, false));
  },
  { requireAuth: true },
)
```
Ensure `AuthIdentity` exposes `role` (it does — `auth.types.mts`). `requireId` already returns the identity.

- [ ] **Step 5: Run to verify it passes**

Run: `cd apps/api && bun test test/open-mat.routes.test.mts`
Expected: PASS.

- [ ] **Step 6: Full API gate**

Run: `cd apps/api && bun run verify` (type-check + lint + test). Expected: all pass. Fix any fallout in `boot.test.mts`/other tests caused by the `create` signature (none expected — routes call the facade).

- [ ] **Step 7: Commit**

```bash
git add apps/api/src/auth/auth.middleware.mts apps/api/src/routes/open-mat.routes.mts apps/api/test/open-mat.routes.test.mts
git commit -m "feat(api): anyone can POST open-mats; verify/hide endpoints; requireAdmin"
```

---

## Phase C — Mobile

### Task 5: Mobile model + request DTOs

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/models/open_mat.dart`
- Modify: `apps/mobile/lib/features/open_mats/data/session_requests.dart`
- Test: `apps/mobile/test/models/open_mat_test.dart` (extend existing)

- [ ] **Step 1: Write the failing test** (append)

```dart
test('parses verified and status with safe defaults', () {
  final m = OpenMat.fromJson({'id': 'x', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '21:00', 'verified': true, 'status': 'hidden'});
  expect(m.verified, isTrue);
  expect(m.status, 'hidden');
  final d = OpenMat.fromJson({'id': 'y', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '21:00'});
  expect(d.verified, isFalse);
  expect(d.status, 'live');
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/mobile && flutter test test/models/open_mat_test.dart`
Expected: FAIL — no `verified`/`status` getters.

- [ ] **Step 3: Implement** — add fields to `OpenMat` (constructor params `this.verified = false`, `this.status = 'live'`; final fields `final bool verified; final String status;`) and in `fromJson`:
```dart
      verified: json['verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'live',
```

- [ ] **Step 4: Extend `session_requests.dart`** — make `gymId` optional and add `newGym`:
```dart
class NewGymInput {
  final String name;
  final String address;
  final String? city;
  final String? state;
  const NewGymInput({required this.name, required this.address, this.city, this.state});
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
      };
}
```
Change `CreateSessionRequest`: make `gymId` `final String?`, add `final NewGymInput? newGym;`, and in `toJson()` replace the `'gymId': gymId` line with:
```dart
        if (gymId != null) 'gymId': gymId,
        if (newGym != null) 'newGym': newGym!.toJson(),
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd apps/mobile && flutter test test/models/open_mat_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/open_mats/models/open_mat.dart apps/mobile/lib/features/open_mats/data/session_requests.dart apps/mobile/test/models/open_mat_test.dart
git commit -m "feat(mobile): OpenMat verified/status; CreateSessionRequest newGym"
```

### Task 6: Session repository — verify/hide/listUnverified; create supports newGym; all-gyms search

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/data/session_repository.dart`
- Modify: `apps/mobile/lib/features/gyms/data/gym_repository.dart`

- [ ] **Step 1: Add methods to `SessionRepository` interface + `ApiSessionRepository`:**
```dart
  Future<List<OpenMat>> listUnverified();
  Future<void> verify(String id);
  Future<void> hide(String id);
```
Implementations:
```dart
  @override
  Future<List<OpenMat>> listUnverified() async {
    try {
      final res = await _dio.get('/api/v1/open-mats', queryParameters: {'verified': false});
      return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
    } on DioException catch (e) { throw ApiException.fromDio(e); }
  }

  @override
  Future<void> verify(String id) async {
    try { await _dio.post('/api/v1/open-mats/$id/verify'); } on DioException catch (e) { throw ApiException.fromDio(e); }
  }

  @override
  Future<void> hide(String id) async {
    try { await _dio.post('/api/v1/open-mats/$id/hide'); } on DioException catch (e) { throw ApiException.fromDio(e); }
  }
```
`create` already POSTs `req.toJson()`, which now includes `newGym` when set — no change needed.

- [ ] **Step 2: Add an all-gyms search provider in `gym_repository.dart`** — add a method to the repo:
```dart
  Future<List<Gym>> searchAll(String query) async {
    try {
      final res = await _dio.get('/api/v1/gyms', queryParameters: {if (query.isNotEmpty) 'q': query, 'limit': 50});
      return unwrapList(res.data as Map<String, dynamic>).items.map(Gym.fromJson).toList();
    } on DioException catch (e) { throw ApiException.fromDio(e); }
  }
```
(If the repo already exposes a list method, reuse it; the API `GET /gyms` ignores unknown `q` safely. Client-side filter by name as a fallback.) Add a provider:
```dart
final allGymsProvider = FutureProvider<List<Gym>>((ref) => ref.read(gymRepositoryProvider).searchAll(''));
```

- [ ] **Step 3: Verify it compiles**

Run: `cd apps/mobile && flutter analyze lib/features/open_mats/data/session_repository.dart lib/features/gyms/data/gym_repository.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/lib/features/open_mats/data/session_repository.dart apps/mobile/lib/features/gyms/data/gym_repository.dart
git commit -m "feat(mobile): session repo verify/hide/listUnverified; all-gyms search"
```

### Task 7: Create screen works for everyone — all-gyms search + inline new gym

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/create_session_screen.dart`
- Test: `apps/mobile/test/features/create_session_gym_test.dart` (NEW, widget test)

- [ ] **Step 1: Write the failing widget test** — pump the screen with an overridden `allGymsProvider` returning a couple of gyms, and an `addNewGym` toggle revealing name/address fields.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/admin/screens/create_session_screen.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows gym search and an add-new-gym affordance', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allGymsProvider.overrideWith((ref) async => const [
              Gym(id: 'g1', name: 'Atos HQ', address: '1 A St'),
            ]),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const CreateSessionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Atos HQ'), findsWidgets);
    expect(find.textContaining('Add'), findsWidgets); // "Add a gym" affordance
  });
}
```

(Adjust `Gym(...)` to the actual constructor in `features/gyms/models/gym.dart`.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/mobile && flutter test test/features/create_session_gym_test.dart`
Expected: FAIL — screen still depends on `myGymsProvider`.

- [ ] **Step 3: Implement** — in `create_session_screen.dart`:
  - Replace `ref.watch(myGymsProvider)` with `ref.watch(allGymsProvider)`.
  - Add state: `bool _addingNewGym = false; final _gymNameCtrl = TextEditingController(); final _gymAddrCtrl = TextEditingController(); final _gymCityCtrl = TextEditingController(); final _gymStateCtrl = TextEditingController();` (dispose them).
  - In `_buildPostingAs`, when gyms load, render a searchable picker (a tappable field that opens `_pickGym` showing ALL gyms, already implemented for >1 gym — just always enable it) plus a trailing "Can't find it? Add a gym" button that sets `_addingNewGym = true`. When `_addingNewGym`, show name/address/city/state `TextField`s instead of the picker.
  - In `_submit`, build the request:
```dart
final req = _addingNewGym
    ? CreateSessionRequest(
        newGym: NewGymInput(name: _gymNameCtrl.text.trim(), address: _gymAddrCtrl.text.trim(), city: _gymCityCtrl.text.trim(), state: _gymStateCtrl.text.trim()),
        title: _title(), startTime: _hhmm(_startTime), endTime: _hhmm(_endTime),
        isRecurring: _isRecurring, dayOfWeek: _isRecurring ? _selectedDate.weekday % 7 : null,
        specificDate: _isRecurring ? null : _selectedDate.toIso8601String().split('T').first,
        giType: _giType, skillLevel: _expToSkill[_expLevel] ?? 'all', feeCents: fee,
        maxParticipants: int.tryParse(_capCtrl.text.trim()), description: _notesCtrl.text.trim())
    : CreateSessionRequest(
        gymId: _gymId!, title: _title(), startTime: _hhmm(_startTime), endTime: _hhmm(_endTime),
        isRecurring: _isRecurring, dayOfWeek: _isRecurring ? _selectedDate.weekday % 7 : null,
        specificDate: _isRecurring ? null : _selectedDate.toIso8601String().split('T').first,
        giType: _giType, skillLevel: _expToSkill[_expLevel] ?? 'all', feeCents: fee,
        maxParticipants: int.tryParse(_capCtrl.text.trim()), description: _notesCtrl.text.trim());
await ref.read(sessionRepositoryProvider).create(req);
```
  - Submit enabled when `(_addingNewGym && nameNotEmpty && addrNotEmpty) || (!_addingNewGym && _gymId != null)`.
  - Update `_SuccessOverlay` subtitle to: `'It's live now, marked unverified until the gym or an admin confirms it.'`
  - Update header copy/empty-state: remove "Add a gym first" gating (everyone can now add inline).

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/mobile && flutter test test/features/create_session_gym_test.dart`
Expected: PASS. Then `flutter analyze lib/features/admin/screens/create_session_screen.dart` → clean.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/admin/screens/create_session_screen.dart apps/mobile/test/features/create_session_gym_test.dart
git commit -m "feat(mobile): create session for everyone with gym search + inline new gym"
```

### Task 8: First-class "+" CTA in the bottom nav + top-level route

**Files:**
- Modify: `apps/mobile/lib/app/router.dart`
- Modify: `apps/mobile/lib/shared/widgets/app_bottom_nav.dart`
- Modify: `apps/mobile/lib/shared/widgets/om_widgets.dart` (OMBottomNav)

- [ ] **Step 1: Add a top-level route** in `router.dart` (sibling of `/settings`, outside the `/owner` subtree so any role reaches it):
```dart
GoRoute(
  path: '/add-session',
  builder: (context, state) => const CreateSessionScreen(),
),
```
Add the import for `CreateSessionScreen`. Confirm the redirect logic allows it for authenticated non-owners (it does — `/add-session` is not under `/owner` and not in `authRoutes`).

- [ ] **Step 2: Add a center "+" to `AppBottomNav`** (practitioner). The current nav maps `_pracTabs = ['home','search','schedule','profile']`. Insert a raised circular "+" button between item 2 and 3 that calls `onAdd`. Add an `onAdd` callback param; in `_ScaffoldWithNavBar` pass `onAdd: () => context.push('/add-session')`. (Use `context.push` so the create screen returns to the current tab on close.)

Minimal structure for the center button row in `AppBottomNav.build`:
```dart
// between the 2nd and 3rd tab, insert:
GestureDetector(
  onTap: onAdd,
  child: Container(
    width: 52, height: 52,
    decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
    child: const Icon(Icons.add, color: Colors.white, size: 28),
  ),
),
```
(Keep the four existing tab items; the "+" is a 5th, non-index action.)

- [ ] **Step 3: Mirror the same center "+" in `OMBottomNav`** (owner shell) with `onAdd: () => context.push('/add-session')` wired from `_ScaffoldWithNavBar`.

- [ ] **Step 4: Verify**

Run: `cd apps/mobile && flutter analyze lib/app/router.dart lib/shared/widgets/app_bottom_nav.dart lib/shared/widgets/om_widgets.dart`
Expected: clean. Then build/install/launch on the emulator and confirm the "+" appears and opens the create screen (see Task 11 verification flow).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/app/router.dart apps/mobile/lib/shared/widgets/app_bottom_nav.dart apps/mobile/lib/shared/widgets/om_widgets.dart
git commit -m "feat(mobile): first-class center + CTA to add an open mat from any tab"
```

### Task 9: "Unverified" badge on session rows

**Files:**
- Modify: `apps/mobile/lib/shared/widgets/session_row.dart`
- Modify: `apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart`
- Test: `apps/mobile/test/features/unverified_badge_test.dart` (NEW)

- [ ] **Step 1: Add `bool unverified` to `SessionRowData`** (default `false`) and render a small amber "Unverified" pill in both `_GlassCard` and `_SportRow` when `unverified == true`. Where session rows are built from `OpenMat`, pass `unverified: !openMat.verified`.

- [ ] **Step 2: Write a widget test** that pumps a `SessionRow(session: SessionRowData(..., unverified: true))` and asserts `find.text('Unverified')` is present; and absent when `unverified: false`.

```dart
testWidgets('shows Unverified pill only when unverified', (tester) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.glass(),
    home: const Scaffold(body: SessionRow(session: SessionRowData(
      gymName: 'X', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1 mi', fee: 0, unverified: true)))));
  await tester.pump();
  expect(find.text('Unverified'), findsOneWidget);
});
```

- [ ] **Step 3: Run → fail → implement → pass**

Run: `cd apps/mobile && flutter test test/features/unverified_badge_test.dart`
Expected: FAIL then PASS after adding the field + pill.

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/lib/shared/widgets/session_row.dart apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart apps/mobile/test/features/unverified_badge_test.dart
git commit -m "feat(mobile): badge unverified (community-added) sessions"
```

### Task 10: Owner verify/hide + admin review screen

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/session_mgmt_screen.dart`
- Create: `apps/mobile/lib/features/admin/screens/admin_review_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (route `/admin/review`)
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart` (admin-only entry)

- [ ] **Step 1: Owner Sessions actions** — in `session_mgmt_screen.dart` `ListTile`, add a trailing popup menu (or two icon buttons) with **Verify** (if `!s.verified`) and **Hide**:
```dart
trailing: PopupMenuButton<String>(
  onSelected: (v) async {
    final repo = ref.read(sessionRepositoryProvider);
    if (v == 'verify') { await repo.verify(s.id); } else if (v == 'hide') { await repo.hide(s.id); }
    ref.invalidate(mySessionsProvider);
  },
  itemBuilder: (_) => [
    if (!s.verified) const PopupMenuItem(value: 'verify', child: Text('Verify')),
    const PopupMenuItem(value: 'hide', child: Text('Hide')),
  ],
),
```
Show an "Unverified" tag in the subtitle when `!s.verified`.

- [ ] **Step 2: Create `admin_review_screen.dart`** — a `ConsumerWidget` watching a provider `adminUnverifiedProvider = FutureProvider((ref) => ref.read(sessionRepositoryProvider).listUnverified())`, rendering each with Verify/Hide actions (same as above) and invalidating on action. Mirror `SessionMgmtScreen` structure (AppBar "Review submissions", ShimmerList/ErrorState/EmptyState).

- [ ] **Step 3: Add route** in `router.dart`:
```dart
GoRoute(path: '/admin/review', builder: (context, state) => const AdminReviewScreen()),
```
Guard in the redirect: if `loc == '/admin/review'` and the user's role is not `admin`, return `'/'`.

- [ ] **Step 4: Admin entry** — in `profile_screen.dart`, when `auth.user?.role == 'admin'`, show a "Review submissions" row → `context.go('/admin/review')`.

- [ ] **Step 5: Verify**

Run: `cd apps/mobile && flutter analyze lib/features/admin/screens/session_mgmt_screen.dart lib/features/admin/screens/admin_review_screen.dart lib/app/router.dart lib/features/profile/screens/profile_screen.dart`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/admin apps/mobile/lib/app/router.dart apps/mobile/lib/features/profile/screens/profile_screen.dart
git commit -m "feat(mobile): owner verify/hide actions + admin review screen"
```

### Task 11: End-to-end — anyone adds a session; it appears live + unverified

**Files:**
- Create: `apps/mobile/integration_test/community_submission_test.dart`
- Modify: `package.json` (root) — add `mobile:e2e:submit` script.

- [ ] **Step 1: Write the E2E** (mirror `create_open_mat_session_test.dart`; uses the dev-bypass + running API). Use a **practitioner** dev-bypass identity to prove non-owners can add: this requires the API running with `DEMO_USER_ROLE=practitioner`. Steps: login → tap the center "+" → (use the auto-selected first gym OR toggle "Add a gym" and fill name/address) → Post Session → expect "Session posted!" → navigate to a list that shows it.

```dart
// after login (pumpUntilFound 'Find your roll'):
await tester.tap(find.byIcon(Icons.add));            // center + CTA
expect(await pumpUntilFound(tester, find.text('Post Session')), isTrue);
expect(await pumpUntilFound(tester, find.text('Atos HQ')), isTrue); // a gym loaded
await tester.tap(find.text('Post Session'));
expect(await pumpUntilFound(tester, find.text('Session posted!')), isTrue);
```

- [ ] **Step 2: Add script** to root `package.json`:
```json
"mobile:e2e:submit": "cd apps/mobile && flutter test integration_test/community_submission_test.dart -d emulator-5554 --dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret --dart-define=API_BASE_URL=http://10.0.2.2:3100",
```

- [ ] **Step 3: Run on the emulator** (API + Mongo up; for the non-owner proof, restart the API with `DEMO_USER_ROLE=practitioner`).

Run: `bun run mobile:e2e:submit`
Expected: `All tests passed!`

- [ ] **Step 4: Visual check** — build the normal debug APK (`flutter build apk --debug --dart-define=...`), `adb install -r`, launch, screenshot: confirm the center "+" CTA, the create form's gym search + "Add a gym", and an "Unverified" badge on the new session.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/integration_test/community_submission_test.dart package.json
git commit -m "test(mobile): e2e anyone can add an open mat (live + unverified)"
```

---

## Self-review notes

- Spec coverage: contract flags+role+newGym (Task 1); repo filters/ownerless (Task 2); open create+verify/hide+inline gym (Task 3); routes+requireAdmin (Task 4); mobile model/DTO (Task 5); repo methods+gym search (Task 6); create-for-everyone (Task 7); first-class CTA+route (Task 8); unverified badge (Task 9); owner verify/hide + admin review (Task 10); E2E (Task 11). All spec sections mapped.
- The existing `open-mat.facade.test.mts` calls `create(owner, req)` with two args; Task 3 Step 1 updates them to the three-arg form — do this or the suite won't compile.
- `AuthIdentity.role` is required by routes' verify/hide and create; it already exists in `auth/auth.types.mts`.
- Gym `searchAll` relies on `GET /api/v1/gyms` returning a list envelope; if it lacks a `q` param, filter client-side by name (noted in Task 6).
