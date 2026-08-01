# Admin Portal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an internal Admin Portal (Angular 22 app at `apps/admin`) over the BJJ Open Mat data set, backed by a new unauthenticated `/api/v1/admin/*` Elysia router that reuses existing facades and adds KPI aggregations.

**Architecture:** A thin `AdminFacade` + `AdminAnalyticsRepository` sit behind a new `admin.routes.mts` module (no auth in Phase I). They reuse `gymFacade`, `userFacade`, `openMatFacade`, `membershipFacade`, `email.service`, and add a net-new `UserRepository.list` plus Mongo aggregations for signup and open-mat-by-state KPIs. The Angular app consumes these via signal-based data services and Nebular components.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (backend); Angular 22 (signals, standalone) + Nebular (frontend); Playwright (e2e); `bun test` (backend unit tests).

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-08-01-admin-portal-design.md`.
- **Phase I: NO authentication** on the admin app or the `/api/v1/admin/*` router. Do NOT modify existing role-guarded routes.
- TypeScript strict mode everywhere. **No `any`** — use explicit types/interfaces/`unknown`.
- Validation with **TypeBox** (never Zod). Schema-first: define schema, derive type with `Static`.
- Backend files use `.mts`; import specifiers use `.mjs`.
- All functions have explicit return types and access modifiers.
- Backend logging via Winston (no `console.*`). Angular may use `console.*`.
- Health endpoints (if referenced) are `/health` and `/ready` — never `/healthz`.
- Conventional commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`). **Never** add Co-Authored-By lines.
- UI library: **Nebular only** (no Angular Material). Prefer SCSS. Standalone components only.
- Contract package is `@bjj/contract`; add new schemas there and export via the barrels.
- API default port: **3100**. Existing DI container in `apps/api/src/container.mts`; app assembly in `apps/api/src/app.mts`; unit tests live in `apps/api/test/*.test.mts` using `bun:test` + a real Mongo (`MONGODB_URI`, default `mongodb://localhost:27017`), each test file using its own `db(...)` name and `dropDatabase()` in `afterAll`.
- Windows dev host: do not use `mkdir -p`.

---

## File Structure

**Backend (`apps/api`, `packages/contract`):**
- `packages/contract/src/schemas/admin-stats.mts` — Create: `AdminOverviewStats`, `StateOpenMatCount`, `AdminOpenMatsByState` schemas.
- `packages/contract/src/schemas/requests/admin-requests.mts` — Create: `AddGymOwnerRequest`, `GymMemberInviteRequest`.
- `packages/contract/src/schemas/gym.mts` — Modify: add optional `verifiedAt`.
- `packages/contract/src/schemas/index.mts` + `.../requests/*` barrel — Modify: export new files.
- `apps/api/src/repositories/user.repository.mts` — Modify: add `list(skip, limit)`.
- `apps/api/src/repositories/admin-analytics.repository.mts` — Create: signup-window + top-states aggregations.
- `apps/api/src/services/email.service.mts` — Modify: add `sendGymMemberInvite` to interface + both impls.
- `apps/api/src/facades/admin.facade.mts` — Create: orchestration.
- `apps/api/src/routes/admin.routes.mts` — Create: `/api/v1/admin/*` router.
- `apps/api/src/container.mts` — Modify: wire `adminAnalyticsRepo` + `adminFacade`.
- `apps/api/src/app.mts` — Modify: register `adminRoutes(container)`.
- `apps/api/test/*.test.mts` — Create: unit/route tests per task.

**Frontend (`apps/admin`, new):**
- `apps/admin/` — Angular 22 app: `src/app/core/` (models, api services), `src/app/features/{dashboard,users,gyms,open-mats,members,schedules}/`, `src/environments/`, routing, Nebular theme.
- `apps/admin/e2e/` + `apps/admin/playwright.config.ts` — Playwright specs.
- `apps/admin/e2e/seed/` — e2e seed script + fixtures.

---

## Phase A — Backend contract schemas

### Task 1: Admin contract schemas + gym `verifiedAt`

**Files:**
- Create: `packages/contract/src/schemas/admin-stats.mts`
- Create: `packages/contract/src/schemas/requests/admin-requests.mts`
- Modify: `packages/contract/src/schemas/gym.mts` (add `verifiedAt`)
- Modify: `packages/contract/src/schemas/index.mts` (export `admin-stats.mjs`)
- Modify: `packages/contract/src/schemas/requests/index.mts` (export `admin-requests.mjs`) — if no requests barrel exists, export directly from `schemas/index.mts`.
- Test: `packages/contract/test/admin-schemas.test.mts`

**Interfaces:**
- Produces: `AdminOverviewStats`, `StateOpenMatCount`, `AdminOpenMatsByState`, `AddGymOwnerRequest`, `GymMemberInviteRequest` (TypeBox schemas + `Static` types). Gym gains optional `verifiedAt: string`.

- [ ] **Step 1: Write the failing test**

```typescript
// packages/contract/test/admin-schemas.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  AdminOverviewStats,
  AdminOpenMatsByState,
  AddGymOwnerRequest,
  GymMemberInviteRequest,
  Gym,
} from "../src/index.mts";

describe("admin contract schemas", () => {
  it("AdminOverviewStats accepts all six signup windows + totals", () => {
    const v = {
      signups: { today: 1, last3Days: 2, last7Days: 3, last14Days: 4, monthToDate: 5, yearToDate: 6 },
      totalUsers: 10, totalGyms: 4, totalOpenMats: 7,
    };
    expect(Value.Check(AdminOverviewStats, v)).toBe(true);
  });

  it("AdminOpenMatsByState holds total + a top-states array", () => {
    const v = { totalOpenMats: 12, topStates: [{ state: "TX", count: 5 }, { state: "CA", count: 3 }] };
    expect(Value.Check(AdminOpenMatsByState, v)).toBe(true);
  });

  it("AddGymOwnerRequest requires a userId", () => {
    expect(Value.Check(AddGymOwnerRequest, { userId: "u-1" })).toBe(true);
    expect(Value.Check(AddGymOwnerRequest, {})).toBe(false);
  });

  it("GymMemberInviteRequest requires at least one email", () => {
    expect(Value.Check(GymMemberInviteRequest, { emails: ["a@b.dev"] })).toBe(true);
    expect(Value.Check(GymMemberInviteRequest, { emails: [] })).toBe(false);
  });

  it("Gym allows optional verifiedAt", () => {
    const base = { id: "g1", name: "G", address: "A", amenities: [], isVerified: true, verifiedAt: "2026-08-01T00:00:00.000Z" };
    expect(Value.Check(Gym, base)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/admin-schemas.test.mts`
Expected: FAIL — modules/exports not found.

- [ ] **Step 3: Create the schemas**

```typescript
// packages/contract/src/schemas/admin-stats.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const SignupWindows = t.Object(
  {
    today: t.Integer({ minimum: 0 }),
    last3Days: t.Integer({ minimum: 0 }),
    last7Days: t.Integer({ minimum: 0 }),
    last14Days: t.Integer({ minimum: 0 }),
    monthToDate: t.Integer({ minimum: 0 }),
    yearToDate: t.Integer({ minimum: 0 }),
  },
  { $id: "SignupWindows" },
);
export type SignupWindows = Static<typeof SignupWindows>;

export const AdminOverviewStats = t.Object(
  {
    signups: SignupWindows,
    totalUsers: t.Integer({ minimum: 0 }),
    totalGyms: t.Integer({ minimum: 0 }),
    totalOpenMats: t.Integer({ minimum: 0 }),
  },
  { $id: "AdminOverviewStats" },
);
export type AdminOverviewStats = Static<typeof AdminOverviewStats>;

export const StateOpenMatCount = t.Object(
  { state: t.String(), count: t.Integer({ minimum: 0 }) },
  { $id: "StateOpenMatCount" },
);
export type StateOpenMatCount = Static<typeof StateOpenMatCount>;

export const AdminOpenMatsByState = t.Object(
  {
    totalOpenMats: t.Integer({ minimum: 0 }),
    topStates: t.Array(StateOpenMatCount),
  },
  { $id: "AdminOpenMatsByState" },
);
export type AdminOpenMatsByState = Static<typeof AdminOpenMatsByState>;
```

```typescript
// packages/contract/src/schemas/requests/admin-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const AddGymOwnerRequest = t.Object(
  { userId: t.String({ minLength: 1 }) },
  { $id: "AddGymOwnerRequest" },
);
export type AddGymOwnerRequest = Static<typeof AddGymOwnerRequest>;

export const GymMemberInviteRequest = t.Object(
  { emails: t.Array(t.String({ format: "email" }), { minItems: 1 }) },
  { $id: "GymMemberInviteRequest" },
);
export type GymMemberInviteRequest = Static<typeof GymMemberInviteRequest>;
```

- [ ] **Step 4: Add `verifiedAt` to Gym and wire barrels**

In `packages/contract/src/schemas/gym.mts`, add after `isVerified`:

```typescript
    isVerified: t.Boolean({ default: false }),
    verifiedAt: t.Optional(t.String()),
```

In `packages/contract/src/schemas/index.mts` add:

```typescript
export * from "./admin-stats.mjs";
```

In the requests barrel (`packages/contract/src/schemas/requests/index.mts`, or wherever `UpdateMembershipRequest` is exported from — mirror that file) add:

```typescript
export * from "./admin-requests.mjs";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/contract && bun test test/admin-schemas.test.mts`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/contract/src/schemas/admin-stats.mts packages/contract/src/schemas/requests/admin-requests.mts packages/contract/src/schemas/gym.mts packages/contract/src/schemas/index.mts packages/contract/src/schemas/requests/index.mts packages/contract/test/admin-schemas.test.mts
git commit -m "feat(contract): add admin stats + request schemas and gym verifiedAt"
```

---

## Phase B — Backend repository, service, facade, routes

### Task 2: `UserRepository.list(skip, limit)`

**Files:**
- Modify: `apps/api/src/repositories/user.repository.mts`
- Test: `apps/api/test/user-repository-list.test.mts`

**Interfaces:**
- Consumes: `UserRepository` (existing), `COLLECTIONS.users`, `stripId`.
- Produces: `UserRepository.list(skip: number, limit: number): Promise<{ items: User[]; total: number }>` — sorted by `createdAt` desc.

- [ ] **Step 1: Write the failing test**

```typescript
// apps/api/test/user-repository-list.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserRepository } from "../src/repositories/user.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_user_repo_list");

afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("UserRepository.list", () => {
  it("returns paged items and a total count, newest first", async () => {
    const repo = new UserRepository(db);
    await repo.insert({ id: "u-1", email: "a@x.dev", displayName: "A", createdAt: "2026-01-01T00:00:00.000Z" });
    await repo.insert({ id: "u-2", email: "b@x.dev", displayName: "B", createdAt: "2026-02-01T00:00:00.000Z" });
    await repo.insert({ id: "u-3", email: "c@x.dev", displayName: "C", createdAt: "2026-03-01T00:00:00.000Z" });

    const page = await repo.list(0, 2);
    expect(page.total).toBe(3);
    expect(page.items.map((u) => u.id)).toEqual(["u-3", "u-2"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/user-repository-list.test.mts`
Expected: FAIL — `repo.list is not a function`.

- [ ] **Step 3: Implement `list`**

Add to `UserRepository` (mirror the existing `GymRepository.list` shape, sorting by `createdAt` desc):

```typescript
  public async list(skip: number, limit: number): Promise<{ items: UserType[]; total: number }> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    const [docs, total] = await Promise.all([
      col.find({}).sort({ createdAt: -1 }).skip(skip).limit(limit).toArray(),
      col.countDocuments({}),
    ]);
    return { items: docs.map((d) => stripId<UserType>(d)!), total };
  }
```

(Use the same `UserType`/`UserDoc` aliases and `stripId` import already present in the file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/user-repository-list.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/user.repository.mts apps/api/test/user-repository-list.test.mts
git commit -m "feat(api): add UserRepository.list for admin user grid"
```

---

### Task 3: `AdminAnalyticsRepository` (signup windows + top states)

**Files:**
- Create: `apps/api/src/repositories/admin-analytics.repository.mts`
- Test: `apps/api/test/admin-analytics-repository.test.mts`

**Interfaces:**
- Consumes: `BaseRepository`, `COLLECTIONS.users/gyms/openMats`.
- Produces:
  - `AdminAnalyticsRepository.signupWindows(now: Date): Promise<SignupWindows>` — counts `users` by `createdAt` within today/3/7/14 days/month-to-date/year-to-date (all relative to `now`, UTC).
  - `AdminAnalyticsRepository.totals(): Promise<{ totalUsers: number; totalGyms: number; totalOpenMats: number }>`
  - `AdminAnalyticsRepository.topStates(limit: number): Promise<StateOpenMatCount[]>` — aggregate `openMats` → `$lookup` `gyms` on `gymId=_id` → group by `gym.state` → sort count desc → limit.

- [ ] **Step 1: Write the failing test**

```typescript
// apps/api/test/admin-analytics-repository.test.mts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { AdminAnalyticsRepository } from "../src/repositories/admin-analytics.repository.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_admin_analytics");
const NOW = new Date("2026-08-01T12:00:00.000Z");

beforeAll(async () => {
  await db.collection("users").insertMany([
    { _id: "u-today", email: "t@x.dev", displayName: "T", createdAt: "2026-08-01T01:00:00.000Z" },
    { _id: "u-5d", email: "f@x.dev", displayName: "F", createdAt: "2026-07-27T00:00:00.000Z" },
    { _id: "u-old", email: "o@x.dev", displayName: "O", createdAt: "2025-12-01T00:00:00.000Z" },
  ] as never);
  await db.collection("gyms").insertMany([
    { _id: "g-tx", name: "TX Gym", address: "A", state: "TX", amenities: [], isVerified: false },
    { _id: "g-ca", name: "CA Gym", address: "B", state: "CA", amenities: [], isVerified: false },
  ] as never);
  await db.collection("openMats").insertMany([
    { _id: "om-1", gymId: "g-tx", title: "1", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
    { _id: "om-2", gymId: "g-tx", title: "2", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
    { _id: "om-3", gymId: "g-ca", title: "3", startTime: "10:00", endTime: "12:00", skillLevel: "all", giType: "both" },
  ] as never);
});
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("AdminAnalyticsRepository", () => {
  it("counts signups per window relative to now", async () => {
    const repo = new AdminAnalyticsRepository(db);
    const w = await repo.signupWindows(NOW);
    expect(w.today).toBe(1);       // u-today
    expect(w.last7Days).toBe(2);   // u-today + u-5d
    expect(w.last3Days).toBe(1);   // u-today only
    expect(w.yearToDate).toBe(2);  // u-today + u-5d (both in 2026)
  });

  it("returns totals", async () => {
    const repo = new AdminAnalyticsRepository(db);
    expect(await repo.totals()).toEqual({ totalUsers: 3, totalGyms: 2, totalOpenMats: 3 });
  });

  it("returns top states by open-mat count, descending", async () => {
    const repo = new AdminAnalyticsRepository(db);
    const top = await repo.topStates(10);
    expect(top[0]).toEqual({ state: "TX", count: 2 });
    expect(top).toContainEqual({ state: "CA", count: 1 });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/admin-analytics-repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the repository**

```typescript
// apps/api/src/repositories/admin-analytics.repository.mts
import type { Db } from "mongodb";
import type { SignupWindows, StateOpenMatCount } from "@bjj/contract";
import { BaseRepository } from "./base.repository.mjs";
import { COLLECTIONS } from "../db/collections.mjs";

interface UserCreatedDoc {
  readonly createdAt?: string;
}

export class AdminAnalyticsRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  private startOfUtcDay(now: Date): Date {
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  }

  private daysAgo(now: Date, days: number): Date {
    return new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  }

  public async signupWindows(now: Date): Promise<SignupWindows> {
    const col = this.collection<UserCreatedDoc>(COLLECTIONS.users);
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
    const yearStart = new Date(Date.UTC(now.getUTCFullYear(), 0, 1)).toISOString();
    const since = async (iso: string): Promise<number> =>
      col.countDocuments({ createdAt: { $gte: iso } });
    const [today, last3Days, last7Days, last14Days, monthToDate, yearToDate] = await Promise.all([
      since(this.startOfUtcDay(now).toISOString()),
      since(this.daysAgo(now, 3).toISOString()),
      since(this.daysAgo(now, 7).toISOString()),
      since(this.daysAgo(now, 14).toISOString()),
      since(monthStart),
      since(yearStart),
    ]);
    return { today, last3Days, last7Days, last14Days, monthToDate, yearToDate };
  }

  public async totals(): Promise<{ totalUsers: number; totalGyms: number; totalOpenMats: number }> {
    const [totalUsers, totalGyms, totalOpenMats] = await Promise.all([
      this.collection(COLLECTIONS.users).countDocuments({}),
      this.collection(COLLECTIONS.gyms).countDocuments({}),
      this.collection(COLLECTIONS.openMats).countDocuments({}),
    ]);
    return { totalUsers, totalGyms, totalOpenMats };
  }

  public async topStates(limit: number): Promise<StateOpenMatCount[]> {
    const rows = await this.collection(COLLECTIONS.openMats)
      .aggregate<{ _id: string; count: number }>([
        { $lookup: { from: COLLECTIONS.gyms, localField: "gymId", foreignField: "_id", as: "gym" } },
        { $unwind: "$gym" },
        { $match: { "gym.state": { $type: "string", $ne: "" } } },
        { $group: { _id: "$gym.state", count: { $sum: 1 } } },
        { $sort: { count: -1, _id: 1 } },
        { $limit: limit },
      ])
      .toArray();
    return rows.map((r) => ({ state: r._id, count: r.count }));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/admin-analytics-repository.test.mts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/admin-analytics.repository.mts apps/api/test/admin-analytics-repository.test.mts
git commit -m "feat(api): add AdminAnalyticsRepository for signup and open-mat KPIs"
```

---

### Task 4: `EmailService.sendGymMemberInvite`

**Files:**
- Modify: `apps/api/src/services/email.service.mts`
- Test: `apps/api/test/email-invite.test.mts`

**Interfaces:**
- Produces: `EmailService.sendGymMemberInvite(to: string, gymName: string, joinCode?: string): Promise<void>` on the interface, `SesEmailService`, and `UnconfiguredEmailService`.

- [ ] **Step 1: Write the failing test**

```typescript
// apps/api/test/email-invite.test.mts
import { describe, expect, it } from "bun:test";
import { UnconfiguredEmailService } from "../src/services/email.service.mts";

describe("sendGymMemberInvite", () => {
  it("UnconfiguredEmailService no-ops without throwing", async () => {
    const svc = new UnconfiguredEmailService();
    await expect(svc.sendGymMemberInvite("a@b.dev", "Gracie HQ", "JOIN123")).resolves.toBeUndefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/email-invite.test.mts`
Expected: FAIL — `sendGymMemberInvite is not a function`.

- [ ] **Step 3: Implement on interface + both classes**

Add to the `EmailService` interface:

```typescript
  sendGymMemberInvite(to: string, gymName: string, joinCode?: string): Promise<void>;
```

Add to `SesEmailService` (reuse the private `send(to, subject, text)`):

```typescript
  public async sendGymMemberInvite(to: string, gymName: string, joinCode?: string): Promise<void> {
    const codeLine = joinCode ? `\nUse join code: ${joinCode}` : "";
    await this.send(
      to,
      `[BJJ Open Mat] You're invited to join ${gymName}`,
      `You've been invited to join ${gymName} on BJJ Open Mat.${codeLine}\n\nOpen the app to accept.`,
    );
  }
```

Add to `UnconfiguredEmailService` (match the existing no-op style — Winston debug log, no `console.*`):

```typescript
  public async sendGymMemberInvite(to: string, gymName: string, joinCode?: string): Promise<void> {
    logger.debug("email disabled — skipping gym member invite", { to, gymName, joinCode });
  }
```

(Import `logger` if the file references it the same way as the other no-op methods; otherwise mirror their exact body.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/email-invite.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/services/email.service.mts apps/api/test/email-invite.test.mts
git commit -m "feat(api): add sendGymMemberInvite to EmailService"
```

---

### Task 5: `AdminFacade`

**Files:**
- Create: `apps/api/src/facades/admin.facade.mts`
- Test: `apps/api/test/admin-facade.test.mts`

**Interfaces:**
- Consumes: `AdminAnalyticsRepository` (Task 3), `UserRepository.list` (Task 2), `GymFacade` (`getById`, `update`, `create`, `list`), `OpenMatFacade` (`list`, `update`), `MembershipFacade` (`updateMembership`), `UserRepository.update`, `EmailService.sendGymMemberInvite` (Task 4).
- Produces:
  - `overview(now: Date): Promise<AdminOverviewStats>`
  - `openMatsByState(limit: number): Promise<AdminOpenMatsByState>`
  - `listUsers(skip: number, limit: number): Promise<{ items: User[]; total: number }>`
  - `verifyGym(gymId: string, now: Date): Promise<Gym>` — sets `isVerified: true`, `verifiedAt: now.toISOString()`.
  - `addOwner(gymId: string, userId: string): Promise<Gym>` — sets `gym.ownerId` and promotes the user's `role` to `gym_owner`.
  - `invite(gymId: string, emails: string[]): Promise<{ invited: number }>` — sends one invite per email via `EmailService`, returns count.

- [ ] **Step 1: Write the failing test** (uses fakes for collaborators — pure orchestration)

```typescript
// apps/api/test/admin-facade.test.mts
import { describe, expect, it } from "bun:test";
import { AdminFacade } from "../src/facades/admin.facade.mts";

const NOW = new Date("2026-08-01T00:00:00.000Z");

function makeFacade(overrides: Partial<Record<string, unknown>> = {}) {
  const gymStore: Record<string, unknown> = { "g-1": { id: "g-1", name: "G", address: "A", amenities: [], isVerified: false } };
  const userRoles: Record<string, string> = {};
  const sent: string[] = [];
  const analytics = {
    signupWindows: async () => ({ today: 1, last3Days: 1, last7Days: 1, last14Days: 1, monthToDate: 1, yearToDate: 1 }),
    totals: async () => ({ totalUsers: 3, totalGyms: 1, totalOpenMats: 2 }),
    topStates: async () => [{ state: "TX", count: 2 }],
  };
  const userRepo = {
    list: async () => ({ items: [{ id: "u-1", email: "a@b.dev", displayName: "A" }], total: 1 }),
    update: async (id: string, patch: Record<string, unknown>) => { userRoles[id] = patch["role"] as string; return { id, ...patch }; },
  };
  const gymFacade = {
    getById: async (id: string) => gymStore[id],
    update: async (_owner: string, id: string, patch: Record<string, unknown>) => { gymStore[id] = { ...(gymStore[id] as object), ...patch }; return gymStore[id]; },
  };
  const email = { sendGymMemberInvite: async (to: string) => { sent.push(to); } };
  const facade = new AdminFacade(analytics as never, userRepo as never, gymFacade as never, {} as never, {} as never, email as never);
  return { facade, gymStore, userRoles, sent };
}

describe("AdminFacade", () => {
  it("overview merges signup windows + totals", async () => {
    const { facade } = makeFacade();
    const o = await facade.overview(NOW);
    expect(o.totalUsers).toBe(3);
    expect(o.signups.today).toBe(1);
  });

  it("verifyGym sets isVerified + verifiedAt", async () => {
    const { facade, gymStore } = makeFacade();
    await facade.verifyGym("g-1", NOW);
    expect((gymStore["g-1"] as Record<string, unknown>)["isVerified"]).toBe(true);
    expect((gymStore["g-1"] as Record<string, unknown>)["verifiedAt"]).toBe(NOW.toISOString());
  });

  it("addOwner sets ownerId and promotes user role", async () => {
    const { facade, gymStore, userRoles } = makeFacade();
    await facade.addOwner("g-1", "u-9");
    expect((gymStore["g-1"] as Record<string, unknown>)["ownerId"]).toBe("u-9");
    expect(userRoles["u-9"]).toBe("gym_owner");
  });

  it("invite sends one email per address", async () => {
    const { facade, sent } = makeFacade();
    const r = await facade.invite("g-1", ["x@y.dev", "z@y.dev"]);
    expect(r.invited).toBe(2);
    expect(sent).toEqual(["x@y.dev", "z@y.dev"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/admin-facade.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the facade**

```typescript
// apps/api/src/facades/admin.facade.mts
import type {
  AdminOverviewStats,
  AdminOpenMatsByState,
  Gym,
  User,
} from "@bjj/contract";
import type { AdminAnalyticsRepository } from "../repositories/admin-analytics.repository.mjs";
import type { UserRepository } from "../repositories/user.repository.mjs";
import type { GymFacade } from "./gym.facade.mjs";
import type { OpenMatFacade } from "./open-mat.facade.mjs";
import type { EmailService } from "../services/email.service.mjs";

const ADMIN_ACTOR = "admin";

export class AdminFacade {

  public constructor(
    private readonly analytics: AdminAnalyticsRepository,
    private readonly users: UserRepository,
    private readonly gyms: GymFacade,
    private readonly openMats: OpenMatFacade,
    private readonly memberships: unknown,
    private readonly email: EmailService,
  ) {}

  public async overview(now: Date): Promise<AdminOverviewStats> {
    const [signups, totals] = await Promise.all([
      this.analytics.signupWindows(now),
      this.analytics.totals(),
    ]);
    return { signups, ...totals };
  }

  public async openMatsByState(limit: number): Promise<AdminOpenMatsByState> {
    const [topStates, totals] = await Promise.all([
      this.analytics.topStates(limit),
      this.analytics.totals(),
    ]);
    return { totalOpenMats: totals.totalOpenMats, topStates };
  }

  public async listUsers(skip: number, limit: number): Promise<{ items: User[]; total: number }> {
    return this.users.list(skip, limit);
  }

  public async verifyGym(gymId: string, now: Date): Promise<Gym> {
    return this.gyms.update(ADMIN_ACTOR, gymId, { isVerified: true, verifiedAt: now.toISOString() });
  }

  public async addOwner(gymId: string, userId: string): Promise<Gym> {
    const gym = await this.gyms.update(ADMIN_ACTOR, gymId, { ownerId: userId });
    await this.users.update(userId, { role: "gym_owner" });
    return gym;
  }

  public async invite(gymId: string, emails: string[]): Promise<{ invited: number }> {
    const gym = await this.gyms.getById(gymId);
    for (const to of emails) {
      await this.email.sendGymMemberInvite(to, gym.name, gym.joinCode);
    }
    return { invited: emails.length };
  }
}
```

> Note: `GymFacade.update`'s first arg is `ownerId` used for authorization in the owner flow; for the admin path we pass the sentinel `"admin"`. If `GymFacade.update` enforces owner-match and rejects the sentinel, add a `gymFacade.adminUpdate(id, patch)` that skips the owner check and call it here instead. Verify against `apps/api/src/facades/gym.facade.mts:57` before implementing; prefer adding `adminUpdate` if `update` asserts ownership. Update the `Produces` note and this task's code accordingly.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/admin-facade.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/admin.facade.mts apps/api/test/admin-facade.test.mts
git commit -m "feat(api): add AdminFacade orchestration"
```

---

### Task 6: `admin.routes.mts` + DI wiring + registration

**Files:**
- Create: `apps/api/src/routes/admin.routes.mts`
- Modify: `apps/api/src/container.mts` (add `adminAnalyticsRepo`, `adminFacade` to type + `createContainer`)
- Modify: `apps/api/src/app.mts` (import + `.use(adminRoutes(container))`)
- Test: `apps/api/test/admin-routes.test.mts`

**Interfaces:**
- Consumes: `AdminFacade`, `GymFacade`, `OpenMatFacade`, `MembershipFacade` from the container; `data`/`list` envelope helpers.
- Produces: unauthenticated router mounted at `/api/v1/admin` with:
  - `GET /stats/overview` → `data(AdminOverviewStats)`
  - `GET /stats/open-mats-by-state?limit=10` → `data(AdminOpenMatsByState)`
  - `GET /users?page&limit` → `list(User[], meta)`
  - `GET /gyms?page&limit` → `list(Gym[], meta)`
  - `GET /open-mats?page&limit` → `list(OpenMat[], meta)`
  - `POST /gyms` (body `CreateGymRequest`) → `data(Gym)`
  - `PUT /gyms/:id` (body `UpdateGymRequest`) → `data(Gym)`
  - `POST /gyms/:id/verify` → `data(Gym)`
  - `POST /gyms/:id/owner` (body `AddGymOwnerRequest`) → `data(Gym)`
  - `POST /gyms/:id/invite` (body `GymMemberInviteRequest`) → `data({ invited })`
  - `PUT /open-mats/:id` (body `UpdateOpenMatRequest`) → `data(OpenMat)`

- [ ] **Step 1: Write the failing test** (route-level, real container against a scratch DB)

```typescript
// apps/api/test/admin-routes.test.mts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";
import { loadEnv } from "../src/config/env.mts";

const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 4000 });
const db = client.db("bjj_test_admin_routes");
let app: ReturnType<typeof buildApp>;

beforeAll(async () => {
  await db.collection("users").insertOne({ _id: "u-1", email: "a@b.dev", displayName: "A", createdAt: "2026-08-01T00:00:00.000Z" } as never);
  await db.collection("gyms").insertOne({ _id: "g-1", name: "G", address: "A", state: "TX", amenities: [], isVerified: false } as never);
  const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: "bjj_test_admin_routes" });
  app = buildApp(createContainer(db, env));
});
afterAll(async () => { await db.dropDatabase(); await client.close(); });

async function get(path: string): Promise<{ status: number; body: unknown }> {
  const res = await app.handle(new Request(`http://localhost${path}`));
  return { status: res.status, body: await res.json() };
}

describe("admin routes", () => {
  it("GET /api/v1/admin/stats/overview returns totals without auth", async () => {
    const { status, body } = await get("/api/v1/admin/stats/overview");
    expect(status).toBe(200);
    expect((body as { data: { totalGyms: number } }).data.totalGyms).toBe(1);
  });

  it("GET /api/v1/admin/users returns a non-empty list", async () => {
    const { status, body } = await get("/api/v1/admin/users?page=1&limit=20");
    expect(status).toBe(200);
    expect((body as { data: unknown[] }).data.length).toBeGreaterThan(0);
  });

  it("GET /api/v1/admin/gyms returns a non-empty list", async () => {
    const { body } = await get("/api/v1/admin/gyms?page=1&limit=20");
    expect((body as { data: unknown[] }).data.length).toBeGreaterThan(0);
  });

  it("POST /api/v1/admin/gyms/:id/verify sets isVerified", async () => {
    const res = await app.handle(new Request("http://localhost/api/v1/admin/gyms/g-1/verify", { method: "POST" }));
    const body = await res.json() as { data: { isVerified: boolean } };
    expect(body.data.isVerified).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/admin-routes.test.mts`
Expected: FAIL — `adminRoutes` not registered / 404.

- [ ] **Step 3: Wire the container**

In `apps/api/src/container.mts`:
- Add import: `import { AdminAnalyticsRepository } from "./repositories/admin-analytics.repository.mjs";` and `import { AdminFacade } from "./facades/admin.facade.mjs";`
- Add to the `Container` interface: `readonly adminFacade: AdminFacade;`
- In `createContainer`, after `membershipFacade` is built, add:

```typescript
  const adminAnalyticsRepo = new AdminAnalyticsRepository(db);
```

- In the returned object add:

```typescript
    adminFacade: new AdminFacade(adminAnalyticsRepo, userRepo, gymFacade, openMatFacade, membershipFacade, emailService),
```

> If Task 5's note required a `gymFacade.adminUpdate`, ensure `gymFacade` is referenced after construction (it is created in the return literal). If ordering is a problem, hoist `const gymFacade = new GymFacade(...)` into a `const` above the return, then reference it in both places.

- [ ] **Step 4: Implement the router**

```typescript
// apps/api/src/routes/admin.routes.mts
import { Elysia } from "elysia";
import {
  CreateGymRequest,
  UpdateGymRequest,
  UpdateOpenMatRequest,
  AddGymOwnerRequest,
  GymMemberInviteRequest,
} from "@bjj/contract";
import type { Container } from "../container.mts";
import { data, list } from "../http/envelope.mts";

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function adminRoutes(container: Container) {
  const { adminFacade, gymFacade, openMatFacade } = container;

  return new Elysia({ prefix: "/api/v1/admin" })
    .get("/stats/overview", async () => data(await adminFacade.overview(new Date())))
    .get("/stats/open-mats-by-state", async ({ query }) =>
      data(await adminFacade.openMatsByState(Number(query.limit ?? 10))),
    )
    .get("/users", async ({ query }) => {
      const page = Number(query.page ?? 1);
      const limit = Number(query.limit ?? 20);
      const { items, total } = await adminFacade.listUsers((page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .get("/gyms", async ({ query }) => {
      const page = Number(query.page ?? 1);
      const limit = Number(query.limit ?? 20);
      const { items, total } = await gymFacade.list({ skip: (page - 1) * limit, limit });
      return list(items, { page, limit, total });
    })
    .get("/open-mats", async ({ query }) => {
      const page = Number(query.page ?? 1);
      const limit = Number(query.limit ?? 20);
      const { items, total } = await openMatFacade.list({}, (page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .post("/gyms", async ({ body }) => data(await gymFacade.create("admin", body)), { body: CreateGymRequest })
    .put("/gyms/:id", async ({ params, body }) => data(await gymFacade.update("admin", params.id, body)), { body: UpdateGymRequest })
    .post("/gyms/:id/verify", async ({ params }) => data(await adminFacade.verifyGym(params.id, new Date())))
    .post("/gyms/:id/owner", async ({ params, body }) => data(await adminFacade.addOwner(params.id, body.userId)), { body: AddGymOwnerRequest })
    .post("/gyms/:id/invite", async ({ params, body }) => data(await adminFacade.invite(params.id, body.emails)), { body: GymMemberInviteRequest })
    .put("/open-mats/:id", async ({ params, body }) => data(await openMatFacade.update("admin", "admin", params.id, body)), { body: UpdateOpenMatRequest });
}
```

> Verify the exact `openMatFacade.update` / `gymFacade.create` / `gymFacade.update` signatures at `apps/api/src/facades/*.mts` before finalizing — they take a caller id (and role for open mats). For Phase-I admin, pass the `"admin"` sentinel and `"admin"` role. If any of those methods assert ownership/role and reject the sentinel, add an `adminUpdate`/`adminCreate` variant on that facade that skips the check (mirroring the note in Task 5) and call it here.

Register in `apps/api/src/app.mts`:
- Add `import { adminRoutes } from "./routes/admin.routes.mjs";`
- Add `.use(adminRoutes(container))` in the chain.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/admin-routes.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 6: Full backend gate**

Run: `cd apps/api && bun test` and `cd packages/contract && bun test`
Expected: all pass. Then `bunx eslint . --fix` in `apps/api` and fix any lint.

- [ ] **Step 7: Commit**

```bash
git add apps/api/src/routes/admin.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/admin-routes.test.mts
git commit -m "feat(api): add unauthenticated /api/v1/admin router and wiring"
```

---

## Phase C — Frontend `apps/admin` (Angular 22 + Nebular)

> Tasks 7–13 are agent-driven UI generation. Use the **angular-scaffold-agent** to scaffold and the **angular-dashboard-styler** (Nebular) to theme. Each task lists exact deliverables so the e2e specs in Phase D can rely on stable selectors and service signatures. After each task, run `cd apps/admin && bunx ng build` and fix errors before committing.

### Task 7: Scaffold `apps/admin` shell + workspace wiring

**Files:**
- Create: `apps/admin/` (Angular 22 app: `package.json`, `angular.json`, `tsconfig*.json`, `src/main.ts`, `src/app/app.config.ts`, `src/app/app.routes.ts`, `src/app/app.ts`, `src/environments/environment.ts`).
- Modify: root `package.json` workspaces if needed so `apps/admin` is recognized (mirror how `website/` is handled — it is a standalone Angular app with its own lockfile, so `apps/admin` should likewise have its own `package.json` and be buildable independently).

**Deliverables (exact):**
- Angular 22, standalone, signals. Nebular installed (`@nebular/theme`, `@nebular/eva-icons`, `eva-icons`).
- `src/environments/environment.ts` exports `export const environment = { apiBaseUrl: 'http://localhost:3100' } as const;`
- Nebular layout shell in `app.ts`: `<nb-layout>` with `<nb-sidebar>` nav (links: Dashboard, Users, Gyms, Open Mats, Members, Schedules) + `<nb-layout-header>` (title "BJJ Admin").
- Routing (`app.routes.ts`) with lazy standalone routes: `/` → dashboard, `/users`, `/gyms`, `/open-mats`, `/members`, `/schedules`. Each initially a placeholder standalone component rendering an `<h1>` with the page name.
- `HttpClient` provided in `app.config.ts` (`provideHttpClient()`).

- [ ] **Step 1: Dispatch angular-scaffold-agent** with the deliverables above (Nebular, port target 4300, API base `http://localhost:3100`, the six routes as placeholders).
- [ ] **Step 2: Verify build** — `cd apps/admin && bun install && bunx ng build`. Expected: build succeeds.
- [ ] **Step 3: Verify serve** — `cd apps/admin && bunx ng serve --port 4300` boots; the shell renders the sidebar with six nav links. Stop the server.
- [ ] **Step 4: Commit**

```bash
git add apps/admin
git commit -m "feat(admin): scaffold Angular 22 + Nebular admin shell"
```

### Task 8: Core models + signal data services

**Files:**
- Create: `apps/admin/src/app/core/models/` (TS interfaces mirroring `@bjj/contract`: `User`, `Gym`, `OpenMat`, `AdminOverviewStats`, `AdminOpenMatsByState`, `ListEnvelope<T>`, `DataEnvelope<T>`).
- Create: `apps/admin/src/app/core/api/admin-api.service.ts` — one injectable `AdminApiService` with signal-returning methods.

**Deliverables (exact method signatures — e2e and pages depend on these):**
```typescript
// AdminApiService (injectable, providedIn: 'root')
getOverview(): Promise<AdminOverviewStats>            // GET /api/v1/admin/stats/overview
getOpenMatsByState(limit = 10): Promise<AdminOpenMatsByState> // GET /api/v1/admin/stats/open-mats-by-state
listUsers(page = 1, limit = 50): Promise<ListEnvelope<User>>  // GET /api/v1/admin/users
listGyms(page = 1, limit = 50): Promise<ListEnvelope<Gym>>    // GET /api/v1/admin/gyms
listOpenMats(page = 1, limit = 50): Promise<ListEnvelope<OpenMat>>
verifyGym(id: string): Promise<Gym>                  // POST /api/v1/admin/gyms/:id/verify
createGym(body: CreateGymBody): Promise<Gym>         // POST /api/v1/admin/gyms
updateGym(id: string, body: Partial<Gym>): Promise<Gym> // PUT /api/v1/admin/gyms/:id
addOwner(id: string, userId: string): Promise<Gym>   // POST /api/v1/admin/gyms/:id/owner
invite(id: string, emails: string[]): Promise<{ invited: number }> // POST /api/v1/admin/gyms/:id/invite
updateOpenMat(id: string, body: Partial<OpenMat>): Promise<OpenMat>
```
- All read via `HttpClient` against `environment.apiBaseUrl`. Unwrap the `{ data, meta }` envelope.

- [ ] **Step 1: Dispatch angular-ui (or angular-scaffold-agent)** to create the models + `AdminApiService` with the exact signatures above.
- [ ] **Step 2: Verify build** — `cd apps/admin && bunx ng build`. Expected: success, no `any`.
- [ ] **Step 3: Commit**

```bash
git add apps/admin/src/app/core
git commit -m "feat(admin): core models and AdminApiService"
```

### Task 9: Dashboard page (KPI cards + top-10 states)

**Files:**
- Modify: `apps/admin/src/app/features/dashboard/dashboard.ts` + template/styles.

**Deliverables:**
- On init, load `getOverview()` and `getOpenMatsByState(10)` into signals.
- Render six Nebular KPI cards: Today, 3 Days, 7 Days, 14 Days, Month to Date, Year to Date (from `signups`), plus Total Users / Total Gyms / Total Open Mats.
- Render a Nebular table of top-10 states (`state`, `count`). Add `data-testid="top-states-table"`.

- [ ] **Step 1: Dispatch angular-ui** with the deliverables.
- [ ] **Step 2: Verify build + serve** — cards and table render (against a running API + seeded DB, or with the e2e seed from Task 14).
- [ ] **Step 3: Commit** — `git commit -m "feat(admin): dashboard KPI cards and top-states table"`.

### Task 10: Users grid page

**Files:**
- Modify: `apps/admin/src/app/features/users/users.ts` + template/styles.

**Deliverables:**
- On init, `listUsers()` → signal. Render a Nebular table with columns: Display Name, Email, Role, City/State, Created At.
- The table root has `data-testid="users-grid"` and each row has `data-testid="user-row"`.
- Empty state renders a `data-testid="users-empty"` element when there are zero rows.

- [ ] **Step 1: Dispatch angular-ui.**
- [ ] **Step 2: Verify** grid renders rows against seeded API.
- [ ] **Step 3: Commit** — `git commit -m "feat(admin): users grid"`.

### Task 11: Gyms grid + actions

**Files:**
- Modify: `apps/admin/src/app/features/gyms/gyms.ts` + template/styles; add dialog components for Create/Edit/Add-Owner/Invite.

**Deliverables:**
- `listGyms()` → signal. Nebular table columns: Name, City/State, Verified (badge), Owner. Root `data-testid="gyms-grid"`, rows `data-testid="gym-row"`.
- Row actions: **Verify** (calls `verifyGym`, optimistic badge flip), **Edit** (dialog → `updateGym`), **Add Owner** (dialog with userId → `addOwner`), **Send Invite** (dialog with emails → `invite`).
- Toolbar **Create Gym** button → dialog → `createGym`.

- [ ] **Step 1: Dispatch angular-ui.**
- [ ] **Step 2: Verify** grid + verify action work against seeded API.
- [ ] **Step 3: Commit** — `git commit -m "feat(admin): gyms grid with verify/create/edit/owner/invite"`.

### Task 12: Open Mats + Members + Schedules pages

**Files:**
- Modify: `apps/admin/src/app/features/{open-mats,members,schedules}/*`.

**Deliverables:**
- **Open Mats**: `listOpenMats()` grid (`data-testid="open-mats-grid"`) + Edit dialog → `updateOpenMat`.
- **Members**: reuse membership listing (via a gym roster call if per-gym; otherwise a flat list) — grid `data-testid="members-grid"` + edit (verifiedMember / gymRole).
- **Schedules**: per-gym class schedule editor (list + edit). Minimal for Phase I.

> If a flat members/schedules list endpoint is missing, either scope Members to a gym-selected roster using the existing membership facade, or add `GET /api/v1/admin/memberships` in the same style as Task 6 (reuse `membershipFacade`). Decide during implementation and keep it in the admin router.

- [ ] **Step 1: Dispatch angular-ui.**
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Commit** — `git commit -m "feat(admin): open-mats, members, schedules pages"`.

### Task 13: Nebular theming pass

**Files:**
- Modify: theme registration + SCSS tokens in `apps/admin/src/`.

**Deliverables:**
- Dispatch **angular-dashboard-styler** (Nebular) to apply a consistent color scheme/theme across the shell, cards, and grids. No structural/behavioral changes.

- [ ] **Step 1: Dispatch angular-dashboard-styler (Nebular).**
- [ ] **Step 2: Verify build + serve** — visual consistency; all `data-testid`s intact.
- [ ] **Step 3: Commit** — `git commit -m "style(admin): apply Nebular theme"`.

---

## Phase D — E2E

### Task 14: E2E seed database + fixtures

**Files:**
- Create: `apps/admin/e2e/seed/fixtures.ts` — known users + gyms (+ a couple open mats with `gymId` → state).
- Create: `apps/admin/e2e/seed/seed.ts` — connects to `MONGODB_URI`, drops + inserts fixtures into DB `bjj_admin_e2e`.
- Create: `apps/admin/e2e/seed/reset.ts` — drops `bjj_admin_e2e` (optional cleanup).

**Deliverables (exact):**
- Fixtures include **≥3 users** and **≥3 gyms** (with `state` set, at least two in the same state so top-states is meaningful) and **≥3 open mats**.
- `seed.ts` is runnable via `bun apps/admin/e2e/seed/seed.ts` and inserts documents with `_id` set (matching how repositories store `_id`), `createdAt` ISO strings (at least one user `createdAt` = today so a KPI window is non-zero).

- [ ] **Step 1: Write fixtures + seed script** (real inserts into `users`, `gyms`, `openMats` collections in DB `bjj_admin_e2e`).
- [ ] **Step 2: Run** `bun apps/admin/e2e/seed/seed.ts` against local Mongo. Expected: logs inserted counts (≥3/≥3/≥3).
- [ ] **Step 3: Commit** — `git commit -m "test(admin): e2e seed fixtures and script"`.

### Task 15: Playwright specs — Users & Gyms grids have data (GATE)

**Files:**
- Create: `apps/admin/playwright.config.ts`
- Create: `apps/admin/e2e/grids.spec.ts`

**Deliverables:**
- `playwright.config.ts` starts two web servers: the API against the e2e DB and the admin app.

```typescript
// apps/admin/playwright.config.ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  testMatch: /grids\.spec\.ts/,
  fullyParallel: false,
  webServer: [
    {
      command: "bun apps/admin/e2e/seed/seed.ts && cd ../../apps/api && MONGODB_URI=mongodb://localhost:27017 MONGODB_DB=bjj_admin_e2e bun run src/index.mts",
      url: "http://localhost:3100/health",
      reuseExistingServer: true,
      timeout: 120_000,
    },
    {
      command: "bunx ng serve --port 4300 --configuration development",
      url: "http://localhost:4300",
      reuseExistingServer: true,
      timeout: 180_000,
    },
  ],
  use: { baseURL: "http://localhost:4300" },
});
```

> Adjust the API start command to this repo's actual dev entry (check `apps/api/package.json` scripts — e.g. `bun run dev`). The API must point at `MONGODB_DB=bjj_admin_e2e`. Confirm `/health` is the liveness path (it is, per standards).

- [ ] **Step 1: Write the failing test**

```typescript
// apps/admin/e2e/grids.spec.ts
import { test, expect } from "@playwright/test";

test("users grid has data", async ({ page }) => {
  await page.goto("/users");
  const grid = page.getByTestId("users-grid");
  await expect(grid).toBeVisible();
  await expect(page.getByTestId("user-row")).not.toHaveCount(0);
});

test("gyms grid has data", async ({ page }) => {
  await page.goto("/gyms");
  const grid = page.getByTestId("gyms-grid");
  await expect(grid).toBeVisible();
  await expect(page.getByTestId("gym-row")).not.toHaveCount(0);
});
```

- [ ] **Step 2: Run and verify** — `cd apps/admin && bunx playwright test`. If it fails, debug via systematic-debugging (seed ran? API on 3100 pointing at `bjj_admin_e2e`? testids present? CORS `websiteOrigins` includes `http://localhost:4300` — if not, set the API's allowed origins env for the e2e run).
- [ ] **Step 3: Make it pass** — all e2e green.
- [ ] **Step 4: Commit** — `git commit -m "test(admin): playwright e2e for users and gyms grids"`.

---

## Self-Review (completed against the spec)

- **See all Users** → Task 6 `GET /admin/users` + Task 10 grid. ✅
- **See all Gyms / members / claims / gym info** → Task 6 lists + Tasks 11–12. ✅
- **KPIs signups today/3/7/14/month/YTD** → Tasks 3, 5, 6, 9. ✅
- **Total Open Mats** → Task 3 `totals` + Task 9. ✅
- **Open mats by state top 10** → Task 3 `topStates` + Task 6 + Task 9. ✅
- **Verify gyms** → Task 5 `verifyGym` + Task 6 route + Task 11 action. ✅
- **Update Gyms / Members / Open Mats / schedules** → Task 6 `PUT` routes + Tasks 11–12. ✅
- **Create a Gym** → Task 6 `POST /gyms` + Task 11. ✅
- **Email new members to join a gym** → Task 4 + Task 5 `invite` + Task 6 route + Task 11 dialog. ✅
- **Add a Gym Owner** → Task 5 `addOwner` + Task 6 route + Task 11 dialog. ✅
- **Update data models** → Task 1 (`verifiedAt`, admin schemas) + Task 4 (email method). ✅
- **No auth Phase I** → admin router unauthenticated; existing guarded routes untouched. ✅
- **Reuse existing API calls** → reuse map honored (gym/open-mat/membership/user facades + email service). ✅
- **Angular + signals, latest** → Angular 22, signals, standalone (Tasks 7–13). ✅
- **Angular UI agent for layout/look** → angular-scaffold-agent + angular-ui + angular-dashboard-styler. ✅
- **Playwright e2e that Users and Gyms grids have data; all pass** → Tasks 14–15 (GATE). ✅

**Open verification points flagged inline** (resolve during implementation, not blockers): exact `gymFacade`/`openMatFacade` mutation signatures and whether an `adminUpdate`/`adminCreate` variant is needed to bypass owner/role assertions (Tasks 5–6); actual API dev-start script + CORS origins for the e2e web server (Task 15); whether a flat members/schedules endpoint is added or scoped per-gym (Task 12).
