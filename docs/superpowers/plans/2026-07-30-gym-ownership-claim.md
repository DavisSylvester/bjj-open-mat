# Gym Ownership / Claim Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users claim unowned gyms (or request transfer of owned ones); an admin approves/rejects; approval grants real ownership so owner-gated features become usable.

**Architecture:** TypeBox contracts (`@bjj/contract`) → MongoDB `GymClaimRepository` → `GymClaimFacade` (all authorization + orchestration) → Elysia routes via DI (claimant routes + `requireAdmin` admin routes) → Flutter + Riverpod client (claim form, gym-detail entry point, admin review screen). Mirrors the existing forum/messaging/membership stack exactly.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^6`), Flutter + Riverpod + Dio. Tests: `bun test` (API/contract), `flutter test` (mobile).

**Spec:** `docs/superpowers/specs/2026-07-30-gym-ownership-claim-design.md`

## Global Constraints

- TypeScript strict; **no `any`**; explicit return types + access modifiers; explicit variable types.
- TypeBox only (never Zod). Schema-first, `Static<typeof X>`, **`$id` on every schema/enum**.
- `.mts` source; **import specifiers use `.mjs`** in contract cross-imports (e.g. `../enums/gym-role.mjs`). API/contract test files import from source (`../src/...mts`).
- One concern per file; barrel via `index.mts`; named exports.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `debugPrint`.
- Layering router → facade → repository; DI via `container.mts`, no `new` in routers. Repo deps via `Pick<>`.
- MongoDB: never an empty `$set`; never a field in both `$set` and `$setOnInsert`; `null !== undefined` care on optional fields.
- Health endpoints `/health` and `/ready` only.
- Route param is `:id` at a path position (memoirist). Gym-scoped routes under `/api/v1/gyms/:id/...`; admin under `/api/v1/admin/...`.
- Conventional Commits; **never** add Co-Authored-By. Do NOT commit `packages/contract/src/index.mjs` (gitignored). Commit per task.
- Before each commit: `bunx eslint --fix` on changed `apps/api`/`packages/contract` files; `flutter analyze` clean on changed mobile files.
- **API tests run against local Mongo on 27021:** `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test <file>`. (`test/setup.mts` maps `TEST_MONGODB_URI` → `MONGODB_URI`.)
- **In facade/repo tests, `await` mongodb operations directly — do NOT use `await expect(promise).resolves...`.** Bun's `.resolves` matcher hangs against a client-carrying CSOT (`timeoutMS`), timing out at 4s. Assert with `const r = await ...; expect(r)...`.

---

## File Structure

**Contract (`packages/contract/src/`):**
- `enums/gym-claim-status.mts`, `enums/gym-claim-kind.mts`, `enums/claimant-relationship.mts` — new enums
- `enums/notification-type.mts` — add `'gym_claim'`
- `schemas/gym-claim.mts` — `GymClaim` object schema
- `schemas/requests/gym-claim-requests.mts` — submit/reject/query request schemas
- `enums/index.mts`, `schemas/index.mts`, `schemas/requests/index.mts` — barrels

**API (`apps/api/src/`):**
- `db/collections.mts` — add `gymClaims`
- `repositories/gym-claim.repository.mts` — data access
- `facades/gym-claim.facade.mts` — orchestration
- `routes/gym-claim.routes.mts` — claimant + admin routes
- `container.mts`, `app.mts` — wiring

**Mobile (`apps/mobile/lib/`):**
- `features/gym_claims/models/gym_claim.dart`, `models/admin_gym_claim.dart`
- `features/gym_claims/data/gym_claim_repository.dart` — Dio repo + providers
- `features/gym_claims/screens/claim_gym_screen.dart` — submission form
- `features/gym_claims/screens/admin_gym_claims_screen.dart` — admin review
- `core/api/endpoints.dart` — add endpoints
- `app/router.dart` — routes
- `features/gyms/screens/gym_detail_screen.dart` — entry point
- `features/profile/screens/profile_screen.dart` — admin row

---

## Task 1: Contract enums + notification type

**Files:**
- Create: `packages/contract/src/enums/gym-claim-status.mts`
- Create: `packages/contract/src/enums/gym-claim-kind.mts`
- Create: `packages/contract/src/enums/claimant-relationship.mts`
- Modify: `packages/contract/src/enums/notification-type.mts`
- Modify: `packages/contract/src/enums/index.mts`
- Test: `packages/contract/test/gym-claim-enums.test.mts`

**Interfaces:**
- Produces: `GymClaimStatus` (`'pending'|'approved'|'rejected'|'cancelled'`), `GymClaimKind` (`'claim'|'transfer'`), `ClaimantRelationship` (`'owner'|'head_coach'|'manager'`); `NotificationType` gains `'gym_claim'`.

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/gym-claim-enums.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  GymClaimStatus,
  GymClaimKind,
  ClaimantRelationship,
  NotificationType,
} from "../src/index.mts";

describe("gym claim enums", () => {
  it("accepts valid status values and rejects others", () => {
    expect(Value.Check(GymClaimStatus, "pending")).toBe(true);
    expect(Value.Check(GymClaimStatus, "approved")).toBe(true);
    expect(Value.Check(GymClaimStatus, "rejected")).toBe(true);
    expect(Value.Check(GymClaimStatus, "cancelled")).toBe(true);
    expect(Value.Check(GymClaimStatus, "bogus")).toBe(false);
  });

  it("accepts valid kinds", () => {
    expect(Value.Check(GymClaimKind, "claim")).toBe(true);
    expect(Value.Check(GymClaimKind, "transfer")).toBe(true);
    expect(Value.Check(GymClaimKind, "steal")).toBe(false);
  });

  it("accepts valid relationships", () => {
    expect(Value.Check(ClaimantRelationship, "owner")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "head_coach")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "manager")).toBe(true);
    expect(Value.Check(ClaimantRelationship, "janitor")).toBe(false);
  });

  it("notification type now includes gym_claim", () => {
    expect(Value.Check(NotificationType, "gym_claim")).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/gym-claim-enums.test.mts`
Expected: FAIL — cannot import `GymClaimStatus` etc.

- [ ] **Step 3: Create the enum files**

`packages/contract/src/enums/gym-claim-status.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const GymClaimStatus = t.Union(
  [t.Literal("pending"), t.Literal("approved"), t.Literal("rejected"), t.Literal("cancelled")],
  { $id: "GymClaimStatus" },
);
export type GymClaimStatus = Static<typeof GymClaimStatus>;
```

`packages/contract/src/enums/gym-claim-kind.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const GymClaimKind = t.Union(
  [t.Literal("claim"), t.Literal("transfer")],
  { $id: "GymClaimKind" },
);
export type GymClaimKind = Static<typeof GymClaimKind>;
```

`packages/contract/src/enums/claimant-relationship.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const ClaimantRelationship = t.Union(
  [t.Literal("owner"), t.Literal("head_coach"), t.Literal("manager")],
  { $id: "ClaimantRelationship" },
);
export type ClaimantRelationship = Static<typeof ClaimantRelationship>;
```

- [ ] **Step 4: Add `gym_claim` to notification type**

In `packages/contract/src/enums/notification-type.mts`, add `t.Literal("gym_claim"),` to the union (after `t.Literal("forum_accepted"),`):

```typescript
export const NotificationType = t.Union(
  [
    t.Literal("rsvp"),
    t.Literal("review"),
    t.Literal("session_update"),
    t.Literal("system"),
    t.Literal("forum_answer"),
    t.Literal("forum_accepted"),
    t.Literal("gym_claim"),
  ],
  { $id: "NotificationType" },
);
export type NotificationType = Static<typeof NotificationType>;
```

- [ ] **Step 5: Add the three new enums to the barrel**

In `packages/contract/src/enums/index.mts`, append:

```typescript
export * from "./gym-claim-status.mts";
export * from "./gym-claim-kind.mts";
export * from "./claimant-relationship.mts";
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/contract && bun test test/gym-claim-enums.test.mts`
Expected: PASS (4 tests)

- [ ] **Step 7: Lint + commit**

```bash
cd packages/contract && bunx eslint --fix src/enums/gym-claim-status.mts src/enums/gym-claim-kind.mts src/enums/claimant-relationship.mts src/enums/notification-type.mts src/enums/index.mts test/gym-claim-enums.test.mts
cd ../.. && git add packages/contract/src/enums packages/contract/test/gym-claim-enums.test.mts
git commit -m "feat(contract): gym-claim enums + gym_claim notification type"
```

---

## Task 2: `GymClaim` schema

**Files:**
- Create: `packages/contract/src/schemas/gym-claim.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `packages/contract/test/gym-claim-schema.test.mts`

**Interfaces:**
- Consumes: `GymClaimStatus`, `GymClaimKind`, `ClaimantRelationship` (Task 1).
- Produces: `GymClaim` type = `{ id, gymId, claimantId, kind, relationship, contact, message, status?, previousOwnerId?, createdAt, decidedAt?, decidedBy?, decisionNote? }`.

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/gym-claim-schema.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymClaim } from "../src/index.mts";

describe("GymClaim schema", () => {
  const base = {
    id: "c1",
    gymId: "g1",
    claimantId: "u1",
    kind: "claim",
    relationship: "owner",
    contact: "owner@gym.com",
    message: "I own this gym",
    status: "pending",
    createdAt: "2026-07-30T00:00:00.000Z",
  };

  it("accepts a minimal valid pending claim", () => {
    expect(Value.Check(GymClaim, base)).toBe(true);
  });

  it("accepts an approved claim with decision + previousOwner fields", () => {
    const approved = {
      ...base,
      status: "approved",
      previousOwnerId: "u0",
      decidedAt: "2026-07-31T00:00:00.000Z",
      decidedBy: "admin1",
      decisionNote: "verified by phone",
    };
    expect(Value.Check(GymClaim, approved)).toBe(true);
  });

  it("rejects an invalid relationship", () => {
    expect(Value.Check(GymClaim, { ...base, relationship: "janitor" })).toBe(false);
  });

  it("rejects a missing required field (contact)", () => {
    const { contact, ...withoutContact } = base;
    expect(Value.Check(GymClaim, withoutContact)).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/gym-claim-schema.test.mts`
Expected: FAIL — cannot import `GymClaim`.

- [ ] **Step 3: Create the schema**

`packages/contract/src/schemas/gym-claim.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { GymClaimKind } from "../enums/gym-claim-kind.mjs";
import { GymClaimStatus } from "../enums/gym-claim-status.mjs";
import { ClaimantRelationship } from "../enums/claimant-relationship.mjs";

export const GymClaim = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    claimantId: t.String(),
    kind: GymClaimKind,
    relationship: ClaimantRelationship,
    contact: t.String({ minLength: 1 }),
    message: t.String(),
    status: t.Optional(t.Union([GymClaimStatus], { default: "pending" })),
    previousOwnerId: t.Optional(t.String()),
    createdAt: t.String(),
    decidedAt: t.Optional(t.String()),
    decidedBy: t.Optional(t.String()),
    decisionNote: t.Optional(t.String()),
  },
  { $id: "GymClaim" },
);
export type GymClaim = Static<typeof GymClaim>;
```

- [ ] **Step 4: Add to the schema barrel**

In `packages/contract/src/schemas/index.mts`, add (near the other schema exports, before the `requests`/`responses` exports):

```typescript
export * from "./gym-claim.mts";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/contract && bun test test/gym-claim-schema.test.mts`
Expected: PASS (4 tests)

- [ ] **Step 6: Lint + commit**

```bash
cd packages/contract && bunx eslint --fix src/schemas/gym-claim.mts src/schemas/index.mts test/gym-claim-schema.test.mts
cd ../.. && git add packages/contract/src/schemas/gym-claim.mts packages/contract/src/schemas/index.mts packages/contract/test/gym-claim-schema.test.mts
git commit -m "feat(contract): GymClaim schema"
```

---

## Task 3: Request schemas

**Files:**
- Create: `packages/contract/src/schemas/requests/gym-claim-requests.mts`
- Modify: `packages/contract/src/schemas/requests/index.mts`
- Test: `packages/contract/test/gym-claim-requests.test.mts`

**Interfaces:**
- Produces: `SubmitGymClaimRequest` = `{ relationship, contact, message }`; `RejectGymClaimRequest` = `{ note? }`; `AdminGymClaimsQuery` = `{ status? }`.

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/gym-claim-requests.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import {
  SubmitGymClaimRequest,
  RejectGymClaimRequest,
  AdminGymClaimsQuery,
} from "../src/index.mts";

describe("gym claim request schemas", () => {
  it("SubmitGymClaimRequest requires relationship, contact, message", () => {
    expect(
      Value.Check(SubmitGymClaimRequest, {
        relationship: "owner",
        contact: "me@gym.com",
        message: "hi",
      }),
    ).toBe(true);
    expect(Value.Check(SubmitGymClaimRequest, { relationship: "owner" })).toBe(false);
    expect(
      Value.Check(SubmitGymClaimRequest, { relationship: "owner", contact: "", message: "x" }),
    ).toBe(false);
  });

  it("RejectGymClaimRequest allows an optional note", () => {
    expect(Value.Check(RejectGymClaimRequest, {})).toBe(true);
    expect(Value.Check(RejectGymClaimRequest, { note: "not verified" })).toBe(true);
  });

  it("AdminGymClaimsQuery allows an optional status", () => {
    expect(Value.Check(AdminGymClaimsQuery, {})).toBe(true);
    expect(Value.Check(AdminGymClaimsQuery, { status: "pending" })).toBe(true);
    expect(Value.Check(AdminGymClaimsQuery, { status: "bogus" })).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/gym-claim-requests.test.mts`
Expected: FAIL — cannot import the request schemas.

- [ ] **Step 3: Create the request schemas**

`packages/contract/src/schemas/requests/gym-claim-requests.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { ClaimantRelationship } from "../../enums/claimant-relationship.mts";
import { GymClaimStatus } from "../../enums/gym-claim-status.mts";

export const SubmitGymClaimRequest = t.Object(
  {
    relationship: ClaimantRelationship,
    contact: t.String({ minLength: 1 }),
    message: t.String({ minLength: 1 }),
  },
  { $id: "SubmitGymClaimRequest" },
);
export type SubmitGymClaimRequest = Static<typeof SubmitGymClaimRequest>;

export const RejectGymClaimRequest = t.Object(
  {
    note: t.Optional(t.String()),
  },
  { $id: "RejectGymClaimRequest" },
);
export type RejectGymClaimRequest = Static<typeof RejectGymClaimRequest>;

export const AdminGymClaimsQuery = t.Object(
  {
    status: t.Optional(GymClaimStatus),
  },
  { $id: "AdminGymClaimsQuery" },
);
export type AdminGymClaimsQuery = Static<typeof AdminGymClaimsQuery>;
```

- [ ] **Step 4: Add to the requests barrel**

In `packages/contract/src/schemas/requests/index.mts`, append:

```typescript
export * from "./gym-claim-requests.mts";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/contract && bun test test/gym-claim-requests.test.mts`
Expected: PASS (3 tests)

- [ ] **Step 6: Lint + commit**

```bash
cd packages/contract && bunx eslint --fix src/schemas/requests/gym-claim-requests.mts src/schemas/requests/index.mts test/gym-claim-requests.test.mts
cd ../.. && git add packages/contract/src/schemas/requests/gym-claim-requests.mts packages/contract/src/schemas/requests/index.mts packages/contract/test/gym-claim-requests.test.mts
git commit -m "feat(contract): gym-claim request schemas"
```

---

## Task 4: `GymClaimRepository` + collection

**Files:**
- Modify: `apps/api/src/db/collections.mts` (add `gymClaims`)
- Create: `apps/api/src/repositories/gym-claim.repository.mts`
- Test: `apps/api/test/gym-claim.repository.test.mts`

**Interfaces:**
- Consumes: `GymClaim`, `GymClaimStatus` (Tasks 1-2); `BaseRepository`, `stripId`, `COLLECTIONS`.
- Produces: `GymClaimRepository` with:
  - `ensureIndexes(): Promise<void>`
  - `insert(c: GymClaim): Promise<GymClaim>`
  - `findById(id: string): Promise<GymClaim | null>`
  - `findPendingByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null>`
  - `findLatestByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null>`
  - `listByStatus(status: GymClaimStatus): Promise<GymClaim[]>`
  - `listByClaimant(claimantId: string): Promise<GymClaim[]>`
  - `listPendingByGym(gymId: string): Promise<GymClaim[]>`
  - `updateStatus(id: string, patch: Partial<GymClaim>): Promise<GymClaim | null>`

- [ ] **Step 1: Add the collection name**

In `apps/api/src/db/collections.mts`, add inside the `COLLECTIONS` object (after `messageReports: "messageReports",`):

```typescript
  gymClaims: "gymClaims",
```

- [ ] **Step 2: Write the failing test**

Create `apps/api/test/gym-claim.repository.test.mts`:

```typescript
import { afterAll, beforeEach, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import type { GymClaim } from "@bjj/contract";
import { GymClaimRepository } from "../src/repositories/gym-claim.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27021", { timeoutMS: 4000 });
const db = client.db("bjj_test_gym_claims");
const repo = new GymClaimRepository(db);

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

beforeEach(async () => {
  await db.collection("gymClaims").deleteMany({});
});

function claim(over: Partial<GymClaim> = {}): GymClaim {
  return {
    id: "c1",
    gymId: "g1",
    claimantId: "u1",
    kind: "claim",
    relationship: "owner",
    contact: "u1@gym.com",
    message: "mine",
    status: "pending",
    createdAt: "2026-07-30T00:00:00.000Z",
    ...over,
  };
}

describe("GymClaimRepository", () => {
  it("inserts and finds by id", async () => {
    await repo.insert(claim());
    const found = await repo.findById("c1");
    expect(found?.gymId).toBe("g1");
    expect((found as { _id?: unknown })._id).toBeUndefined();
  });

  it("finds a pending claim by gym + claimant, ignoring decided ones", async () => {
    await repo.insert(claim({ id: "c1", status: "rejected" }));
    expect(await repo.findPendingByGymAndClaimant("g1", "u1")).toBeNull();
    await repo.insert(claim({ id: "c2", status: "pending" }));
    const pending = await repo.findPendingByGymAndClaimant("g1", "u1");
    expect(pending?.id).toBe("c2");
  });

  it("returns the most recent claim for gym + claimant", async () => {
    await repo.insert(claim({ id: "c1", status: "rejected", createdAt: "2026-07-01T00:00:00.000Z" }));
    await repo.insert(claim({ id: "c2", status: "pending", createdAt: "2026-07-30T00:00:00.000Z" }));
    const latest = await repo.findLatestByGymAndClaimant("g1", "u1");
    expect(latest?.id).toBe("c2");
  });

  it("lists by status and by claimant and pending-by-gym", async () => {
    await repo.insert(claim({ id: "c1", status: "pending" }));
    await repo.insert(claim({ id: "c2", claimantId: "u2", contact: "u2@gym.com", status: "pending" }));
    await repo.insert(claim({ id: "c3", status: "approved" }));
    expect((await repo.listByStatus("pending")).map((c) => c.id).sort()).toEqual(["c1", "c2"]);
    expect((await repo.listByClaimant("u1")).map((c) => c.id).sort()).toEqual(["c1", "c3"]);
    expect((await repo.listPendingByGym("g1")).map((c) => c.id).sort()).toEqual(["c1", "c2"]);
  });

  it("updates status fields", async () => {
    await repo.insert(claim());
    const updated = await repo.updateStatus("c1", { status: "approved", decidedBy: "admin1" });
    expect(updated?.status).toBe("approved");
    expect(updated?.decidedBy).toBe("admin1");
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim.repository.test.mts`
Expected: FAIL — cannot import `GymClaimRepository`.

- [ ] **Step 4: Implement the repository**

`apps/api/src/repositories/gym-claim.repository.mts`:

```typescript
import type { Db } from "mongodb";
import type { GymClaim, GymClaimStatus } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface GymClaimDoc extends GymClaim {
  _id: string;
}

export class GymClaimRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<GymClaimDoc>(COLLECTIONS.gymClaims);
    await col.createIndex({ gymId: 1, claimantId: 1 });
    await col.createIndex({ status: 1, createdAt: 1 });
    await col.createIndex({ claimantId: 1 });
  }

  public async insert(c: GymClaim): Promise<GymClaim> {
    await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<GymClaim | null> {
    return stripId<GymClaim>(await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).findOne({ _id: id }));
  }

  public async findPendingByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null> {
    return stripId<GymClaim>(
      await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).findOne({ gymId, claimantId, status: "pending" }),
    );
  }

  public async findLatestByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ gymId, claimantId })
      .sort({ createdAt: -1 })
      .limit(1)
      .toArray();
    return docs.length > 0 ? (stripId<GymClaim>(docs[0]) as GymClaim) : null;
  }

  public async listByStatus(status: GymClaimStatus): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ status })
      .sort({ createdAt: 1 })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async listByClaimant(claimantId: string): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ claimantId })
      .sort({ createdAt: -1 })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async listPendingByGym(gymId: string): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ gymId, status: "pending" })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async updateStatus(id: string, patch: Partial<GymClaim>): Promise<GymClaim | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim.repository.test.mts`
Expected: PASS (5 tests)

- [ ] **Step 6: Lint + commit**

```bash
cd apps/api && bunx eslint --fix src/db/collections.mts src/repositories/gym-claim.repository.mts test/gym-claim.repository.test.mts
cd ../.. && git add apps/api/src/db/collections.mts apps/api/src/repositories/gym-claim.repository.mts apps/api/test/gym-claim.repository.test.mts
git commit -m "feat(api): GymClaimRepository + gymClaims collection"
```

---

## Task 5: `GymClaimFacade` — submit, my-claims, cancel, reject

**Files:**
- Create: `apps/api/src/facades/gym-claim.facade.mts`
- Test: `apps/api/test/gym-claim-facade.test.mts`

**Interfaces:**
- Consumes: `GymClaimRepository` (Task 4); `GymRepository` (`findById`, `update`), `UserRepository` (`findById`, `update`), `MembershipRepository` (`find`, `update`, `upsertJoin`), `NotificationRepository` (`insert`); `AppError`.
- Produces: `GymClaimFacade` with `submit`, `listMyClaims`, `getMyClaimForGym`, `cancel`, `reject` (approve added in Task 6). Constructor:
  ```typescript
  new GymClaimFacade(gymClaims, gyms, users, memberships, notifications, newId)
  ```
  where each dep is a `Pick<>` slice and `newId: () => string`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/gym-claim-facade.test.mts` (this file grows in Task 6; start with submit/cancel/reject):

```typescript
import { describe, expect, it } from "bun:test";
import type {
  Gym,
  GymClaim,
  GymMembership,
  Notification,
  User,
} from "@bjj/contract";
import { AppError } from "../src/http/errors.mts";
import { GymClaimFacade } from "../src/facades/gym-claim.facade.mts";

// ── In-memory fakes ─────────────────────────────────────────────────────────
function makeFakes(seedGym: Partial<Gym> = {}) {
  const claims = new Map<string, GymClaim>();
  const gyms = new Map<string, Gym>();
  const users = new Map<string, User>();
  const memberships = new Map<string, GymMembership>();
  const notifications: Notification[] = [];
  gyms.set("g1", { id: "g1", name: "Alliance", address: "1 Main St", amenities: [], isVerified: false, ...seedGym });

  const mkey = (gymId: string, userId: string): string => `${gymId}::${userId}`;
  let seq = 0;
  const newId = (): string => `id-${++seq}`;

  const gymClaimsRepo = {
    insert: async (c: GymClaim): Promise<GymClaim> => { claims.set(c.id, c); return c; },
    findById: async (id: string): Promise<GymClaim | null> => claims.get(id) ?? null,
    findPendingByGymAndClaimant: async (gymId: string, claimantId: string): Promise<GymClaim | null> =>
      [...claims.values()].find((c) => c.gymId === gymId && c.claimantId === claimantId && c.status === "pending") ?? null,
    findLatestByGymAndClaimant: async (gymId: string, claimantId: string): Promise<GymClaim | null> =>
      [...claims.values()]
        .filter((c) => c.gymId === gymId && c.claimantId === claimantId)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0] ?? null,
    listByStatus: async (status: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.status === status),
    listByClaimant: async (claimantId: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.claimantId === claimantId),
    listPendingByGym: async (gymId: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.gymId === gymId && c.status === "pending"),
    updateStatus: async (id: string, patch: Partial<GymClaim>): Promise<GymClaim | null> => {
      const cur = claims.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      claims.set(id, next);
      return next;
    },
  };
  const gymsRepo = {
    findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null,
    update: async (id: string, patch: Partial<Gym>): Promise<Gym | null> => {
      const cur = gyms.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      gyms.set(id, next);
      return next;
    },
  };
  const usersRepo = {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id) ?? ({ id } as User);
      const next = { ...cur, ...patch };
      users.set(id, next);
      return next;
    },
  };
  const membershipsRepo = {
    find: async (gymId: string, userId: string): Promise<GymMembership | null> => memberships.get(mkey(gymId, userId)) ?? null,
    update: async (gymId: string, userId: string, patch: Partial<GymMembership>): Promise<GymMembership | null> => {
      const cur = memberships.get(mkey(gymId, userId));
      if (!cur) return null;
      const next = { ...cur, ...patch };
      memberships.set(mkey(gymId, userId), next);
      return next;
    },
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      const existing = memberships.get(mkey(m.gymId, m.userId));
      if (existing) return existing;
      memberships.set(mkey(m.gymId, m.userId), m);
      return m;
    },
  };
  const notificationsRepo = {
    insert: async (n: Notification): Promise<Notification> => { notifications.push(n); return n; },
  };

  const facade = new GymClaimFacade(gymClaimsRepo, gymsRepo, usersRepo, membershipsRepo, notificationsRepo, newId);
  return { facade, claims, gyms, users, memberships, notifications };
}

describe("GymClaimFacade — submit / cancel / reject", () => {
  it("submits a claim for an unowned gym with kind 'claim'", async () => {
    const { facade, claims } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    expect(c.kind).toBe("claim");
    expect(c.status).toBe("pending");
    expect(claims.size).toBe(1);
  });

  it("submits a transfer for an owned gym and notifies the current owner", async () => {
    const { facade, notifications } = makeFakes({ ownerId: "owner9" });
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine now" });
    expect(c.kind).toBe("transfer");
    expect(notifications).toHaveLength(1);
    expect(notifications[0]?.userId).toBe("owner9");
    expect(notifications[0]?.type).toBe("gym_claim");
  });

  it("rejects a duplicate pending claim", async () => {
    const { facade } = makeFakes();
    await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    let threw = false;
    try {
      await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "again" });
    } catch (e) {
      threw = e instanceof AppError && e.code === "conflict";
    }
    expect(threw).toBe(true);
  });

  it("rejects claiming a gym you already own", async () => {
    const { facade } = makeFakes({ ownerId: "u1" });
    let threw = false;
    try {
      await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    } catch (e) {
      threw = e instanceof AppError && e.code === "conflict";
    }
    expect(threw).toBe(true);
  });

  it("404s submitting for a missing gym", async () => {
    const { facade } = makeFakes();
    let code = "";
    try {
      await facade.submit("u1", "missing", { relationship: "owner", contact: "x", message: "y" });
    } catch (e) {
      if (e instanceof AppError) code = e.code;
    }
    expect(code).toBe("not_found");
  });

  it("cancels a pending claim", async () => {
    const { facade, claims } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.cancel("u1", "g1");
    expect(claims.get(c.id)?.status).toBe("cancelled");
  });

  it("rejects a claim with a note and notifies the claimant", async () => {
    const { facade, notifications } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.reject("admin1", c.id, "could not verify");
    expect(notifications.some((n) => n.userId === "u1" && n.type === "gym_claim")).toBe(true);
  });

  it("getMyClaimForGym returns the latest claim", async () => {
    const { facade } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    const got = await facade.getMyClaimForGym("u1", "g1");
    expect(got?.id).toBe(c.id);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts`
Expected: FAIL — cannot import `GymClaimFacade`.

- [ ] **Step 3: Implement the facade (submit/list/cancel/reject; `approve` stub added in Task 6)**

`apps/api/src/facades/gym-claim.facade.mts`:

```typescript
import type {
  Gym,
  GymClaim,
  GymClaimStatus,
  Notification,
  SubmitGymClaimRequest,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { GymClaimRepository } from "../repositories/gym-claim.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { NotificationRepository } from "../repositories/notification.repository.mts";

type IdFactory = () => string;

type ClaimRepo = Pick<
  GymClaimRepository,
  | "insert"
  | "findById"
  | "findPendingByGymAndClaimant"
  | "findLatestByGymAndClaimant"
  | "listByStatus"
  | "listByClaimant"
  | "listPendingByGym"
  | "updateStatus"
>;
type GymRepo = Pick<GymRepository, "findById" | "update">;
type UserRepo = Pick<UserRepository, "findById" | "update">;
type MemberRepo = Pick<MembershipRepository, "find" | "update" | "upsertJoin">;
type NotifRepo = Pick<NotificationRepository, "insert">;

export class GymClaimFacade {

  public constructor(
    private readonly claims: ClaimRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly memberships: MemberRepo,
    private readonly notifications: NotifRepo,
    private readonly newId: IdFactory,
  ) {}

  private async notify(
    userId: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const n: Notification = {
      id: this.newId(),
      userId,
      type: "gym_claim",
      title,
      body,
      read: false,
      data,
      createdAt: new Date().toISOString(),
    };
    await this.notifications.insert(n);
  }

  private async getClaimOr404(id: string): Promise<GymClaim> {
    const c = await this.claims.findById(id);
    if (!c) throw new AppError("not_found", `Claim ${id} not found`);
    return c;
  }

  public async submit(callerId: string, gymId: string, req: SubmitGymClaimRequest): Promise<GymClaim> {
    const gym: Gym | null = await this.gyms.findById(gymId);
    if (!gym) throw new AppError("not_found", `Gym ${gymId} not found`);
    if (gym.ownerId === callerId) throw new AppError("conflict", "You already own this gym");
    const dupe = await this.claims.findPendingByGymAndClaimant(gymId, callerId);
    if (dupe) throw new AppError("conflict", "You already have a pending claim for this gym");

    const kind = gym.ownerId ? "transfer" : "claim";
    const claim: GymClaim = {
      id: this.newId(),
      gymId,
      claimantId: callerId,
      kind,
      relationship: req.relationship,
      contact: req.contact,
      message: req.message,
      status: "pending",
      createdAt: new Date().toISOString(),
    };
    const saved = await this.claims.insert(claim);
    if (kind === "transfer" && gym.ownerId) {
      await this.notify(
        gym.ownerId,
        "Ownership requested",
        `Someone requested ownership of ${gym.name}`,
        { gymId, claimId: saved.id, kind: "transfer" },
      );
    }
    return saved;
  }

  public async listMyClaims(callerId: string): Promise<GymClaim[]> {
    return this.claims.listByClaimant(callerId);
  }

  public async getMyClaimForGym(callerId: string, gymId: string): Promise<GymClaim | null> {
    return this.claims.findLatestByGymAndClaimant(gymId, callerId);
  }

  public async cancel(callerId: string, gymId: string): Promise<void> {
    const pending = await this.claims.findPendingByGymAndClaimant(gymId, callerId);
    if (!pending) throw new AppError("not_found", "No pending claim to withdraw");
    await this.claims.updateStatus(pending.id, { status: "cancelled", decidedAt: new Date().toISOString() });
  }

  public async reject(adminId: string, claimId: string, note: string | undefined): Promise<GymClaim> {
    const claim = await this.getClaimOr404(claimId);
    if (claim.status !== "pending") throw new AppError("conflict", "Claim is not pending");
    const patch: Partial<GymClaim> = {
      status: "rejected",
      decidedAt: new Date().toISOString(),
      decidedBy: adminId,
    };
    if (note !== undefined) patch.decisionNote = note;
    const updated = (await this.claims.updateStatus(claimId, patch)) as GymClaim;
    await this.notify(
      claim.claimantId,
      "Claim not approved",
      note && note.length > 0
        ? `Your claim was not approved: ${note}`
        : "Your gym claim was not approved",
      { gymId: claim.gymId, claimId, outcome: "rejected" },
    );
    return updated;
  }

  public async listForAdmin(status: GymClaimStatus): Promise<GymClaim[]> {
    return this.claims.listByStatus(status);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts`
Expected: PASS (8 tests)

- [ ] **Step 5: Lint + commit**

```bash
cd apps/api && bunx eslint --fix src/facades/gym-claim.facade.mts test/gym-claim-facade.test.mts
cd ../.. && git add apps/api/src/facades/gym-claim.facade.mts apps/api/test/gym-claim-facade.test.mts
git commit -m "feat(api): GymClaimFacade submit/cancel/reject/list"
```

---

## Task 6: `GymClaimFacade.approve` — ownership grant + transfer + supersede

**Files:**
- Modify: `apps/api/src/facades/gym-claim.facade.mts` (add `approve`)
- Modify: `apps/api/test/gym-claim-facade.test.mts` (add approve tests)

**Interfaces:**
- Produces: `approve(adminId: string, claimId: string): Promise<GymClaim>` — sets `gym.ownerId`, elevates claimant `role → gym_owner`, upserts claimant `owner` membership, downgrades a transfer's previous owner, supersedes other pending claims, notifies all parties.

- [ ] **Step 1: Add the failing approve tests**

Append inside `apps/api/test/gym-claim-facade.test.mts` (a new `describe` block after the existing one):

```typescript
describe("GymClaimFacade — approve", () => {
  it("grants ownership on a claim: sets ownerId, elevates role, owner membership", async () => {
    const { facade, gyms, users } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(gyms.get("g1")?.ownerId).toBe("u1");
    expect(users.get("u1")?.role).toBe("gym_owner");
  });

  it("creates an owner membership for the claimant", async () => {
    const { facade, memberships } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(memberships.get("g1::u1")?.gymRole).toBe("owner");
    expect(memberships.get("g1::u1")?.verifiedMember).toBe(true);
  });

  it("does not downgrade an admin claimant's account role", async () => {
    const { facade, users } = makeFakes();
    users.set("u1", { id: "u1", email: "a@b.c", displayName: "Ann", role: "admin" } as never);
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(users.get("u1")?.role).toBe("admin");
  });

  it("on transfer, downgrades the previous owner's membership to member", async () => {
    const { facade, memberships, gyms } = makeFakes({ ownerId: "owner9" });
    memberships.set("g1::owner9", {
      id: "m0", gymId: "g1", userId: "owner9", status: "active", verifiedMember: true,
      gymRole: "owner", isHome: true, visibleInRoster: true, joinMethod: "self",
      joinedAt: "2020-01-01T00:00:00.000Z",
    });
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(gyms.get("g1")?.ownerId).toBe("u1");
    expect(memberships.get("g1::owner9")?.gymRole).toBe("member");
    expect(memberships.get("g1::owner9")?.isHome).toBe(true); // isHome untouched
  });

  it("supersedes other pending claims for the same gym", async () => {
    const { facade, claims } = makeFakes();
    const c1 = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    const c2 = await facade.submit("u2", "g1", { relationship: "manager", contact: "u2@gym.com", message: "no mine" });
    await facade.approve("admin1", c1.id);
    expect(claims.get(c1.id)?.status).toBe("approved");
    expect(claims.get(c2.id)?.status).toBe("rejected");
  });

  it("notifies the claimant on approval", async () => {
    const { facade, notifications } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(notifications.some((n) => n.userId === "u1" && (n.data?.["outcome"] === "approved"))).toBe(true);
  });

  it("409s approving a non-pending claim", async () => {
    const { facade } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    let code = "";
    try {
      await facade.approve("admin1", c.id);
    } catch (e) {
      if (e instanceof AppError) code = e.code;
    }
    expect(code).toBe("conflict");
  });
});
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts`
Expected: FAIL — `facade.approve is not a function`.

- [ ] **Step 3: Implement `approve`**

Add this method to `GymClaimFacade` (in `apps/api/src/facades/gym-claim.facade.mts`), after `reject`:

```typescript
  public async approve(adminId: string, claimId: string): Promise<GymClaim> {
    const claim = await this.getClaimOr404(claimId);
    if (claim.status !== "pending") throw new AppError("conflict", "Claim is not pending");
    const gym: Gym | null = await this.gyms.findById(claim.gymId);
    if (!gym) throw new AppError("not_found", `Gym ${claim.gymId} not found`);

    const previousOwnerId: string | undefined = gym.ownerId;
    const now: string = new Date().toISOString();

    // 1. Move ownership on the gym.
    await this.gyms.update(gym.id, { ownerId: claim.claimantId });

    // 2. Elevate the claimant's account role (never downgrade admin/gym_owner).
    const claimant = await this.users.findById(claim.claimantId);
    if (claimant && claimant.role !== "gym_owner" && claimant.role !== "admin") {
      await this.users.update(claim.claimantId, { role: "gym_owner" });
    }

    // 3. Grant the claimant an owner membership (create or promote).
    const existing = await this.memberships.find(gym.id, claim.claimantId);
    if (existing) {
      await this.memberships.update(gym.id, claim.claimantId, {
        gymRole: "owner",
        status: "active",
        verifiedMember: true,
      });
    } else {
      await this.memberships.upsertJoin({
        id: this.newId(),
        gymId: gym.id,
        userId: claim.claimantId,
        status: "active",
        verifiedMember: true,
        gymRole: "owner",
        isHome: false,
        visibleInRoster: true,
        joinMethod: "self",
        joinedAt: now,
        createdAt: now,
      });
    }

    // 4. On a transfer, downgrade the previous owner's per-gym role (keep account role + isHome).
    if (previousOwnerId && previousOwnerId !== claim.claimantId) {
      const prev = await this.memberships.find(gym.id, previousOwnerId);
      if (prev) await this.memberships.update(gym.id, previousOwnerId, { gymRole: "member" });
      await this.notify(
        previousOwnerId,
        "Ownership transferred",
        `Ownership of ${gym.name} was transferred`,
        { gymId: gym.id, claimId, outcome: "transferred" },
      );
    }

    // 5. Mark this claim approved. Only include previousOwnerId when set, so a
    //    'claim' (no prior owner) never writes an undefined/null into $set.
    const approvePatch: Partial<GymClaim> = {
      status: "approved",
      decidedAt: now,
      decidedBy: adminId,
    };
    if (previousOwnerId !== undefined) approvePatch.previousOwnerId = previousOwnerId;
    const updated = (await this.claims.updateStatus(claimId, approvePatch)) as GymClaim;

    // 6. Supersede other pending claims for this gym.
    const others = (await this.claims.listPendingByGym(gym.id)).filter((c) => c.id !== claimId);
    for (const other of others) {
      await this.claims.updateStatus(other.id, {
        status: "rejected",
        decidedAt: now,
        decidedBy: adminId,
        decisionNote: "superseded by another approved claim",
      });
      await this.notify(
        other.claimantId,
        "Claim not approved",
        `Ownership of ${gym.name} was granted to another claimant`,
        { gymId: gym.id, claimId: other.id, outcome: "rejected" },
      );
    }

    // 7. Notify the claimant.
    await this.notify(
      claim.claimantId,
      "Claim approved",
      `You now manage ${gym.name}`,
      { gymId: gym.id, claimId, outcome: "approved" },
    );
    return updated;
  }
```

Note: `previousOwnerId` is added to the `$set` patch only when defined (step 5), so a `claim`-kind approval never writes an undefined/null. No empty-`$set` risk — `status`/`decidedAt`/`decidedBy` are always present.

- [ ] **Step 4: Run to verify all facade tests pass**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts`
Expected: PASS (15 tests total)

- [ ] **Step 5: Lint + commit**

```bash
cd apps/api && bunx eslint --fix src/facades/gym-claim.facade.mts test/gym-claim-facade.test.mts
cd ../.. && git add apps/api/src/facades/gym-claim.facade.mts apps/api/test/gym-claim-facade.test.mts
git commit -m "feat(api): GymClaimFacade.approve — ownership grant, transfer, supersede"
```

---

## Task 7: Routes + DI wiring

**Files:**
- Create: `apps/api/src/routes/gym-claim.routes.mts`
- Modify: `apps/api/src/container.mts` (repo + facade + interface + ensureIndexes)
- Modify: `apps/api/src/app.mts` (register routes)
- Test: `apps/api/test/gym-claim.routes.test.mts`

**Interfaces:**
- Consumes: `GymClaimFacade` (Tasks 5-6), `authPlugin`, `requireId`, envelope helpers, `SubmitGymClaimRequest`/`RejectGymClaimRequest`/`AdminGymClaimsQuery`.
- Produces: `gymClaimRoutes(container)`; `container.gymClaimFacade`.

- [ ] **Step 1: Wire the repository + facade into the container**

In `apps/api/src/container.mts`:

1. Add imports near the other repo/facade imports:
```typescript
import { GymClaimFacade } from "./facades/gym-claim.facade.mts";
import { GymClaimRepository } from "./repositories/gym-claim.repository.mts";
```
2. Add to the `Container` interface (after `messagingFacade`):
```typescript
  readonly gymClaimFacade: GymClaimFacade;
```
3. Instantiate the repo (with the other `new XRepository(db)` lines):
```typescript
  const gymClaimRepo = new GymClaimRepository(db);
```
4. Add the facade to the returned object (after `messagingFacade: ...`):
```typescript
    gymClaimFacade: new GymClaimFacade(gymClaimRepo, gymRepo, userRepo, membershipRepo, notificationRepo, id),
```
5. Add to the `ensureIndexes` `Promise.all([...])`:
```typescript
        gymClaimRepo.ensureIndexes(),
```

- [ ] **Step 2: Write the failing route test**

Create `apps/api/test/gym-claim.routes.test.mts`:

```typescript
import { afterAll, beforeEach, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";
import { loadEnv } from "../src/config/env.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27021", { timeoutMS: 8000 });
const db = client.db("bjj_test_gym_claim_routes");
const env = loadEnv();
const container = createContainer(db, { ...env, bypassSecret: "test-secret", demoUser: { id: "demo", email: "d@e.f", role: "practitioner" } } as never);
const app = buildApp(container);

afterAll(async () => { await db.dropDatabase(); await client.close(); });
beforeEach(async () => {
  await db.collection("gyms").deleteMany({});
  await db.collection("gymClaims").deleteMany({});
  await db.collection("users").deleteMany({});
});

// Helper: bypass auth as a given role. The bypass token equals bypassSecret;
// role is taken from demoUser, so we seed the user's DB role for role overrides.
async function req(path: string, opts: { method?: string; body?: unknown; role?: string } = {}): Promise<Response> {
  const headers: Record<string, string> = { authorization: "Bearer test-secret" };
  if (opts.body) headers["content-type"] = "application/json";
  return app.handle(new Request(`http://local${path}`, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  }));
}

describe("gym claim routes", () => {
  it("submits a claim for an unowned gym", async () => {
    await db.collection("gyms").insertOne({ _id: "g1", id: "g1", name: "Alliance", address: "1 Main St", amenities: [], isVerified: false });
    const res = await req("/api/v1/gyms/g1/claims", {
      method: "POST",
      body: { relationship: "owner", contact: "me@gym.com", message: "I own this" },
    });
    expect(res.status).toBe(200);
    const json = await res.json() as { data: { kind: string; status?: string } };
    expect(json.data.kind).toBe("claim");
  });

  it("returns my latest claim for a gym", async () => {
    await db.collection("gyms").insertOne({ _id: "g1", id: "g1", name: "Alliance", address: "1 Main St", amenities: [], isVerified: false });
    await req("/api/v1/gyms/g1/claims", { method: "POST", body: { relationship: "owner", contact: "me@gym.com", message: "mine" } });
    const res = await req("/api/v1/gyms/g1/claims/me");
    expect(res.status).toBe(200);
    const json = await res.json() as { data: { gymId: string } | null };
    expect(json.data?.gymId).toBe("g1");
  });

  it("blocks a non-admin from the admin queue", async () => {
    // demoUser role is practitioner and no DB role override -> not admin
    const res = await req("/api/v1/admin/gym-claims?status=pending");
    expect(res.status).toBe(403);
  });
});
```

> Note: if `loadEnv()` requires env vars not present in the test shell, mirror the setup used by `apps/api/test/gym-review-link.test.mts` or another existing route test for constructing the container/app; keep the three assertions above.

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim.routes.test.mts`
Expected: FAIL — `gymClaimRoutes` / route 404s.

- [ ] **Step 4: Implement the routes**

`apps/api/src/routes/gym-claim.routes.mts`:

```typescript
import { Elysia } from "elysia";
import { SubmitGymClaimRequest, RejectGymClaimRequest, AdminGymClaimsQuery } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function gymClaimRoutes(container: Container) {
  const { gymClaimFacade } = container;

  const claimantRoutes = new Elysia({ prefix: "/api/v1" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/gyms/:id/claims",
      async ({ identity, params, body }) =>
        data(await gymClaimFacade.submit(requireId(identity).userId, params.id, body)),
      { requireAuth: true, body: SubmitGymClaimRequest },
    )
    .get(
      "/gyms/:id/claims/me",
      async ({ identity, params }) =>
        data(await gymClaimFacade.getMyClaimForGym(requireId(identity).userId, params.id)),
      { requireAuth: true },
    )
    .delete(
      "/gyms/:id/claims/me",
      async ({ identity, params }) => {
        await gymClaimFacade.cancel(requireId(identity).userId, params.id);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .get(
      "/users/me/gym-claims",
      async ({ identity }) => {
        const claims = await gymClaimFacade.listMyClaims(requireId(identity).userId);
        return list(claims, { page: 1, limit: claims.length, total: claims.length });
      },
      { requireAuth: true },
    );

  const adminRoutes = new Elysia({ prefix: "/api/v1/admin" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/gym-claims",
      async ({ query }) => {
        const claims = await gymClaimFacade.listForAdmin(query.status ?? "pending");
        return list(claims, { page: 1, limit: claims.length, total: claims.length });
      },
      { requireAdmin: true, query: AdminGymClaimsQuery },
    )
    .post(
      "/gym-claims/:claimId/approve",
      async ({ identity, params }) =>
        data(await gymClaimFacade.approve(requireId(identity).userId, params.claimId)),
      { requireAdmin: true },
    )
    .post(
      "/gym-claims/:claimId/reject",
      async ({ identity, params, body }) =>
        data(await gymClaimFacade.reject(requireId(identity).userId, params.claimId, body.note)),
      { requireAdmin: true, body: RejectGymClaimRequest },
    );

  return new Elysia().use(claimantRoutes).use(adminRoutes);
}
```

- [ ] **Step 5: Register the routes in the app**

In `apps/api/src/app.mts`, add the import at the top with the other route imports:
```typescript
import { gymClaimRoutes } from "./routes/gym-claim.routes.mts";
```
and add `.use(gymClaimRoutes(container))` right after `.use(gymRoutes(container))`.

- [ ] **Step 6: Run route test + full API suite**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim.routes.test.mts`
Expected: PASS (3 tests)

Then the whole suite (nothing regressed):
Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: all pass.

- [ ] **Step 7: Boot check (DI wires up)**

```bash
cd apps/api && MONGODB_URI="mongodb://localhost:27021" MONGODB_DB="bjj_bootcheck" PORT=3199 bun src/index.mts &
sleep 3 && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3199/health && kill %1
```
Expected: `200`.

- [ ] **Step 8: Lint + commit**

```bash
cd apps/api && bunx eslint --fix src/routes/gym-claim.routes.mts src/container.mts src/app.mts test/gym-claim.routes.test.mts
cd ../.. && git add apps/api/src/routes/gym-claim.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/gym-claim.routes.test.mts
git commit -m "feat(api): gym-claim routes (claimant + admin) wired via DI"
```

---

## Task 8: Mobile — models + endpoints

**Files:**
- Create: `apps/mobile/lib/features/gym_claims/models/gym_claim.dart`
- Create: `apps/mobile/lib/features/gym_claims/models/admin_gym_claim.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/mobile/test/gym_claims/gym_claim_model_test.dart`

**Interfaces:**
- Produces: `GymClaim` (Dart), `AdminGymClaim` (Dart, claim + gym summary + claimant), endpoint helpers.

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gym_claims/gym_claim_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';

void main() {
  test('GymClaim.fromJson parses fields and status', () {
    final c = GymClaim.fromJson({
      'id': 'c1',
      'gymId': 'g1',
      'claimantId': 'u1',
      'kind': 'transfer',
      'relationship': 'owner',
      'contact': 'me@gym.com',
      'message': 'mine',
      'status': 'pending',
      'createdAt': '2026-07-30T00:00:00.000Z',
    });
    expect(c.id, 'c1');
    expect(c.kind, 'transfer');
    expect(c.status, 'pending');
  });

  test('AdminGymClaim.fromJson parses nested gym + claimant', () {
    final a = AdminGymClaim.fromJson({
      'claim': {
        'id': 'c1', 'gymId': 'g1', 'claimantId': 'u1', 'kind': 'claim',
        'relationship': 'owner', 'contact': 'me@gym.com', 'message': 'mine',
        'status': 'pending', 'createdAt': '2026-07-30T00:00:00.000Z',
      },
      'gymName': 'Alliance',
      'gymPhone': '555-1212',
      'gymWebsite': 'alliance.com',
      'claimantEmail': 'me@gym.com',
    });
    expect(a.claim.id, 'c1');
    expect(a.gymName, 'Alliance');
    expect(a.gymPhone, '555-1212');
    expect(a.claimantEmail, 'me@gym.com');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_claims/gym_claim_model_test.dart`
Expected: FAIL — models don't exist.

- [ ] **Step 3: Create `GymClaim` model**

`apps/mobile/lib/features/gym_claims/models/gym_claim.dart`:

```dart
class GymClaim {
  final String id;
  final String gymId;
  final String claimantId;
  final String kind; // 'claim' | 'transfer'
  final String relationship; // 'owner' | 'head_coach' | 'manager'
  final String contact;
  final String message;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String? previousOwnerId;
  final String? createdAt;
  final String? decidedAt;
  final String? decisionNote;

  const GymClaim({
    required this.id,
    required this.gymId,
    required this.claimantId,
    required this.kind,
    required this.relationship,
    required this.contact,
    required this.message,
    required this.status,
    this.previousOwnerId,
    this.createdAt,
    this.decidedAt,
    this.decisionNote,
  });

  factory GymClaim.fromJson(Map<String, dynamic> json) => GymClaim(
        id: json['id'] as String,
        gymId: json['gymId'] as String,
        claimantId: json['claimantId'] as String,
        kind: json['kind'] as String,
        relationship: json['relationship'] as String,
        contact: json['contact'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        previousOwnerId: json['previousOwnerId'] as String?,
        createdAt: json['createdAt'] as String?,
        decidedAt: json['decidedAt'] as String?,
        decisionNote: json['decisionNote'] as String?,
      );
}
```

- [ ] **Step 4: Create `AdminGymClaim` model**

`apps/mobile/lib/features/gym_claims/models/admin_gym_claim.dart`:

```dart
import 'gym_claim.dart';

class AdminGymClaim {
  final GymClaim claim;
  final String gymName;
  final String? gymPhone;
  final String? gymWebsite;
  final String? claimantEmail;

  const AdminGymClaim({
    required this.claim,
    required this.gymName,
    this.gymPhone,
    this.gymWebsite,
    this.claimantEmail,
  });

  factory AdminGymClaim.fromJson(Map<String, dynamic> json) => AdminGymClaim(
        claim: GymClaim.fromJson(json['claim'] as Map<String, dynamic>),
        gymName: json['gymName'] as String? ?? 'Gym',
        gymPhone: json['gymPhone'] as String?,
        gymWebsite: json['gymWebsite'] as String?,
        claimantEmail: json['claimantEmail'] as String?,
      );
}
```

- [ ] **Step 5: Add endpoints**

In `apps/mobile/lib/core/api/endpoints.dart`, add (in the Gyms section):

```dart
  static String gymClaims(String gymId) => '/api/v1/gyms/$gymId/claims';
  static String gymClaimMine(String gymId) => '/api/v1/gyms/$gymId/claims/me';
  static const String adminGymClaims = '/api/v1/admin/gym-claims';
  static String adminGymClaimApprove(String claimId) => '/api/v1/admin/gym-claims/$claimId/approve';
  static String adminGymClaimReject(String claimId) => '/api/v1/admin/gym-claims/$claimId/reject';
```

> The admin list endpoint returns the enriched view: shape `{ claim, gymName, gymPhone?, gymWebsite?, claimantEmail? }`. **The API's `listForAdmin` currently returns bare `GymClaim[]`.** To match `AdminGymClaim`, extend the API admin GET handler (Task 7 route) to enrich each claim; if you kept it bare, update `AdminGymClaim.fromJson` to read a flat `GymClaim` instead. Decide now and keep the two ends consistent. **Recommended:** enrich on the API — see Task 8b.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_claims/gym_claim_model_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 7: analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/gym_claims lib/core/api/endpoints.dart test/gym_claims
cd ../.. && git add apps/mobile/lib/features/gym_claims/models apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/gym_claims/gym_claim_model_test.dart
git commit -m "feat(mobile): gym-claim models + endpoints"
```

---

## Task 8b: API — enrich the admin list view

**Files:**
- Modify: `apps/api/src/facades/gym-claim.facade.mts` (add `listForAdminEnriched`)
- Modify: `apps/api/src/routes/gym-claim.routes.mts` (admin GET returns enriched view)
- Modify: `apps/api/test/gym-claim-facade.test.mts` (test enrichment)

**Interfaces:**
- Produces: `listForAdminEnriched(status): Promise<AdminGymClaimView[]>` where `AdminGymClaimView = { claim: GymClaim; gymName: string; gymPhone?: string; gymWebsite?: string; claimantEmail?: string }`.

- [ ] **Step 1: Add the failing test**

Append to `apps/api/test/gym-claim-facade.test.mts`:

```typescript
describe("GymClaimFacade — admin enrichment", () => {
  it("enriches pending claims with gym name/phone/website + claimant email", async () => {
    const { facade, users } = makeFakes({ phone: "555-1212", website: "alliance.com" });
    users.set("u1", { id: "u1", email: "me@gym.com", displayName: "Me", role: "practitioner" } as never);
    await facade.submit("u1", "g1", { relationship: "owner", contact: "me@gym.com", message: "mine" });
    const views = await facade.listForAdminEnriched("pending");
    expect(views).toHaveLength(1);
    expect(views[0]?.gymName).toBe("Alliance");
    expect(views[0]?.gymPhone).toBe("555-1212");
    expect(views[0]?.claimantEmail).toBe("me@gym.com");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts`
Expected: FAIL — `listForAdminEnriched` missing.

- [ ] **Step 3: Implement enrichment**

Add to `gym-claim.facade.mts` (export the view type + method):

```typescript
export interface AdminGymClaimView {
  readonly claim: GymClaim;
  readonly gymName: string;
  readonly gymPhone?: string;
  readonly gymWebsite?: string;
  readonly claimantEmail?: string;
}
```

and add the method to the class:

```typescript
  public async listForAdminEnriched(status: GymClaimStatus): Promise<AdminGymClaimView[]> {
    const claims = await this.claims.listByStatus(status);
    return Promise.all(
      claims.map(async (claim): Promise<AdminGymClaimView> => {
        const gym = await this.gyms.findById(claim.gymId);
        const claimant = await this.users.findById(claim.claimantId);
        const view: AdminGymClaimView = {
          claim,
          gymName: gym?.name ?? "Gym",
          gymPhone: gym?.phone,
          gymWebsite: gym?.website,
          claimantEmail: claimant?.email,
        };
        return view;
      }),
    );
  }
```

- [ ] **Step 4: Point the admin route at the enriched method**

In `gym-claim.routes.mts`, change the admin GET handler body to:

```typescript
      async ({ query }) => {
        const views = await gymClaimFacade.listForAdminEnriched(query.status ?? "pending");
        return list(views, { page: 1, limit: views.length, total: views.length });
      },
```

- [ ] **Step 5: Run facade + route tests**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/gym-claim-facade.test.mts test/gym-claim.routes.test.mts`
Expected: PASS.

- [ ] **Step 6: Lint + commit**

```bash
cd apps/api && bunx eslint --fix src/facades/gym-claim.facade.mts src/routes/gym-claim.routes.mts test/gym-claim-facade.test.mts
cd ../.. && git add apps/api/src/facades/gym-claim.facade.mts apps/api/src/routes/gym-claim.routes.mts apps/api/test/gym-claim-facade.test.mts
git commit -m "feat(api): enriched admin gym-claim list view"
```

---

## Task 9: Mobile — repository + providers

**Files:**
- Create: `apps/mobile/lib/features/gym_claims/data/gym_claim_repository.dart`
- Test: `apps/mobile/test/gym_claims/gym_claim_repository_test.dart` (optional light test — see note)

**Interfaces:**
- Consumes: `apiClientProvider` (`ref.read(apiClientProvider).dio`), `unwrapData`, `unwrapList`, `ApiException`.
- Produces: `gymClaimRepositoryProvider`, `myGymClaimProvider` (family, `String gymId` → `GymClaim?`), `adminGymClaimsProvider` (family, `String status` → `List<AdminGymClaim>`).

- [ ] **Step 1: Implement the repository + providers**

`apps/mobile/lib/features/gym_claims/data/gym_claim_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym_claim.dart';
import '../models/admin_gym_claim.dart';

abstract class GymClaimRepository {
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message});
  Future<GymClaim?> myClaimForGym(String gymId);
  Future<void> withdraw(String gymId);
  Future<List<AdminGymClaim>> adminList({String status = 'pending'});
  Future<void> approve(String claimId);
  Future<void> reject(String claimId, {String? note});
}

class ApiGymClaimRepository implements GymClaimRepository {
  final Dio _dio;
  ApiGymClaimRepository(this._dio);

  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async {
    try {
      final res = await _dio.post(Endpoints.gymClaims(gymId), data: {
        'relationship': relationship,
        'contact': contact,
        'message': message,
      });
      return GymClaim.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymClaim?> myClaimForGym(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymClaimMine(gymId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data == null) return null;
      return GymClaim.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> withdraw(String gymId) async {
    try {
      await _dio.delete(Endpoints.gymClaimMine(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async {
    try {
      final res = await _dio.get(Endpoints.adminGymClaims, queryParameters: {'status': status});
      return unwrapList(res.data as Map<String, dynamic>).items.map(AdminGymClaim.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> approve(String claimId) async {
    try {
      await _dio.post(Endpoints.adminGymClaimApprove(claimId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> reject(String claimId, {String? note}) async {
    try {
      await _dio.post(Endpoints.adminGymClaimReject(claimId), data: {if (note != null) 'note': note});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymClaimRepositoryProvider = Provider<GymClaimRepository>((ref) {
  return ApiGymClaimRepository(ref.read(apiClientProvider).dio);
});

final myGymClaimProvider = FutureProvider.family<GymClaim?, String>((ref, gymId) {
  return ref.read(gymClaimRepositoryProvider).myClaimForGym(gymId);
});

final adminGymClaimsProvider = FutureProvider.family<List<AdminGymClaim>, String>((ref, status) {
  return ref.read(gymClaimRepositoryProvider).adminList(status: status);
});
```

> Note: confirm `ApiException.fromDio` exists (used by messaging repo). If the constructor differs, mirror `messaging_repository.dart` exactly.

- [ ] **Step 2: analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/gym_claims/data
cd ../.. && git add apps/mobile/lib/features/gym_claims/data/gym_claim_repository.dart
git commit -m "feat(mobile): gym-claim repository + providers"
```

---

## Task 10: Mobile — claim form screen + route

**Files:**
- Create: `apps/mobile/lib/features/gym_claims/screens/claim_gym_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (add `gym/:id/claim` route)
- Test: `apps/mobile/test/gym_claims/claim_gym_screen_test.dart`

**Interfaces:**
- Consumes: `gymClaimRepositoryProvider`, `myGymClaimProvider`; `friendlyErrorMessage`.
- Produces: `ClaimGymScreen(gymId, kind)`.

- [ ] **Step 1: Write the failing widget test**

Create `apps/mobile/test/gym_claims/claim_gym_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/screens/claim_gym_screen.dart';

class _FakeRepo implements GymClaimRepository {
  final List<Map<String, String>> submits = [];
  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async {
    submits.add({'gymId': gymId, 'relationship': relationship, 'contact': contact, 'message': message});
    return GymClaim(id: 'c1', gymId: gymId, claimantId: 'u1', kind: 'claim', relationship: relationship, contact: contact, message: message, status: 'pending');
  }
  @override
  Future<GymClaim?> myClaimForGym(String gymId) async => null;
  @override
  Future<void> withdraw(String gymId) async {}
  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async => [];
  @override
  Future<void> approve(String claimId) async {}
  @override
  Future<void> reject(String claimId, {String? note}) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [gymClaimRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.glass(), home: const ClaimGymScreen(gymId: 'g1', kind: 'claim')),
    ));
    await tester.pump();
  }

  testWidgets('submits the claim with the entered contact + message', (tester) async {
    final repo = _FakeRepo();
    await pump(tester, repo);
    await tester.enterText(find.byKey(const Key('claim-contact')), 'me@gym.com');
    await tester.enterText(find.byKey(const Key('claim-message')), 'I run this gym');
    await tester.tap(find.byKey(const Key('claim-submit')));
    await tester.pump();
    expect(repo.submits, hasLength(1));
    expect(repo.submits.first['contact'], 'me@gym.com');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_claims/claim_gym_screen_test.dart`
Expected: FAIL — screen doesn't exist.

- [ ] **Step 3: Implement the screen**

`apps/mobile/lib/features/gym_claims/screens/claim_gym_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/gym_claim_repository.dart';

class ClaimGymScreen extends ConsumerStatefulWidget {
  final String gymId;
  final String kind; // 'claim' | 'transfer'
  const ClaimGymScreen({super.key, required this.gymId, required this.kind});

  @override
  ConsumerState<ClaimGymScreen> createState() => _ClaimGymScreenState();
}

class _ClaimGymScreenState extends ConsumerState<ClaimGymScreen> {
  String _relationship = 'owner';
  final _contactCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contactCtrl.addListener(() => setState(() {}));
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving && _contactCtrl.text.trim().isNotEmpty && _messageCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(gymClaimRepositoryProvider).submit(
            widget.gymId,
            relationship: _relationship,
            contact: _contactCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
          );
      ref.invalidate(myGymClaimProvider(widget.gymId));
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final title = widget.kind == 'transfer' ? 'Request ownership' : 'Claim this gym';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text(title, style: t.h2Style),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your role at this gym', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('claim-relationship'),
                initialValue: _relationship,
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'head_coach', child: Text('Head coach')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setState(() => _relationship = v ?? 'owner'),
              ),
              const SizedBox(height: 16),
              Text('Gym contact (email or phone)', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('claim-contact'),
                controller: _contactCtrl,
                decoration: const InputDecoration(hintText: 'owner@yourgym.com'),
              ),
              const SizedBox(height: 16),
              Text('Message', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('claim-message'),
                controller: _messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Tell us how you\'re connected to this gym'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(_error!, style: t.bodyStyle.copyWith(color: t.red)),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('claim-submit'),
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary,
                  disabledBackgroundColor: t.border,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Text('Submit', style: t.h2Style.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route**

In `apps/mobile/lib/app/router.dart`, add to the `gym/:id` nested `routes: [...]` list (mirroring the `open-mats`/`roster` entries):

```dart
GoRoute(
  path: 'claim',
  builder: (context, state) => ClaimGymScreen(
    gymId: state.pathParameters['id']!,
    kind: state.uri.queryParameters['kind'] ?? 'claim',
  ),
),
```

and add the import at the top of `router.dart`:
```dart
import '../features/gym_claims/screens/claim_gym_screen.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_claims/claim_gym_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/gym_claims/screens/claim_gym_screen.dart lib/app/router.dart test/gym_claims/claim_gym_screen_test.dart
cd ../.. && git add apps/mobile/lib/features/gym_claims/screens/claim_gym_screen.dart apps/mobile/lib/app/router.dart apps/mobile/test/gym_claims/claim_gym_screen_test.dart
git commit -m "feat(mobile): claim gym form screen + route"
```

---

## Task 11: Mobile — gym-detail entry point

**Files:**
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`
- Test: `apps/mobile/test/gym_claims/gym_detail_claim_entry_test.dart`

**Interfaces:**
- Consumes: `myGymClaimProvider`, `currentUserIdProvider`, `authStateProvider`, gym `ownerId`.
- Produces: an entry-point widget on gym detail reflecting the five states.

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gym_claims/gym_detail_claim_entry_test.dart`. It pumps the small entry-point widget in isolation (extract a `GymClaimEntry` widget rather than the whole screen to keep the test focused):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/widgets/gym_claim_entry.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, {required String? ownerId, GymClaim? myClaim, String? myId}) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        myGymClaimProvider('g1').overrideWith((_) async => myClaim),
        currentUserIdProvider.overrideWith((ref) => myId),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(body: GymClaimEntry(gymId: 'g1', ownerId: ownerId)),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows Claim this gym when unowned and no claim', (tester) async {
    await pump(tester, ownerId: null, myClaim: null, myId: 'u1');
    expect(find.text('Claim this gym'), findsOneWidget);
  });

  testWidgets('shows Request ownership when owned by someone else', (tester) async {
    await pump(tester, ownerId: 'other', myClaim: null, myId: 'u1');
    expect(find.text('Request ownership'), findsOneWidget);
  });

  testWidgets('shows pending chip when a pending claim exists', (tester) async {
    await pump(tester, ownerId: null, myId: 'u1', myClaim: const GymClaim(
      id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner',
      contact: 'x', message: 'y', status: 'pending'));
    expect(find.text('Claim pending review'), findsOneWidget);
  });

  testWidgets('shows nothing when caller is the owner', (tester) async {
    await pump(tester, ownerId: 'u1', myClaim: null, myId: 'u1');
    expect(find.text('Claim this gym'), findsNothing);
    expect(find.text('Request ownership'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_claims/gym_detail_claim_entry_test.dart`
Expected: FAIL — `GymClaimEntry` doesn't exist.

- [ ] **Step 3: Implement the entry widget**

`apps/mobile/lib/features/gym_claims/widgets/gym_claim_entry.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/gym_claim_repository.dart';

class GymClaimEntry extends ConsumerWidget {
  final String gymId;
  final String? ownerId;
  const GymClaimEntry({super.key, required this.gymId, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final myId = ref.watch(currentUserIdProvider);

    // Owner sees no entry point.
    if (myId != null && ownerId == myId) return const SizedBox.shrink();
    // Signed-out users can't claim.
    if (myId == null) return const SizedBox.shrink();

    final claimAsync = ref.watch(myGymClaimProvider(gymId));
    return claimAsync.maybeWhen(
      data: (claim) {
        if (claim != null && claim.status == 'pending') {
          return _chip(t, 'Claim pending review', LucideChipIcon.pending);
        }
        final kind = ownerId != null ? 'transfer' : 'claim';
        final label = ownerId != null ? 'Request ownership' : 'Claim this gym';
        return _button(context, t, label, kind);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _button(BuildContext context, AppTokens t, String label, String kind) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => context.push('/gym/$gymId/claim?kind=$kind'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_outlined, size: 16, color: t.text),
            const SizedBox(width: 8),
            Text(label, style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _chip(AppTokens t, String label, LucideChipIcon _) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.primary.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hourglass_top, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Text(label, style: t.miniStyle.copyWith(color: t.primary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

enum LucideChipIcon { pending }
```

> The `LucideChipIcon` enum is a throwaway to keep `_chip`'s signature explicit; if lint flags it as unused complexity, inline the icon and drop the enum. Keep the visible text exactly `Claim this gym` / `Request ownership` / `Claim pending review` for the tests.

- [ ] **Step 4: Mount the entry widget on gym detail**

In `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`, add the import:
```dart
import '../../gym_claims/widgets/gym_claim_entry.dart';
```
and render it right after the `JoinGymButton(gymId: gym.id)` (around line 149):
```dart
GymClaimEntry(gymId: gym.id, ownerId: gym.ownerId),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_claims/gym_detail_claim_entry_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/gym_claims/widgets/gym_claim_entry.dart lib/features/gyms/screens/gym_detail_screen.dart test/gym_claims/gym_detail_claim_entry_test.dart
cd ../.. && git add apps/mobile/lib/features/gym_claims/widgets/gym_claim_entry.dart apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart apps/mobile/test/gym_claims/gym_detail_claim_entry_test.dart
git commit -m "feat(mobile): gym-detail claim entry point"
```

---

## Task 12: Mobile — admin review screen + route + profile row

**Files:**
- Create: `apps/mobile/lib/features/gym_claims/screens/admin_gym_claims_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (add `/admin/gym-claims` route)
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart` (admin row)
- Test: `apps/mobile/test/gym_claims/admin_gym_claims_screen_test.dart`

**Interfaces:**
- Consumes: `adminGymClaimsProvider`, `gymClaimRepositoryProvider`, `authStateProvider` (admin gate).
- Produces: `AdminGymClaimsScreen`.

- [ ] **Step 1: Write the failing widget test**

Create `apps/mobile/test/gym_claims/admin_gym_claims_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/screens/admin_gym_claims_screen.dart';

class _AdminAuth extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserProfile(id: 'admin1', email: 'a@b.c', displayName: 'Admin', role: 'admin'),
  );
}

class _FakeRepo implements GymClaimRepository {
  final List<String> approvals = [];
  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async => [
    AdminGymClaim(
      claim: const GymClaim(id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner', contact: 'me@gym.com', message: 'mine', status: 'pending'),
      gymName: 'Alliance', gymPhone: '555-1212', claimantEmail: 'me@gym.com',
    ),
  ];
  @override
  Future<void> approve(String claimId) async => approvals.add(claimId);
  @override
  Future<void> reject(String claimId, {String? note}) async {}
  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async => throw UnimplementedError();
  @override
  Future<GymClaim?> myClaimForGym(String gymId) async => null;
  @override
  Future<void> withdraw(String gymId) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gymClaimRepositoryProvider.overrideWithValue(repo),
        adminGymClaimsProvider('pending').overrideWith((_) async => repo.adminList()),
        authStateProvider.overrideWith(() => _AdminAuth()),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const AdminGymClaimsScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('admin sees claim rows with gym + claimant info', (tester) async {
    await pump(tester, _FakeRepo());
    expect(find.text('Alliance'), findsOneWidget);
    expect(find.textContaining('me@gym.com'), findsWidgets);
  });

  testWidgets('tapping Approve calls approve with the claim id', (tester) async {
    final repo = _FakeRepo();
    await pump(tester, repo);
    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(repo.approvals, contains('c1'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/gym_claims/admin_gym_claims_screen_test.dart`
Expected: FAIL — screen doesn't exist.

- [ ] **Step 3: Implement the admin screen**

`apps/mobile/lib/features/gym_claims/screens/admin_gym_claims_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/gym_claim_repository.dart';
import '../models/admin_gym_claim.dart';

class AdminGymClaimsScreen extends ConsumerWidget {
  const AdminGymClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0, title: Text('Gym Claims', style: t.h2Style)),
        body: Center(child: Text("You don't have access to this page.", style: t.bodyStyle.copyWith(color: t.muted))),
      );
    }

    final claimsAsync = ref.watch(adminGymClaimsProvider('pending'));
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0, title: Text('Gym Claims', style: t.h2Style)),
      body: claimsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load claims", style: t.bodyStyle.copyWith(color: t.muted))),
        data: (claims) => claims.isEmpty
            ? Center(child: Text('No pending claims', style: t.bodyStyle.copyWith(color: t.muted)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: claims.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ClaimTile(view: claims[i], t: t),
              ),
      ),
    );
  }
}

class _ClaimTile extends ConsumerWidget {
  final AdminGymClaim view;
  final AppTokens t;
  const _ClaimTile({required this.view, required this.t});

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(adminGymClaimsProvider('pending'));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't update the claim. Try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = view.claim;
    final repo = ref.read(gymClaimRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(t.cardRadius), border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(view.gymName, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${c.kind} • ${c.relationship}', style: t.miniStyle.copyWith(color: t.muted)),
          const SizedBox(height: 6),
          Text('Claimant: ${view.claimantEmail ?? c.claimantId}', style: t.miniStyle.copyWith(color: t.faint)),
          Text('Stated contact: ${c.contact}', style: t.miniStyle.copyWith(color: t.faint)),
          if (view.gymPhone != null) Text('Gym phone (listed): ${view.gymPhone}', style: t.miniStyle.copyWith(color: t.faint)),
          if (view.gymWebsite != null) Text('Gym website (listed): ${view.gymWebsite}', style: t.miniStyle.copyWith(color: t.faint)),
          const SizedBox(height: 6),
          Text(c.message, style: t.bodyStyle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _act(context, ref, () => repo.reject(c.id)),
                child: Text('Reject', style: t.miniStyle.copyWith(color: t.muted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _act(context, ref, () => repo.approve(c.id)),
                child: Text('Approve', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route + profile row**

In `apps/mobile/lib/app/router.dart`, add the import:
```dart
import '../features/gym_claims/screens/admin_gym_claims_screen.dart';
```
and add a top-level route (near other top-level routes, not inside a shell that gates by tab):
```dart
GoRoute(
  path: '/admin/gym-claims',
  builder: (context, state) => const AdminGymClaimsScreen(),
),
```

In `apps/mobile/lib/features/profile/screens/profile_screen.dart`, inside the existing `if (isAdmin) ...[` block (which already contains a "Review submissions" row), add another `ListTile`:
```dart
ListTile(
  leading: Icon(LucideIcons.building2, color: t.muted),
  title: Text('Gym Claims', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
  trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
  onTap: () => context.push('/admin/gym-claims'),
),
```

> If `profile_screen.dart` has no `if (isAdmin)` block yet, add one guarded by `final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';` (already computed at line ~60 per the reference).

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/gym_claims/admin_gym_claims_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/gym_claims/screens/admin_gym_claims_screen.dart lib/app/router.dart lib/features/profile/screens/profile_screen.dart test/gym_claims/admin_gym_claims_screen_test.dart
cd ../.. && git add apps/mobile/lib/features/gym_claims/screens/admin_gym_claims_screen.dart apps/mobile/lib/app/router.dart apps/mobile/lib/features/profile/screens/profile_screen.dart apps/mobile/test/gym_claims/admin_gym_claims_screen_test.dart
git commit -m "feat(mobile): admin gym-claims review screen + route + profile row"
```

---

## Task 13: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Full API suite (local Mongo on 27021)**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: all pass (previous baseline 309 + the new gym-claim tests).

- [ ] **Step 2: API type-check**

Run: `cd apps/api && bun run type-check`
Expected: only the 4 known pre-existing errors (class-journal.routes ×1, class.routes ×2, forum.routes ×1) — no new errors from gym-claim files.

- [ ] **Step 3: Full mobile suite**

Run: `cd apps/mobile && flutter test`
Expected: all pass (previous baseline 342 + the new gym-claim tests).

- [ ] **Step 4: Mobile analyze (whole app)**

Run: `cd apps/mobile && flutter analyze`
Expected: no new issues in `lib/features/gym_claims` or the modified files.

- [ ] **Step 5: Commit any final lint fixups (if needed)**

```bash
git add -A && git commit -m "chore(gym-claim): lint + verification fixups"
```

---

## Self-Review Notes (for the executor)

- **Spec coverage:** enums+schema (T1-3) → repository (T4) → facade submit/cancel/reject/list (T5) → approve/transfer/supersede (T6) → routes+DI (T7) → admin enrichment (T8b) → mobile models/endpoints (T8), repo/providers (T9), claim form (T10), gym-detail entry (T11), admin screen+route+profile row (T12) → verification (T13). Every spec section maps to a task.
- **Notifications:** claimant on approve/reject (T5/T6), current owner on transfer submit (T5), previous owner on transfer approve + superseded claimants (T6) — all via the `gym_claim` type with `data`.
- **Authz:** claimant routes `requireAuth`; admin routes `requireAdmin` (T7). Facade never trusts body ids.
- **Type consistency:** repo method names in T4 match the `Pick<>` slices in T5/T6/T8b; route handler calls match facade method names; mobile endpoint helpers match route paths.
- **Known-gotcha guards:** direct `await` in facade tests (Bun `.resolves` CSOT); invalidate `gymByIdProvider` (not `gymDetailProvider`) is not needed here because the entry point watches `myGymClaimProvider`, which we invalidate on submit/withdraw; the admin screen invalidates `adminGymClaimsProvider` after each action.
