# Gym Membership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user join gyms, appear on a public gym roster, designate one home gym, and let a gym's owner/coaches confirm members and record verified belt promotions.

**Architecture:** Follow the existing three layers — TypeBox contracts in `@bjj/contract`, then in `apps/api` a route module (`router`) → facade (business logic + authorization) → repository (Mongo), wired through `container.mts` and `app.mts`. The Flutter app consumes it via Dio repositories and Riverpod providers, one new `membership` feature folder. Verified belt rank is denormalized onto the `User` doc (for cheap list/profile rendering) with an append-only `BeltPromotion` history as the source of truth.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^7`), Flutter + Riverpod + Dio. Tests: `bun test` (API), `flutter test` (mobile).

## Global Constraints

- TypeScript strict mode; **no `any`**; explicit return types and access modifiers on all functions/methods; explicit types on variables.
- Validation is **TypeBox only** (never Zod). Schema-first: define schema, derive type with `Static<typeof X>`.
- `.mts` source; import specifiers use `.mjs`. One exported schema/type per concern; barrel via `index.mts`.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `console`/`debugPrint`.
- Health endpoints are `/health` and `/ready` — never `healthz`/`readyz` (not touched here, but hold the rule).
- Layering is **router → facade → repository**; no data access in routers/facades except through repositories; everything resolved through the `container.mts` DI, no `new` in routers.
- MongoDB driver stays `mongodb@^7`; never downgrade. Beware `null !== undefined` on optional Mongo fields — normalize on write and query.
- Conventional Commits; **never** add Co-Authored-By. Commit frequently (one per task minimum).
- Run `bunx eslint --fix` on changed `apps/api` / `packages/contract` files before each commit; fix all lint errors.

---

## File Structure

**`packages/contract/src`** (contracts)
- `enums/gym-role.mts` — `GymRole` (`member`|`coach`|`owner`)
- `enums/membership-status.mts` — `MembershipStatus` (`pending`|`active`)
- `enums/join-method.mts` — `JoinMethod` (`self`|`code`|`invite`)
- `schemas/gym-membership.mts` — `GymMembership`
- `schemas/belt-promotion.mts` — `BeltPromotion`
- `schemas/roster-member.mts` — `RosterMember` (roster response row)
- `schemas/requests/membership-requests.mts` — `UpdateMembershipRequest`, `UpdateMyMembershipRequest`, `PromoteBeltRequest`
- Modify: `schemas/user.mts` (verified belt fields), `schemas/gym.mts` (`joinCode`), the three barrels

**`apps/api/src`**
- `repositories/membership.repository.mts` — `MembershipRepository`
- `repositories/promotion.repository.mts` — `PromotionRepository`
- `facades/membership.facade.mts` — `MembershipFacade` (owns authorization)
- `routes/membership.routes.mts` — route module
- Modify: `db/collections.mts`, `container.mts`, `app.mts`

**`apps/mobile/lib/features/membership`**
- `models/gym_membership.dart`, `models/belt_promotion.dart`, `models/roster_member.dart`
- `data/membership_repository.dart` (+ Riverpod providers)
- `screens/roster_screen.dart`, `screens/my_gyms_screen.dart`
- `widgets/join_gym_button.dart`, `widgets/promote_belt_sheet.dart`
- Modify: `core/api/endpoints.dart`, `features/gyms/screens/gym_detail_screen.dart`, profile screen

---

## Task 1: Contract enums (GymRole, MembershipStatus, JoinMethod)

**Files:**
- Create: `packages/contract/src/enums/gym-role.mts`, `enums/membership-status.mts`, `enums/join-method.mts`
- Modify: `packages/contract/src/enums/index.mts`
- Test: `packages/contract/test/membership-enums.test.mts`

**Interfaces:**
- Produces: `GymRole` (`'member'|'coach'|'owner'`), `MembershipStatus` (`'pending'|'active'`), `JoinMethod` (`'self'|'code'|'invite'`) — TypeBox unions + `Static` types.

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/membership-enums.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymRole, MembershipStatus, JoinMethod } from "../src/index.mjs";

describe("membership enums", () => {
  it("accepts valid members", () => {
    expect(Value.Check(GymRole, "coach")).toBe(true);
    expect(Value.Check(MembershipStatus, "active")).toBe(true);
    expect(Value.Check(JoinMethod, "self")).toBe(true);
  });
  it("rejects invalid members", () => {
    expect(Value.Check(GymRole, "instructor")).toBe(false);
    expect(Value.Check(MembershipStatus, "banned")).toBe(false);
    expect(Value.Check(JoinMethod, "qr")).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test ../../packages/contract/test/membership-enums.test.mts` (contract has no own test runner script; run from apps/api which resolves `@bjj/contract`). Alternatively `cd packages/contract && bun test`.
Expected: FAIL — modules not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/enums/gym-role.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const GymRole = t.Union(
  [t.Literal("member"), t.Literal("coach"), t.Literal("owner")],
  { $id: "GymRole" },
);
export type GymRole = Static<typeof GymRole>;
```

```ts
// packages/contract/src/enums/membership-status.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const MembershipStatus = t.Union(
  [t.Literal("pending"), t.Literal("active")],
  { $id: "MembershipStatus" },
);
export type MembershipStatus = Static<typeof MembershipStatus>;
```

```ts
// packages/contract/src/enums/join-method.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const JoinMethod = t.Union(
  [t.Literal("self"), t.Literal("code"), t.Literal("invite")],
  { $id: "JoinMethod" },
);
export type JoinMethod = Static<typeof JoinMethod>;
```

Append to `packages/contract/src/enums/index.mts`:

```ts
export * from "./gym-role.mts";
export * from "./membership-status.mts";
export * from "./join-method.mts";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/membership-enums.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/enums packages/contract/test/membership-enums.test.mts
git commit -m "feat(contract): add gym-role, membership-status, join-method enums"
```

---

## Task 2: `GymMembership` and `BeltPromotion` schemas

**Files:**
- Create: `packages/contract/src/schemas/gym-membership.mts`, `schemas/belt-promotion.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `packages/contract/test/membership-schema.test.mts`

**Interfaces:**
- Consumes: `GymRole`, `MembershipStatus`, `JoinMethod` (Task 1), `BeltRank` (existing).
- Produces:
  - `GymMembership` = `{ id, gymId, userId, status: MembershipStatus, verifiedMember: boolean, gymRole: GymRole, isHome: boolean, visibleInRoster: boolean, joinMethod: JoinMethod, joinedAt: string, createdAt?: string }`
  - `BeltPromotion` = `{ id, userId, gymId, beltRank: BeltRank, beltStripes: integer 0..4, promotedByUserId: string, promotedAt: string, note?: string }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/membership-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { GymMembership, BeltPromotion } from "../src/index.mjs";

describe("GymMembership schema", () => {
  it("parses a minimal membership applying defaults", () => {
    const m = Value.Parse(GymMembership, {
      id: "m1", gymId: "g1", userId: "u1", joinedAt: "2026-07-27T00:00:00.000Z",
    });
    expect(m.gymRole).toBe("member");
    expect(m.status).toBe("active");
    expect(m.verifiedMember).toBe(false);
    expect(m.visibleInRoster).toBe(true);
    expect(m.isHome).toBe(false);
    expect(m.joinMethod).toBe("self");
  });
});

describe("BeltPromotion schema", () => {
  it("rejects stripes above 4", () => {
    expect(Value.Check(BeltPromotion, {
      id: "p1", userId: "u1", gymId: "g1", beltRank: "blue",
      beltStripes: 5, promotedByUserId: "u2", promotedAt: "2026-07-27T00:00:00.000Z",
    })).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/membership-schema.test.mts`
Expected: FAIL — `GymMembership`/`BeltPromotion` not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/gym-membership.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { GymRole } from "../enums/gym-role.mts";
import { MembershipStatus } from "../enums/membership-status.mts";
import { JoinMethod } from "../enums/join-method.mts";

export const GymMembership = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    userId: t.String(),
    status: t.Optional(t.Union([MembershipStatus], { default: "active" })),
    verifiedMember: t.Boolean({ default: false }),
    gymRole: t.Optional(t.Union([GymRole], { default: "member" })),
    isHome: t.Boolean({ default: false }),
    visibleInRoster: t.Boolean({ default: true }),
    joinMethod: t.Optional(t.Union([JoinMethod], { default: "self" })),
    joinedAt: t.String(),
    createdAt: t.Optional(t.String()),
  },
  { $id: "GymMembership" },
);
export type GymMembership = Static<typeof GymMembership>;
```

> Note: `status`/`gymRole`/`joinMethod` are wrapped `t.Optional(t.Union([...], { default }))` so `Value.Parse` fills the default when the field is absent (TypeBox only applies `default` to optional properties). `verifiedMember`/`isHome`/`visibleInRoster` are required-with-default to match the existing `Gym.isVerified` style.

```ts
// packages/contract/src/schemas/belt-promotion.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";

export const BeltPromotion = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    gymId: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    promotedByUserId: t.String(),
    promotedAt: t.String(),
    note: t.Optional(t.String()),
  },
  { $id: "BeltPromotion" },
);
export type BeltPromotion = Static<typeof BeltPromotion>;
```

Add to `packages/contract/src/schemas/index.mts` (after `check-in.mts`):

```ts
export * from "./gym-membership.mts";
export * from "./belt-promotion.mts";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/membership-schema.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/schemas packages/contract/test/membership-schema.test.mts
git commit -m "feat(contract): add GymMembership and BeltPromotion schemas"
```

---

## Task 3: Extend `User` + `Gym`; add membership request schemas + `RosterMember`

**Files:**
- Modify: `packages/contract/src/schemas/user.mts`, `schemas/gym.mts`
- Create: `packages/contract/src/schemas/roster-member.mts`, `schemas/requests/membership-requests.mts`
- Modify: `packages/contract/src/schemas/index.mts`, `schemas/requests/index.mts`
- Test: `packages/contract/test/membership-requests.test.mts`

**Interfaces:**
- Produces:
  - `User` gains `verifiedBeltRank?: BeltRank`, `verifiedBeltStripes?: integer 0..4`, `verifiedByGymId?: string`, `verifiedAt?: string`.
  - `Gym` gains `joinCode?: string`.
  - `RosterMember` = `{ userId, name, beltRank?: BeltRank, beltStripes?, verifiedBeltRank?: BeltRank, verifiedBeltStripes?, skillLevel?, avatarUrl?, gymRole: GymRole, verifiedMember: boolean, hasProfile: boolean }`.
  - `UpdateMembershipRequest` = `{ verifiedMember?: boolean, gymRole?: GymRole }`.
  - `UpdateMyMembershipRequest` = `{ visibleInRoster?: boolean, isHome?: boolean }`.
  - `PromoteBeltRequest` = `{ beltRank: BeltRank, beltStripes: integer 0..4, note?: string }`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/membership-requests.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { User, PromoteBeltRequest, UpdateMembershipRequest, UpdateMyMembershipRequest, RosterMember } from "../src/index.mjs";

describe("membership requests + user verified fields", () => {
  it("User accepts verified belt fields", () => {
    expect(Value.Check(User, {
      id: "u1", email: "a@b.co", displayName: "A",
      verifiedBeltRank: "purple", verifiedBeltStripes: 2, verifiedByGymId: "g1",
      verifiedAt: "2026-07-27T00:00:00.000Z",
    })).toBe(true);
  });
  it("PromoteBeltRequest requires belt and bounds stripes", () => {
    expect(Value.Check(PromoteBeltRequest, { beltRank: "brown", beltStripes: 1 })).toBe(true);
    expect(Value.Check(PromoteBeltRequest, { beltStripes: 1 })).toBe(false);
    expect(Value.Check(PromoteBeltRequest, { beltRank: "brown", beltStripes: 9 })).toBe(false);
  });
  it("Update requests are all-optional", () => {
    expect(Value.Check(UpdateMembershipRequest, {})).toBe(true);
    expect(Value.Check(UpdateMyMembershipRequest, { isHome: true })).toBe(true);
  });
  it("RosterMember requires identity + role flags", () => {
    expect(Value.Check(RosterMember, {
      userId: "u1", name: "A", gymRole: "coach", verifiedMember: true, hasProfile: true,
    })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/membership-requests.test.mts`
Expected: FAIL — new exports missing.

- [ ] **Step 3: Write minimal implementation**

In `schemas/user.mts`, add inside the `User` object (after `beltStripes`):

```ts
    verifiedBeltRank: t.Optional(BeltRank),
    verifiedBeltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    verifiedByGymId: t.Optional(t.String()),
    verifiedAt: t.Optional(t.String()),
```

In `schemas/gym.mts`, add (after `logoUrl`):

```ts
    joinCode: t.Optional(t.String()),
```

```ts
// packages/contract/src/schemas/roster-member.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { GymRole } from "../enums/gym-role.mts";
import { SkillLevel } from "../enums/skill-level.mts";

export const RosterMember = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    beltRank: t.Optional(BeltRank),
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    verifiedBeltRank: t.Optional(BeltRank),
    verifiedBeltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    skillLevel: t.Optional(SkillLevel),
    avatarUrl: t.Optional(t.String()),
    gymRole: GymRole,
    verifiedMember: t.Boolean(),
    // False when the user doc could not be resolved — clients must not deep-link.
    hasProfile: t.Boolean(),
  },
  { $id: "RosterMember" },
);
export type RosterMember = Static<typeof RosterMember>;
```

```ts
// packages/contract/src/schemas/requests/membership-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { GymRole } from "../../enums/gym-role.mts";

export const UpdateMembershipRequest = t.Object(
  {
    verifiedMember: t.Optional(t.Boolean()),
    gymRole: t.Optional(GymRole),
  },
  { $id: "UpdateMembershipRequest" },
);
export type UpdateMembershipRequest = Static<typeof UpdateMembershipRequest>;

export const UpdateMyMembershipRequest = t.Object(
  {
    visibleInRoster: t.Optional(t.Boolean()),
    isHome: t.Optional(t.Boolean()),
  },
  { $id: "UpdateMyMembershipRequest" },
);
export type UpdateMyMembershipRequest = Static<typeof UpdateMyMembershipRequest>;

export const PromoteBeltRequest = t.Object(
  {
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    note: t.Optional(t.String()),
  },
  { $id: "PromoteBeltRequest" },
);
export type PromoteBeltRequest = Static<typeof PromoteBeltRequest>;
```

Add to `schemas/index.mts`: `export * from "./roster-member.mts";`
Add to `schemas/requests/index.mts`: `export * from "./membership-requests.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/membership-requests.test.mts`
Expected: PASS. Also run the existing `bun test test/user-profile-fields.test.mts` to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src packages/contract/test/membership-requests.test.mts
git commit -m "feat(contract): user verified-belt fields, gym joinCode, membership requests, RosterMember"
```

---

## Task 4: `MembershipRepository`

**Files:**
- Create: `apps/api/src/repositories/membership.repository.mts`
- Modify: `apps/api/src/db/collections.mts` (add `gymMemberships: "gymMemberships"`)
- Test: `apps/api/test/membership.repository.test.mts`

**Interfaces:**
- Consumes: `GymMembership` (contract), `BaseRepository`, `stripId`, `COLLECTIONS`.
- Produces `MembershipRepository` methods:
  - `ensureIndexes(): Promise<void>` — unique `{ gymId, userId }`, plus `{ userId }`, `{ gymId }`.
  - `upsertJoin(m: GymMembership): Promise<GymMembership>` — insert if absent, else return existing (idempotent join).
  - `find(gymId: string, userId: string): Promise<GymMembership | null>`
  - `remove(gymId: string, userId: string): Promise<void>`
  - `listByGym(gymId: string, includeHidden: boolean): Promise<GymMembership[]>` — when `!includeHidden`, filter `visibleInRoster !== false`.
  - `listByUser(userId: string): Promise<GymMembership[]>`
  - `update(gymId: string, userId: string, patch: Partial<GymMembership>): Promise<GymMembership | null>` — no-op on empty patch (Mongo rejects empty `$set`).
  - `setHome(userId: string, gymId: string): Promise<void>` — set `isHome:true` on `{gymId,userId}`, `isHome:false` on the user's other memberships.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/membership.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MembershipRepository } from "../src/repositories/membership.repository.mts";
import type { GymMembership } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_memberships");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function m(over: Partial<GymMembership>): GymMembership {
  return {
    id: over.id ?? "m1", gymId: over.gymId ?? "g1", userId: over.userId ?? "u1",
    status: "active", verifiedMember: false, gymRole: "member",
    isHome: over.isHome ?? false, visibleInRoster: over.visibleInRoster ?? true,
    joinMethod: "self", joinedAt: "2026-07-27T00:00:00.000Z", ...over,
  };
}

describe("MembershipRepository", () => {
  it("upsertJoin is idempotent per (gym,user)", async () => {
    const repo = new MembershipRepository(db);
    await repo.ensureIndexes();
    const first = await repo.upsertJoin(m({ id: "a" }));
    const second = await repo.upsertJoin(m({ id: "b" })); // same gym+user, different id
    expect(second.id).toBe(first.id);
    const all = await repo.listByUser("u1");
    expect(all.length).toBe(1);
  });

  it("listByGym hides visibleInRoster:false unless includeHidden", async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: "v", gymId: "g2", userId: "vis", visibleInRoster: true }));
    await repo.upsertJoin(m({ id: "h", gymId: "g2", userId: "hid", visibleInRoster: false }));
    expect((await repo.listByGym("g2", false)).map((x) => x.userId)).toEqual(["vis"]);
    expect((await repo.listByGym("g2", true)).length).toBe(2);
  });

  it("setHome makes exactly one membership home for a user", async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: "h1", gymId: "gA", userId: "uH", isHome: true }));
    await repo.upsertJoin(m({ id: "h2", gymId: "gB", userId: "uH" }));
    await repo.setHome("uH", "gB");
    const list = await repo.listByUser("uH");
    expect(list.filter((x) => x.isHome).map((x) => x.gymId)).toEqual(["gB"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/membership.repository.test.mts`
Expected: FAIL — module not found. (Requires a local Mongo on 27017; the repo test suite already assumes this.)

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/membership.repository.mts
import type { Db } from "mongodb";
import type { GymMembership } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface MembershipDoc extends GymMembership {
  _id: string;
}

export class MembershipRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    await col.createIndex({ gymId: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
    await col.createIndex({ gymId: 1 });
  }

  public async upsertJoin(m: GymMembership): Promise<GymMembership> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const existing = await col.findOne({ gymId: m.gymId, userId: m.userId });
    if (existing) return stripId<GymMembership>(existing) as GymMembership;
    await col.insertOne({ ...m, _id: m.id });
    return m;
  }

  public async find(gymId: string, userId: string): Promise<GymMembership | null> {
    return stripId<GymMembership>(
      await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).findOne({ gymId, userId }),
    );
  }

  public async remove(gymId: string, userId: string): Promise<void> {
    await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).deleteOne({ gymId, userId });
  }

  public async listByGym(gymId: string, includeHidden: boolean): Promise<GymMembership[]> {
    // `visibleInRoster: { $ne: false }` also keeps legacy docs missing the field.
    const filter = includeHidden ? { gymId } : { gymId, visibleInRoster: { $ne: false } };
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).find(filter).toArray();
    return docs.map((d) => stripId<GymMembership>(d) as GymMembership);
  }

  public async listByUser(userId: string): Promise<GymMembership[]> {
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).find({ userId }).toArray();
    return docs.map((d) => stripId<GymMembership>(d) as GymMembership);
  }

  public async update(gymId: string, userId: string, patch: Partial<GymMembership>): Promise<GymMembership | null> {
    if (Object.keys(patch).length === 0) return this.find(gymId, userId);
    await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).updateOne({ gymId, userId }, { $set: patch });
    return this.find(gymId, userId);
  }

  public async setHome(userId: string, gymId: string): Promise<void> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    await col.updateMany({ userId, gymId: { $ne: gymId } }, { $set: { isHome: false } });
    await col.updateOne({ userId, gymId }, { $set: { isHome: true } });
  }
}
```

Add to `apps/api/src/db/collections.mts` inside `COLLECTIONS`:

```ts
  gymMemberships: "gymMemberships",
  beltPromotions: "beltPromotions",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/membership.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/membership.repository.mts apps/api/src/db/collections.mts apps/api/test/membership.repository.test.mts
git commit -m "feat(api): MembershipRepository with idempotent join, roster hiding, setHome"
```

---

## Task 5: `PromotionRepository`

**Files:**
- Create: `apps/api/src/repositories/promotion.repository.mts`
- Test: `apps/api/test/promotion.repository.test.mts`

**Interfaces:**
- Consumes: `BeltPromotion` (contract), `COLLECTIONS.beltPromotions` (added in Task 4).
- Produces `PromotionRepository`:
  - `ensureIndexes(): Promise<void>` — `{ userId: 1, promotedAt: -1 }`, `{ gymId: 1 }`.
  - `insert(p: BeltPromotion): Promise<BeltPromotion>`
  - `listByUser(userId: string): Promise<BeltPromotion[]>` — newest first.
  - `latestForUser(userId: string): Promise<BeltPromotion | null>`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/promotion.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { PromotionRepository } from "../src/repositories/promotion.repository.mts";
import type { BeltPromotion } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_promotions");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

function p(id: string, at: string): BeltPromotion {
  return { id, userId: "u1", gymId: "g1", beltRank: "blue", beltStripes: 0, promotedByUserId: "c1", promotedAt: at };
}

describe("PromotionRepository", () => {
  it("lists newest first and returns latest", async () => {
    const repo = new PromotionRepository(db);
    await repo.ensureIndexes();
    await repo.insert(p("old", "2020-01-01T00:00:00.000Z"));
    await repo.insert(p("new", "2026-07-27T00:00:00.000Z"));
    const list = await repo.listByUser("u1");
    expect(list[0]?.id).toBe("new");
    expect((await repo.latestForUser("u1"))?.id).toBe("new");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/promotion.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/promotion.repository.mts
import type { Db } from "mongodb";
import type { BeltPromotion } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface PromotionDoc extends BeltPromotion {
  _id: string;
}

export class PromotionRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<PromotionDoc>(COLLECTIONS.beltPromotions);
    await col.createIndex({ userId: 1, promotedAt: -1 });
    await col.createIndex({ gymId: 1 });
  }

  public async insert(p: BeltPromotion): Promise<BeltPromotion> {
    await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions).insertOne({ ...p, _id: p.id });
    return p;
  }

  public async listByUser(userId: string): Promise<BeltPromotion[]> {
    const docs = await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions)
      .find({ userId }).sort({ promotedAt: -1 }).toArray();
    return docs.map((d) => stripId<BeltPromotion>(d) as BeltPromotion);
  }

  public async latestForUser(userId: string): Promise<BeltPromotion | null> {
    const docs = await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions)
      .find({ userId }).sort({ promotedAt: -1 }).limit(1).toArray();
    return docs[0] ? (stripId<BeltPromotion>(docs[0]) as BeltPromotion) : null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/promotion.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/promotion.repository.mts apps/api/test/promotion.repository.test.mts
git commit -m "feat(api): PromotionRepository (belt history, newest-first)"
```

---

## Task 6: `MembershipFacade` (business logic + authorization)

**Files:**
- Create: `apps/api/src/facades/membership.facade.mts`
- Test: `apps/api/test/membership.facade.test.mts`

**Interfaces:**
- Consumes (via `Pick`, matching the codebase style):
  - `MembershipRepository`: `upsertJoin | find | remove | listByGym | listByUser | update | setHome`
  - `PromotionRepository`: `insert | listByUser`
  - `GymRepository`: `findById`
  - `UserRepository`: `findById | update`
  - `IdFactory = () => string`
- Produces `MembershipFacade`:
  - `join(userId: string, gymId: string): Promise<GymMembership>` — 404 if gym missing; idempotent self-join, `active`, `member`, `joinMethod:'self'`.
  - `leave(userId: string, gymId: string): Promise<void>`
  - `roster(gymId: string): Promise<RosterMember[]>` — joins user docs; hides `visibleInRoster:false`; `hasProfile:false` when user doc missing.
  - `updateMyMembership(userId, gymId, req: UpdateMyMembershipRequest): Promise<GymMembership>` — toggles `visibleInRoster`; if `isHome:true` calls `setHome` and updates `User.homeGymId`.
  - `updateMembership(callerId, gymId, targetUserId, req: UpdateMembershipRequest): Promise<GymMembership>` — **owner/coach/admin only**.
  - `promote(callerId, gymId, targetUserId, req: PromoteBeltRequest, callerRole: UserRole): Promise<BeltPromotion>` — owner/coach/admin only; no self-promote; target must be a member; writes promotion + denormalizes `User.verifiedBelt*`.
  - `listPromotions(userId: string): Promise<BeltPromotion[]>`
- Authorization helper `canManage(callerId, gymId, callerRole): Promise<boolean>` — true if `callerRole==='admin'`, or gym.ownerId===callerId, or caller has an active membership at gym with `gymRole` in `{coach, owner}`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/membership.facade.test.mts
import { describe, expect, it } from "bun:test";
import { MembershipFacade } from "../src/facades/membership.facade.mts";
import type { GymMembership, BeltPromotion, Gym, User } from "@bjj/contract";

function facade(seed?: { gymOwnerId?: string; memberships?: GymMembership[]; users?: User[] }) {
  const memberships = new Map<string, GymMembership>(); // key `${gymId}:${userId}`
  (seed?.memberships ?? []).forEach((m) => memberships.set(`${m.gymId}:${m.userId}`, m));
  const promotions: BeltPromotion[] = [];
  const users = new Map<string, User>();
  (seed?.users ?? []).forEach((u) => users.set(u.id, u));
  const gyms = new Map<string, Gym>([["g1", { id: "g1", name: "Atos", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }]]);

  const membershipRepo = {
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      const k = `${m.gymId}:${m.userId}`; const cur = memberships.get(k); if (cur) return cur;
      memberships.set(k, m); return m;
    },
    find: async (g: string, u: string): Promise<GymMembership | null> => memberships.get(`${g}:${u}`) ?? null,
    remove: async (g: string, u: string): Promise<void> => { memberships.delete(`${g}:${u}`); },
    listByGym: async (g: string, incl: boolean): Promise<GymMembership[]> =>
      [...memberships.values()].filter((m) => m.gymId === g && (incl || m.visibleInRoster !== false)),
    listByUser: async (u: string): Promise<GymMembership[]> => [...memberships.values()].filter((m) => m.userId === u),
    update: async (g: string, u: string, patch: Partial<GymMembership>): Promise<GymMembership | null> => {
      const k = `${g}:${u}`; const cur = memberships.get(k); if (!cur) return null;
      const next = { ...cur, ...patch }; memberships.set(k, next); return next;
    },
    setHome: async (u: string, g: string): Promise<void> => {
      [...memberships.values()].filter((m) => m.userId === u).forEach((m) => { m.isHome = m.gymId === g; });
    },
  };
  const promotionRepo = {
    insert: async (p: BeltPromotion): Promise<BeltPromotion> => { promotions.push(p); return p; },
    listByUser: async (u: string): Promise<BeltPromotion[]> => promotions.filter((p) => p.userId === u),
  };
  const gymRepo = { findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null };
  const userRepo = {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id); if (!cur) return null; const next = { ...cur, ...patch }; users.set(id, next); return next;
    },
  };
  let n = 0;
  return { f: new MembershipFacade(membershipRepo, promotionRepo, gymRepo, userRepo, () => `id-${n++}`), memberships, promotions, users };
}

const member = (gymId: string, userId: string, over: Partial<GymMembership> = {}): GymMembership => ({
  id: `${gymId}-${userId}`, gymId, userId, status: "active", verifiedMember: false, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "2026-07-27T00:00:00.000Z", ...over,
});

describe("MembershipFacade", () => {
  it("join is idempotent and requires an existing gym", async () => {
    const { f } = facade();
    const m1 = await f.join("u1", "g1");
    const m2 = await f.join("u1", "g1");
    expect(m2.id).toBe(m1.id);
    await expect(f.join("u1", "missing")).rejects.toMatchObject({ code: "not_found" });
  });

  it("roster hides opted-out members and flags missing profiles", async () => {
    const { f } = facade({
      memberships: [member("g1", "vis"), member("g1", "hid", { visibleInRoster: false })],
      users: [{ id: "vis", email: "v@x.co", displayName: "Vis", beltRank: "blue" }],
    });
    const roster = await f.roster("g1");
    expect(roster.map((r) => r.userId)).toEqual(["vis"]);
    expect(roster[0]?.hasProfile).toBe(true);
  });

  it("only owner/coach/admin can promote; never self", async () => {
    const owner = "owner1";
    const { f, promotions, users } = facade({
      gymOwnerId: owner,
      memberships: [member("g1", "student"), member("g1", "coach1", { gymRole: "coach" })],
      users: [{ id: "student", email: "s@x.co", displayName: "S", beltRank: "white" }],
    });
    await expect(f.promote("stranger", "g1", "student", { beltRank: "blue", beltStripes: 0 }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
    await expect(f.promote(owner, "g1", owner, { beltRank: "black", beltStripes: 0 }, "gym_owner"))
      .rejects.toMatchObject({ code: "forbidden" });
    const promo = await f.promote("coach1", "g1", "student", { beltRank: "blue", beltStripes: 2 }, "practitioner");
    expect(promo.beltRank).toBe("blue");
    expect(promotions.length).toBe(1);
    expect(users.get("student")?.verifiedBeltRank).toBe("blue");
    expect(users.get("student")?.verifiedBeltStripes).toBe(2);
    expect(users.get("student")?.verifiedByGymId).toBe("g1");
  });

  it("promote rejects a non-member target", async () => {
    const { f } = facade({ gymOwnerId: "owner1" });
    await expect(f.promote("owner1", "g1", "ghost", { beltRank: "blue", beltStripes: 0 }, "gym_owner"))
      .rejects.toMatchObject({ code: "not_found" });
  });

  it("setting a home gym updates User.homeGymId and demotes others", async () => {
    const { f, memberships, users } = facade({
      memberships: [member("g1", "u1", { isHome: true }), member("gB", "u1")],
      users: [{ id: "u1", email: "u@x.co", displayName: "U" }],
    });
    await f.updateMyMembership("u1", "gB", { isHome: true });
    expect(memberships.get("gB:u1")?.isHome).toBe(true);
    expect(memberships.get("g1:u1")?.isHome).toBe(false);
    expect(users.get("u1")?.homeGymId).toBe("gB");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/membership.facade.test.mts`
Expected: FAIL — `MembershipFacade` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/facades/membership.facade.mts
import type {
  BeltPromotion, Gym, GymMembership, RosterMember, UpdateMembershipRequest,
  UpdateMyMembershipRequest, PromoteBeltRequest, User, UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { PromotionRepository } from "../repositories/promotion.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

type IdFactory = () => string;

type MembershipRepo = Pick<MembershipRepository, "upsertJoin" | "find" | "remove" | "listByGym" | "listByUser" | "update" | "setHome">;
type PromotionRepo = Pick<PromotionRepository, "insert" | "listByUser">;
type GymRepo = Pick<GymRepository, "findById">;
type UserRepo = Pick<UserRepository, "findById" | "update">;

export class MembershipFacade {

  public constructor(
    private readonly memberships: MembershipRepo,
    private readonly promotions: PromotionRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  public async join(userId: string, gymId: string): Promise<GymMembership> {
    const gym = await this.gyms.findById(gymId);
    if (!gym) throw new AppError("not_found", `Gym ${gymId} not found`);
    const membership: GymMembership = {
      id: this.newId(), gymId, userId,
      status: "active", verifiedMember: false, gymRole: "member",
      isHome: false, visibleInRoster: true, joinMethod: "self",
      joinedAt: new Date().toISOString(), createdAt: new Date().toISOString(),
    };
    return this.memberships.upsertJoin(membership);
  }

  public async leave(userId: string, gymId: string): Promise<void> {
    await this.memberships.remove(gymId, userId);
  }

  public async roster(gymId: string): Promise<RosterMember[]> {
    const rows = await this.memberships.listByGym(gymId, false);
    const built = await Promise.all(rows.map(async (m): Promise<RosterMember> => {
      const u = await this.users.findById(m.userId);
      return {
        userId: m.userId,
        name: u?.displayName ?? "Member",
        beltRank: u?.beltRank,
        beltStripes: u?.beltStripes,
        verifiedBeltRank: u?.verifiedBeltRank,
        verifiedBeltStripes: u?.verifiedBeltStripes,
        avatarUrl: u?.avatarUrl,
        gymRole: m.gymRole ?? "member",
        verifiedMember: m.verifiedMember,
        hasProfile: u !== null,
      };
    }));
    return built;
  }

  public async updateMyMembership(userId: string, gymId: string, req: UpdateMyMembershipRequest): Promise<GymMembership> {
    const existing = await this.memberships.find(gymId, userId);
    if (!existing) throw new AppError("not_found", "Not a member of this gym");
    const patch: Partial<GymMembership> = {};
    if (req.visibleInRoster !== undefined) patch.visibleInRoster = req.visibleInRoster;
    if (req.isHome === true) {
      await this.memberships.setHome(userId, gymId);
      await this.users.update(userId, { homeGymId: gymId });
    }
    const updated = (await this.memberships.update(gymId, userId, patch)) ?? existing;
    return req.isHome === true ? { ...updated, isHome: true } : updated;
  }

  public async updateMembership(
    callerId: string, gymId: string, targetUserId: string,
    req: UpdateMembershipRequest, callerRole: UserRole,
  ): Promise<GymMembership> {
    await this.assertCanManage(callerId, gymId, callerRole);
    const target = await this.memberships.find(gymId, targetUserId);
    if (!target) throw new AppError("not_found", "Target is not a member of this gym");
    const patch: Partial<GymMembership> = {};
    if (req.verifiedMember !== undefined) patch.verifiedMember = req.verifiedMember;
    if (req.gymRole !== undefined) patch.gymRole = req.gymRole;
    return (await this.memberships.update(gymId, targetUserId, patch)) ?? target;
  }

  public async promote(
    callerId: string, gymId: string, targetUserId: string,
    req: PromoteBeltRequest, callerRole: UserRole,
  ): Promise<BeltPromotion> {
    if (callerId === targetUserId) throw new AppError("forbidden", "Cannot promote yourself");
    await this.assertCanManage(callerId, gymId, callerRole);
    const target = await this.memberships.find(gymId, targetUserId);
    if (!target) throw new AppError("not_found", "Target is not a member of this gym");
    const now = new Date().toISOString();
    const promotion: BeltPromotion = {
      id: this.newId(), userId: targetUserId, gymId,
      beltRank: req.beltRank, beltStripes: req.beltStripes,
      promotedByUserId: callerId, promotedAt: now, note: req.note,
    };
    const saved = await this.promotions.insert(promotion);
    await this.users.update(targetUserId, {
      verifiedBeltRank: req.beltRank,
      verifiedBeltStripes: req.beltStripes,
      verifiedByGymId: gymId,
      verifiedAt: now,
    });
    return saved;
  }

  public async listPromotions(userId: string): Promise<BeltPromotion[]> {
    return this.promotions.listByUser(userId);
  }

  private async assertCanManage(callerId: string, gymId: string, callerRole: UserRole): Promise<void> {
    if (callerRole === "admin") return;
    const gym: Gym | null = await this.gyms.findById(gymId);
    if (gym?.ownerId === callerId) return;
    const membership = await this.memberships.find(gymId, callerId);
    const role = membership?.gymRole ?? "member";
    if (membership && membership.status === "active" && (role === "coach" || role === "owner")) return;
    throw new AppError("forbidden", "Requires gym owner or coach");
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/membership.facade.test.mts`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/membership.facade.mts apps/api/test/membership.facade.test.mts
git commit -m "feat(api): MembershipFacade with join/roster/promote authorization"
```

---

## Task 7: `membership.routes.mts` + container + app wiring

**Files:**
- Create: `apps/api/src/routes/membership.routes.mts`
- Modify: `apps/api/src/container.mts` (build repos+facade, expose `membershipFacade`, call `ensureIndexes`), `apps/api/src/app.mts` (register routes)
- Test: `apps/api/test/membership.routes.test.mts`

**Interfaces:**
- Consumes: `container.membershipFacade`, `authPlugin`, `requireAuth`, `data`/`list`, `AppError`, request schemas from Task 3.
- Produces routes:
  - `POST /api/v1/gyms/:gymId/members` (auth) → `data(join)`
  - `DELETE /api/v1/gyms/:gymId/members/me` (auth) → `{ data: { ok: true } }`
  - `GET /api/v1/gyms/:gymId/members` (public) → `list(roster)`
  - `PATCH /api/v1/gyms/:gymId/members/me` (auth, `UpdateMyMembershipRequest`) → `data`
  - `PATCH /api/v1/gyms/:gymId/members/:userId` (auth, `UpdateMembershipRequest`) → `data`
  - `POST /api/v1/gyms/:gymId/members/:userId/promotions` (auth, `PromoteBeltRequest`) → `data`
  - `GET /api/v1/users/:userId/promotions` (public) → `list(promotions)`
  - `GET /api/v1/users/me/memberships` (auth) → `list(membershipFacade.listMyMemberships(userId))` — backs the "My gyms" screen (Task 14). Add `listMyMemberships(userId: string): Promise<GymMembership[]>` to `MembershipFacade` delegating to `memberships.listByUser(userId)`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/membership.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { membershipRoutes } from "../src/routes/membership.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

// Minimal fake container: stub verifier so a fixed bearer maps to a known identity,
// roleLookup returns practitioner, and membershipFacade records calls.
function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const membershipFacade = {
    join: async (u: string, g: string) => { calls.push(`join:${u}:${g}`); return { id: "m1", gymId: g, userId: u, status: "active", verifiedMember: false, gymRole: "member", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }; },
    leave: async (): Promise<void> => { calls.push("leave"); },
    roster: async (g: string) => { calls.push(`roster:${g}`); return []; },
    updateMyMembership: async () => ({ id: "m1", gymId: "g1", userId: "u1", status: "active", verifiedMember: false, gymRole: "member", isHome: true, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }),
    updateMembership: async () => ({ id: "m1", gymId: "g1", userId: "u2", status: "active", verifiedMember: true, gymRole: "coach", isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t" }),
    promote: async () => ({ id: "p1", userId: "u2", gymId: "g1", beltRank: "blue", beltStripes: 1, promotedByUserId: "u1", promotedAt: "t" }),
    listPromotions: async () => [],
  };
  const container = {
    verifier: { verify: async (token?: string): Promise<AuthIdentity | null> => (token ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    membershipFacade,
  } as unknown as Container;
  return { app: new Elysia().use(membershipRoutes(container)), calls };
}

const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("membership routes", () => {
  it("POST join requires auth (401 without token)", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://x/api/v1/gyms/g1/members", { method: "POST" }));
    expect(res.status).toBe(401);
  });

  it("POST join calls the facade with the caller's id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://x/api/v1/gyms/g1/members", {
      method: "POST", headers: { authorization: "Bearer t" },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("join:u1:g1");
  });

  it("GET roster is public", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://x/api/v1/gyms/g1/members"));
    expect(res.status).toBe(200);
    expect(calls).toContain("roster:g1");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/membership.routes.test.mts`
Expected: FAIL — `membershipRoutes` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/routes/membership.routes.mts
import { Elysia } from "elysia";
import { UpdateMembershipRequest, UpdateMyMembershipRequest, PromoteBeltRequest } from "@bjj/contract";
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
export function membershipRoutes(container: Container) {
  const { membershipFacade } = container;

  return new Elysia()
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/api/v1/gyms/:gymId/members",
      async ({ identity, params }) => data(await membershipFacade.join(requireId(identity).userId, params.gymId)),
      { requireAuth: true },
    )
    .delete(
      "/api/v1/gyms/:gymId/members/me",
      async ({ identity, params }) => {
        await membershipFacade.leave(requireId(identity).userId, params.gymId);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .get(
      "/api/v1/gyms/:gymId/members",
      async ({ params }) => {
        const roster = await membershipFacade.roster(params.gymId);
        return list(roster, { page: 1, limit: roster.length, total: roster.length });
      },
    )
    .patch(
      "/api/v1/gyms/:gymId/members/me",
      async ({ identity, params, body }) =>
        data(await membershipFacade.updateMyMembership(requireId(identity).userId, params.gymId, body)),
      { requireAuth: true, body: UpdateMyMembershipRequest },
    )
    .patch(
      "/api/v1/gyms/:gymId/members/:userId",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await membershipFacade.updateMembership(caller.userId, params.gymId, params.userId, body, caller.role));
      },
      { requireAuth: true, body: UpdateMembershipRequest },
    )
    .post(
      "/api/v1/gyms/:gymId/members/:userId/promotions",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await membershipFacade.promote(caller.userId, params.gymId, params.userId, body, caller.role));
      },
      { requireAuth: true, body: PromoteBeltRequest },
    )
    .get(
      "/api/v1/users/:userId/promotions",
      async ({ params }) => {
        const promotions = await membershipFacade.listPromotions(params.userId);
        return list(promotions, { page: 1, limit: promotions.length, total: promotions.length });
      },
    );
}
```

Wire the container. In `apps/api/src/container.mts`:
- import `MembershipRepository`, `PromotionRepository`, `MembershipFacade`.
- add `readonly membershipFacade: MembershipFacade;` to the `Container` interface.
- in `createContainer`, construct: `const membershipRepo = new MembershipRepository(db);` and `const promotionRepo = new PromotionRepository(db);`, then `membershipFacade: new MembershipFacade(membershipRepo, promotionRepo, gymRepo, userRepo, id),`.
- in the container's `ensureIndexes()` implementation, add `await membershipRepo.ensureIndexes(); await promotionRepo.ensureIndexes();` (follow how other repos are indexed there — read the bottom of `container.mts` first).

In `apps/api/src/app.mts`:
- import `membershipRoutes`.
- add `.use(membershipRoutes(container))` to the chain.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/membership.routes.test.mts`
Then boot check: `cd apps/api && bun test test/boot.test.mts` (proves the container + app still assemble). Then full `bun test` to catch regressions.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/routes/membership.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/membership.routes.test.mts
git commit -m "feat(api): membership routes wired into container and app"
```

---

## Task 8: OpenAPI + Postman docs refresh

**Files:**
- Modify: whatever `apps/api/src/openapi.mts` enumerates (it may auto-derive from routes; if it lists paths manually, add the new ones), and `docs/postman/` collection if present.

**Interfaces:** none (documentation only).

- [ ] **Step 1:** Read `apps/api/src/openapi.mts`. If it builds the document from the live Elysia app, the new routes are already included — just regenerate any committed `openapi.json`. If paths are hand-listed, add the seven membership paths with the request/response schemas from Tasks 2–3.
- [ ] **Step 2:** Regenerate the committed OpenAPI artifact if one exists (check `docs/` and repo root for `openapi.json`; the app also serves `/openapi.json`). Use the project's existing docs skill/command if present (`/docs`).
- [ ] **Step 3:** Run `cd apps/api && bun test` to confirm nothing broke.
- [ ] **Step 4: Commit**

```bash
git add apps/api/src/openapi.mts docs
git commit -m "docs(api): document gym membership + belt promotion endpoints"
```

---

## Task 9: Flutter models + endpoints

**Files:**
- Create: `apps/mobile/lib/features/membership/models/gym_membership.dart`, `models/belt_promotion.dart`, `models/roster_member.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/mobile/test/membership/roster_member_test.dart`

**Interfaces:**
- Produces Dart models with `fromJson` mirroring the contract shapes, and `Endpoints` helpers:
  - `gymMembers(String gymId) => '/api/v1/gyms/$gymId/members'`
  - `gymMemberMe(String gymId) => '/api/v1/gyms/$gymId/members/me'`
  - `gymMember(String gymId, String userId) => '/api/v1/gyms/$gymId/members/$userId'`
  - `gymMemberPromotions(String gymId, String userId) => '/api/v1/gyms/$gymId/members/$userId/promotions'`
  - `userPromotions(String userId) => '/api/v1/users/$userId/promotions'`

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/membership/roster_member_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';

void main() {
  test('RosterMember.fromJson maps role and verified flags', () {
    final r = RosterMember.fromJson(const {
      'userId': 'u1', 'name': 'Alice', 'beltRank': 'blue',
      'gymRole': 'coach', 'verifiedMember': true, 'hasProfile': true,
    });
    expect(r.userId, 'u1');
    expect(r.gymRole, 'coach');
    expect(r.verifiedMember, true);
    expect(r.beltRank, 'blue');
  });
}
```

> Confirm the package import prefix by checking `apps/mobile/pubspec.yaml` `name:` (used here as `bjj_open_mat`) and an existing test's imports; adjust if different.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/membership/roster_member_test.dart`
Expected: FAIL — model not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/mobile/lib/features/membership/models/roster_member.dart
class RosterMember {
  final String userId;
  final String name;
  final String? beltRank;
  final int? beltStripes;
  final String? verifiedBeltRank;
  final int? verifiedBeltStripes;
  final String? avatarUrl;
  final String gymRole;
  final bool verifiedMember;
  final bool hasProfile;

  const RosterMember({
    required this.userId,
    required this.name,
    this.beltRank,
    this.beltStripes,
    this.verifiedBeltRank,
    this.verifiedBeltStripes,
    this.avatarUrl,
    required this.gymRole,
    required this.verifiedMember,
    required this.hasProfile,
  });

  factory RosterMember.fromJson(Map<String, dynamic> json) => RosterMember(
        userId: json['userId'] as String,
        name: json['name'] as String,
        beltRank: json['beltRank'] as String?,
        beltStripes: json['beltStripes'] as int?,
        verifiedBeltRank: json['verifiedBeltRank'] as String?,
        verifiedBeltStripes: json['verifiedBeltStripes'] as int?,
        avatarUrl: json['avatarUrl'] as String?,
        gymRole: json['gymRole'] as String,
        verifiedMember: json['verifiedMember'] as bool,
        hasProfile: json['hasProfile'] as bool,
      );
}
```

Create `gym_membership.dart` and `belt_promotion.dart` the same way, mirroring the Task 2 contract fields (`GymMembership`: id, gymId, userId, status, verifiedMember, gymRole, isHome, visibleInRoster, joinMethod, joinedAt; `BeltPromotion`: id, userId, gymId, beltRank, beltStripes, promotedByUserId, promotedAt, note). Add the `Endpoints` helpers listed above under a new `// Membership` section in `core/api/endpoints.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/membership/roster_member_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/membership/models apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/membership/roster_member_test.dart
git commit -m "feat(mobile): membership models + endpoints"
```

---

## Task 10: Flutter membership repository + providers

**Files:**
- Create: `apps/mobile/lib/features/membership/data/membership_repository.dart`
- Test: `apps/mobile/test/membership/membership_repository_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider` (Dio), `unwrapList`/`unwrapData` (`core/data/api_envelope.dart`), `ApiException`, models from Task 9.
- Produces `MembershipRepository` (abstract) + `ApiMembershipRepository`:
  - `Future<GymMembership> join(String gymId)`
  - `Future<void> leave(String gymId)`
  - `Future<List<RosterMember>> roster(String gymId)`
  - `Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome})`
  - `Future<GymMembership> manageMember(String gymId, String userId, {bool? verifiedMember, String? gymRole})`
  - `Future<BeltPromotion> promote(String gymId, String userId, {required String beltRank, required int beltStripes, String? note})`
  - `Future<List<BeltPromotion>> userPromotions(String userId)`
- Providers: `membershipRepositoryProvider`, `rosterProvider = FutureProvider.family<List<RosterMember>, String>`, `userPromotionsProvider = FutureProvider.family<List<BeltPromotion>, String>`, `myMembershipsProvider` (list of the current user's memberships via `roster`? no — via `GET /users/me`? ) — for "my gyms," reuse `myMembershipsProvider` backed by a new `GET`? See note.

> **Note on "my gyms":** Task 7 defines `GET /api/v1/users/me/memberships` (backed by `MembershipFacade.listMyMemberships`). Add `Endpoints.myMemberships = '/api/v1/users/me/memberships'` in Task 9 and a `myMembershipsProvider = FutureProvider<List<GymMembership>>` here that calls it.

- [ ] **Step 1: Write the failing test** (repository parses a mocked Dio response)

```dart
// apps/mobile/test/membership/membership_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> body;
  _FakeAdapter(this.body);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      '{"data":[{"userId":"u1","name":"A","gymRole":"member","verifiedMember":false,"hasProfile":true}],"meta":{"page":1,"limit":1,"total":1}}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  test('roster parses list envelope', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _FakeAdapter(const {});
    final repo = ApiMembershipRepository(dio);
    final roster = await repo.roster('g1');
    expect(roster.single.userId, 'u1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd apps/mobile && flutter test test/membership/membership_repository_test.dart` → FAIL (module missing).
- [ ] **Step 3: Write minimal implementation** — model on `apps/mobile/lib/features/gyms/data/gym_repository.dart`: `try { final res = await _dio.get(Endpoints.gymMembers(gymId)); return unwrapList(res.data as Map<String, dynamic>).items.map(RosterMember.fromJson).toList(); } on DioException catch (e) { throw ApiException.fromDio(e); }`. Implement each method against the Task 9 endpoints; POST/PATCH send JSON bodies with only the non-null fields. Define the providers with `Provider`/`FutureProvider.family` exactly like `gymRepositoryProvider`/`gymByIdProvider`.
- [ ] **Step 4: Run test to verify it passes** — PASS.
- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/membership/data apps/mobile/test/membership/membership_repository_test.dart
git commit -m "feat(mobile): membership repository + providers"
```

---

## Task 11: Gym detail — Join/Leave button + member count

**Files:**
- Create: `apps/mobile/lib/features/membership/widgets/join_gym_button.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`
- Test: `apps/mobile/test/membership/join_gym_button_test.dart`

**Interfaces:**
- Consumes: `membershipRepositoryProvider`, `rosterProvider(gymId)` (for count), current-user/auth provider (find the existing one used by gym detail / profile — grep for how "I'm going" RSVP reads the signed-in user).
- Produces: `JoinGymButton(gymId)` — a `ConsumerWidget` that shows **Join** when the user is not in the roster and **Leave** when they are; on tap calls `join`/`leave` then invalidates `rosterProvider(gymId)`. Shows the member count from `rosterProvider`.

- [ ] **Step 1:** Write a widget test that pumps `JoinGymButton` with an overridden `membershipRepositoryProvider` (fake) + `rosterProvider` returning empty, taps it, and asserts `join` was called. Model the pump/override harness on an existing widget test under `apps/mobile/test/`.
- [ ] **Step 2:** Run `cd apps/mobile && flutter test test/membership/join_gym_button_test.dart` → FAIL.
- [ ] **Step 3:** Implement `JoinGymButton`; embed it and a "N members" label in `gym_detail_screen.dart` near the existing action row.
- [ ] **Step 4:** `flutter test test/membership/join_gym_button_test.dart` → PASS. Then `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): join/leave gym button + member count on gym detail`.

---

## Task 12: Roster screen

**Files:**
- Create: `apps/mobile/lib/features/membership/screens/roster_screen.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` (a "Members" entry/tab that opens the roster), route registration (grep for where screens are routed — e.g. a router or `Navigator.push`).
- Test: `apps/mobile/test/membership/roster_screen_test.dart`

**Interfaces:**
- Consumes: `rosterProvider(gymId)`, existing belt-icon widget (reuse the attendee/belt widget used by the open-mat attendee grid — grep `features/open_mats/widgets` and `features/profile/widgets` for the belt icon).
- Produces: `RosterScreen(gymId)` — paged/grid list of members showing name, belt icon (with a ✓ badge when `verifiedBeltRank != null`), and an Owner/Coach chip when `gymRole != 'member'`. Tapping a member with `hasProfile == true` pushes their public profile; `hasProfile == false` is non-tappable.

- [ ] **Step 1:** Widget test: override `rosterProvider(gymId)` to return one coach + one plain member; pump `RosterScreen`; assert both names render and the coach chip appears. → write test.
- [ ] **Step 2:** `flutter test test/membership/roster_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement `RosterScreen` reusing the existing belt-icon widget; add the entry point from gym detail.
- [ ] **Step 4:** `flutter test test/membership/roster_screen_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): gym roster screen with belt icons and role chips`.

---

## Task 13: Coach/owner management + Promote-belt sheet

**Files:**
- Create: `apps/mobile/lib/features/membership/widgets/promote_belt_sheet.dart`
- Modify: `apps/mobile/lib/features/membership/screens/roster_screen.dart` (manage affordance visible only to owner/coach)
- Test: `apps/mobile/test/membership/promote_belt_sheet_test.dart`

**Interfaces:**
- Consumes: `membershipRepositoryProvider.promote`, `manageMember`; the current user's manage capability — determine by reading the current user's own `RosterMember`/membership `gymRole` for this gym (from `rosterProvider`), or `User.role == 'admin'`.
- Produces: `PromoteBeltSheet(gymId, targetUserId)` — belt dropdown (white→black), stripes 0–4 selector, optional note; **Confirm** calls `promote` then invalidates `rosterProvider(gymId)` and `userPromotionsProvider(targetUserId)`. A manage affordance in the roster row that opens the sheet, plus "Confirm member" / "Make coach" actions calling `manageMember`.

- [ ] **Step 1:** Widget test: pump the sheet, pick belt=blue, stripes=2, tap Confirm, assert `promote` called with `beltRank:'blue', beltStripes:2`. Validate stripes selector caps at 4. → write test.
- [ ] **Step 2:** `flutter test test/membership/promote_belt_sheet_test.dart` → FAIL.
- [ ] **Step 3:** Implement the sheet + gate the manage affordance to owner/coach/admin.
- [ ] **Step 4:** `flutter test test/membership/promote_belt_sheet_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): promote-belt sheet + confirm-member/assign-coach actions`.

---

## Task 14: Profile — "My gyms", hide-me toggle, verified rank + history

**Files:**
- Create: `apps/mobile/lib/features/membership/screens/my_gyms_screen.dart`
- Modify: the profile screen (grep `features/profile/screens`) to add a "My gyms" entry and render verified rank (✓ + "promoted at \<gym\> on \<date\>") + a belt-history list from `userPromotionsProvider`.
- Test: `apps/mobile/test/membership/my_gyms_screen_test.dart`

**Interfaces:**
- Consumes: `myMembershipsProvider` (needs `GET /api/v1/users/me/memberships` — see Task 10 note), `gymByIdProvider` (for gym names), `membershipRepositoryProvider.updateMine`, `userPromotionsProvider(currentUserId)`.
- Produces: `MyGymsScreen` — lists the user's gyms, a radio/"Set as home" per gym (calls `updateMine(isHome:true)`), and a per-gym "Show me on roster" switch (calls `updateMine(visibleInRoster: value)`). Profile shows verified rank badge + history.

- [ ] **Step 1:** Widget test: override `myMembershipsProvider` with two memberships (one home); pump `MyGymsScreen`; toggle the hide-me switch on the non-home gym; assert `updateMine(visibleInRoster:false)` called. → write test.
- [ ] **Step 2:** `flutter test test/membership/my_gyms_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement `MyGymsScreen` + profile verified-rank/history rendering.
- [ ] **Step 4:** `flutter test test/membership/my_gyms_screen_test.dart` → PASS; `flutter analyze` clean. Run the full `cd apps/mobile && flutter test` suite.
- [ ] **Step 5: Commit** `feat(mobile): my-gyms screen, home + hide-me toggles, verified rank & history on profile`.

---

## Task 15: End-to-end verification pass

**Files:** none (verification only). Do NOT weaken any test to make this pass.

- [ ] **Step 1:** API: `cd apps/api && bun test` — full suite green (requires local Mongo on 27017 for repo tests; skip only the repo tests if no Mongo, and say so).
- [ ] **Step 2:** API boot: start the server (`cd apps/api && bun run src/index.mts` or the project's start script) and hit, with a bypass/dev token, `POST /api/v1/gyms/:id/members`, `GET /api/v1/gyms/:id/members`, `POST .../members/:userId/promotions`, `GET /api/v1/users/:userId/promotions`. Confirm envelopes and status codes. Kill any stale server on the port first (Windows Bun port-collision gotcha). A passing `bun test` is not sufficient on its own.
- [ ] **Step 3:** Mobile: `cd apps/mobile && flutter test` — full suite green; `flutter analyze` clean.
- [ ] **Step 4:** Lint: `bunx eslint --fix` across changed `apps/api` + `packages/contract` files; zero errors.
- [ ] **Step 5: Commit** any lint/fixups: `chore: lint and verification fixups for gym membership`.

---

## Self-Review Notes (author)

- **Spec coverage:** join model (Task 6/7 self-join; enums leave room for code/invite) ✓; multi-gym + one home (`isHome`/`setHome`, Task 4/6/14) ✓; belt authority owner+coach **and** confirm self-reported (promote + `updateMembership.verifiedMember`, Task 6/13) ✓; promotion history (Task 5, `GET .../promotions`, Task 14) ✓; verified vs self-reported belt split (Task 3 user fields + Task 6 denormalization) ✓; roster public + per-user hide-me (Task 4 `listByGym`, Task 6 `roster`, Task 14 toggle) ✓; server-side hidden filtering ✓; testing (service auth, roster filtering, `null!=undefined`, Flutter widget tests) ✓.
- **Open dependency:** becoming a gym `owner` relies on the existing gym-claim/lead flow; `assertCanManage` treats `Gym.ownerId === callerId` as owner so day-one promotion works. If no claim path exists, that must be closed before coach/owner features are usable — surfaced in the spec.
- **Added beyond spec, flagged:** `GET /api/v1/users/me/memberships` (Task 10 note) is needed for the "My gyms" screen; fold it into Task 7 when you reach it.
- **Type consistency:** `MembershipFacade` method names and the repo `Pick<>` sets match across Tasks 4/5/6/7; endpoint helpers in Task 9 match the routes in Task 7.
