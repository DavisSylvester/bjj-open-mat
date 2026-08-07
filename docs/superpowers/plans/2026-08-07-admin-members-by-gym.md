# Admin Members by Gym Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the admin portal's Members page from a flat, 50-row list of ObjectIds into a state → gym → member tree, with users who belong to no gym grouped under "No Gym", four status badges, a self-hidden marker, and a one-click status switcher.

**Architecture:** Three new read endpoints on the admin router. A counts-only tree (`/admin/members/tree`) is always complete, so grouping and totals are truthful; per-gym rosters and the No Gym list page beneath it. Counting happens in Mongo aggregations, not in memory. The write path is unchanged — `PATCH /admin/memberships/:gymId/:userId` already does what the switcher needs.

**Tech Stack:** Bun, Elysia, MongoDB (driver v7), TypeBox contracts in `packages/contract`, Angular 22 standalone + signals, Zard UI components, Vitest (`@angular/build:unit-test`) for admin specs, `bun test` for API.

**Spec:** `docs/superpowers/specs/2026-08-07-admin-members-by-gym-design.md`

## Global Constraints

- **Depends on PR #60** (`fix(api): require an admin identity on /api/v1/admin/*`). All three new endpoints land on the guarded admin router. Branch from `main` **after** #60 merges, or rebase onto it.
- TypeScript strict mode. **Never `any`** — use explicit types, interfaces, or `unknown`.
- Explicit return types and access modifiers on all functions/methods. Explicit types on all variables.
- Validation with **TypeBox only** (`t` from `elysia` for routes, `@sinclair/typebox` for contracts). No Zod.
- `.mts` source; import specifiers use `.mjs`.
- One interface per file in `packages/contract/src/schemas/`, barrelled via `index.mts`.
- Single quotes (admin/Angular) / double quotes (api) — match the file you're editing. Trailing commas in multiline. Named exports only.
- Backend logging via Winston (`logger`), never `console.*`. Angular may use `console.*`.
- Blank line after a class opening brace, before the first property/method.
- Validation errors normalise to **400, not 422** (`apps/api/src/http/error-handler.mts:17`).
- Run `bunx eslint --fix` on changed files after every task. Lint only files you changed — the repo has ~250 pre-existing errors in untouched files.
- `bun test` does **not** typecheck. Run `cd apps/api && bunx tsc --noEmit 2>&1 | grep -E "^src/"` separately. Baseline is **1 pre-existing error** in `src/routes/open-mat.routes.mts(73,49)` — anything beyond that is yours.
- Known pre-existing API test failures: 5 timeouts in `test/device.routes.test.mts`. Not regressions.
- API tests need mongod on `localhost:27017`.

---

## File Structure

**Contract (`packages/contract/src/schemas/`)**
- Create `admin-members.mts` — `GymSummary`, `StateGroup`, `AdminMembersTree`, `AdminRosterRow`, `NoGymUserRow`. All five are one cohesive response family for one page, so they share a file rather than fragmenting into five.
- Modify `index.mts` — barrel the new file.

**API (`apps/api/src/`)**
- Modify `repositories/membership.repository.mts` — add `countsByGym()`, `listByGymForAdmin()`.
- Modify `repositories/user.repository.mts` — add `listWithoutMemberships()`.
- Create `facades/admin-members.facade.mts` — composes gyms + counts into the tree; enriches rosters with user records. Kept out of `AdminFacade`, which already has six dependencies.
- Modify `container.mts` — construct and expose `adminMembersFacade`.
- Modify `routes/admin.routes.mts` — three new GET routes.

**API tests (`apps/api/test/`)**
- Create `admin-members-repository.test.mts` — the two aggregations against real MongoDB.
- Create `admin-members-routes.test.mts` — auth ladder + tree/roster behaviour.

**Admin (`apps/admin/src/app/`)**
- Create `core/models/admin-members.ts` + modify `core/models/index.ts`.
- Modify `core/api/admin-api.service.ts` — three new methods.
- Create `core/api/geo-api.service.ts` — reverse geocode, isolated so the members component doesn't own HTTP-and-geolocation concerns.
- Create `features/members/member-status-switcher.ts|html|scss` — the segmented control, self-contained and independently testable.
- Rewrite `features/members/members.ts|html|scss` — the tree.

**Admin tests**
- Create `core/api/geo-api.service.spec.ts`, `features/members/member-status-switcher.spec.ts`, `features/members/members.spec.ts`.

---

## Task 1: Contract schemas for the members tree

**Files:**
- Create: `packages/contract/src/schemas/admin-members.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `packages/contract/test/admin-members.test.mts`

**Interfaces:**
- Consumes: `MembershipStatus` from `../enums/membership-status.mjs`, `GymRole` from `../enums/gym-role.mjs`.
- Produces: `GymSummary`, `StateGroup`, `AdminMembersTree`, `AdminRosterRow`, `NoGymUserRow` — both TypeBox schemas and `Static` types, exported from `@bjj/contract`.

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/admin-members.test.mts`:

```ts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { AdminMembersTree, AdminRosterRow, GymSummary, NoGymUserRow } from "../src/schemas/admin-members.mts";

describe("admin members contract", () => {
  it("GymSummary requires counts and allows an absent state-bearing gym's optional fields", () => {
    const ok = { id: "g-1", name: "G", memberCount: 3, pendingCount: 1 };
    expect(Value.Check(GymSummary, ok)).toBe(true);
    expect(Value.Check(GymSummary, { ...ok, city: "Dallas", ownerId: "u-9" })).toBe(true);
    expect(Value.Check(GymSummary, { id: "g-1", name: "G" })).toBe(false);
  });

  it("AdminMembersTree carries states, noState gyms and a noGym count", () => {
    const tree = {
      states: [{ state: "TX", gyms: [{ id: "g-1", name: "G", memberCount: 1, pendingCount: 0 }] }],
      noState: [],
      noGym: { userCount: 37 },
    };
    expect(Value.Check(AdminMembersTree, tree)).toBe(true);
    expect(Value.Check(AdminMembersTree, { ...tree, noGym: {} })).toBe(false);
  });

  it("AdminRosterRow accepts all four statuses and requires the self-hide flag", () => {
    const base = {
      membershipId: "m-1", gymId: "g-1", userId: "u-1",
      displayName: "Davis", email: "d@e.dev",
      status: "pending" as const, visibleInRoster: true,
      verifiedMember: false, joinedAt: "2026-08-01T00:00:00.000Z",
    };
    for (const status of ["pending", "active", "hidden", "inactive"]) {
      expect(Value.Check(AdminRosterRow, { ...base, status })).toBe(true);
    }
    expect(Value.Check(AdminRosterRow, { ...base, status: "banned" })).toBe(false);
    const { visibleInRoster: _omitted, ...withoutFlag } = base;
    expect(Value.Check(AdminRosterRow, withoutFlag)).toBe(false);
  });

  it("NoGymUserRow carries no status field", () => {
    const row = { userId: "u-1", displayName: "Bob", email: "b@e.dev", createdAt: "2026-08-01T00:00:00.000Z" };
    expect(Value.Check(NoGymUserRow, row)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bunx bun test test/admin-members.test.mts`
Expected: FAIL — cannot resolve `../src/schemas/admin-members.mts`.

- [ ] **Step 3: Write the schemas**

Create `packages/contract/src/schemas/admin-members.mts`:

```ts
import { type Static, Type as t } from "@sinclair/typebox";
import { GymRole } from "../enums/gym-role.mjs";
import { MembershipStatus } from "../enums/membership-status.mjs";

/// A gym as it appears in the admin members tree: identity plus counts only.
/// The tree must always be complete for grouping and totals to be truthful,
/// so it deliberately carries no member rows.
export const GymSummary = t.Object(
  {
    id: t.String(),
    name: t.String(),
    city: t.Optional(t.String()),
    /// Present so the status switcher can pre-disable hidden/inactive on the
    /// owner's row instead of round-tripping to discover the server guard rail.
    ownerId: t.Optional(t.String()),
    /// Every membership regardless of status, including `pending` and legacy
    /// rows with no `status` field (treated as `active`).
    memberCount: t.Integer({ minimum: 0 }),
    pendingCount: t.Integer({ minimum: 0 }),
  },
  { $id: "GymSummary" },
);
export type GymSummary = Static<typeof GymSummary>;

export const StateGroup = t.Object(
  { state: t.String(), gyms: t.Array(GymSummary) },
  { $id: "StateGroup" },
);
export type StateGroup = Static<typeof StateGroup>;

export const AdminMembersTree = t.Object(
  {
    states: t.Array(StateGroup),
    /// `gym.state` is optional in the Gym schema, so stateless gyms are real
    /// data and need their own group rather than being dropped.
    noState: t.Array(GymSummary),
    noGym: t.Object({ userCount: t.Integer({ minimum: 0 }) }),
  },
  { $id: "AdminMembersTree" },
);
export type AdminMembersTree = Static<typeof AdminMembersTree>;

/// A roster row for the admin view: the membership joined to its user, so the
/// client never has to resolve ObjectIds itself.
export const AdminRosterRow = t.Object(
  {
    membershipId: t.String(),
    gymId: t.String(),
    userId: t.String(),
    displayName: t.String(),
    email: t.String(),
    gymRole: t.Optional(GymRole),
    status: MembershipStatus,
    /// Member-controlled self-hide. Distinct from an admin setting `hidden`,
    /// and never merged into the status badge.
    visibleInRoster: t.Boolean(),
    verifiedMember: t.Boolean(),
    joinedAt: t.String(),
    /// True when the user record could not be resolved; the UI marks the row
    /// rather than dropping it silently.
    unresolved: t.Optional(t.Boolean()),
  },
  { $id: "AdminRosterRow" },
);
export type AdminRosterRow = Static<typeof AdminRosterRow>;

/// A user with no membership anywhere. Carries no status, because there is no
/// membership to carry one.
export const NoGymUserRow = t.Object(
  {
    userId: t.String(),
    displayName: t.String(),
    email: t.String(),
    createdAt: t.String(),
  },
  { $id: "NoGymUserRow" },
);
export type NoGymUserRow = Static<typeof NoGymUserRow>;
```

- [ ] **Step 4: Barrel the new schemas**

In `packages/contract/src/schemas/index.mts`, add alongside the other exports:

```ts
export * from "./admin-members.mjs";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/contract && bunx bun test test/admin-members.test.mts`
Expected: PASS (4 tests).

Verify `GymRole`'s path first: `ls packages/contract/src/enums/`. If the file is named differently, fix the import rather than the plan.

- [ ] **Step 6: Lint and commit**

```bash
bunx eslint --fix packages/contract/src/schemas/admin-members.mts packages/contract/test/admin-members.test.mts
git add packages/contract/src/schemas/admin-members.mts packages/contract/src/schemas/index.mts packages/contract/test/admin-members.test.mts
git commit -m "feat(contract): schemas for the admin members tree"
```

---

## Task 2: Repository aggregations

**Files:**
- Modify: `apps/api/src/repositories/membership.repository.mts`
- Modify: `apps/api/src/repositories/user.repository.mts`
- Test: `apps/api/test/admin-members-repository.test.mts`

**Interfaces:**
- Consumes: `COLLECTIONS` from `../db/collections.mjs`, `BaseRepository`/`stripId` from `./base.repository.mjs`.
- Produces:
  - `MembershipRepository.countsByGym(): Promise<GymMemberCounts[]>` where `GymMemberCounts = { gymId: string; memberCount: number; pendingCount: number }` (exported from `membership.repository.mts`).
  - `MembershipRepository.listByGymForAdmin(gymId: string, skip: number, limit: number): Promise<{ items: GymMembership[]; total: number }>`
  - `UserRepository.listWithoutMemberships(skip: number, limit: number): Promise<{ items: UserType[]; total: number }>`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/admin-members-repository.test.mts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MembershipRepository } from "../src/repositories/membership.repository.mts";
import { UserRepository } from "../src/repositories/user.repository.mts";

const TEST_DB = "bjj_test_admin_members_repo";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
let memberships: MembershipRepository;
let users: UserRepository;

function membership(id: string, gymId: string, userId: string, status?: string): Record<string, unknown> {
  return {
    _id: id, id, gymId, userId,
    ...(status === undefined ? {} : { status }),
    verifiedMember: false, isHome: false, visibleInRoster: true,
    joinedAt: "2026-08-01T00:00:00.000Z",
  };
}

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("users").insertMany([
    { _id: "u-1", email: "u1@e.dev", displayName: "One", role: "practitioner", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-2", email: "u2@e.dev", displayName: "Two", role: "practitioner", createdAt: "2026-08-02T00:00:00.000Z" },
    { _id: "u-3", email: "u3@e.dev", displayName: "Three", role: "practitioner", createdAt: "2026-08-03T00:00:00.000Z" },
    { _id: "u-orphan", email: "orphan@e.dev", displayName: "Orphan", role: "practitioner", createdAt: "2026-08-04T00:00:00.000Z" },
  ] as never);
  await db.collection("gymMemberships").insertMany([
    membership("m-1", "g-1", "u-1", "active"),
    membership("m-2", "g-1", "u-2", "pending"),
    membership("m-3", "g-1", "u-3"),                 // legacy row, no status
    membership("m-4", "g-2", "u-1", "inactive"),
    membership("m-5", "g-3", "u-2", "pending"),
    membership("m-6", "g-3", "u-3", "pending"),
  ] as never);
  memberships = new MembershipRepository(db);
  users = new UserRepository(db);
});

afterAll(async () => {
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("MembershipRepository.countsByGym", () => {
  it("counts every membership including pending and status-less legacy rows", async () => {
    const rows = await memberships.countsByGym();
    const g1 = rows.find((r) => r.gymId === "g-1");
    expect(g1).toEqual({ gymId: "g-1", memberCount: 3, pendingCount: 1 });
  });

  it("counts a gym whose memberships are all pending", async () => {
    const rows = await memberships.countsByGym();
    expect(rows.find((r) => r.gymId === "g-3")).toEqual({ gymId: "g-3", memberCount: 2, pendingCount: 2 });
  });

  it("omits gyms with no memberships rather than reporting zero", async () => {
    const rows = await memberships.countsByGym();
    expect(rows.find((r) => r.gymId === "g-nonexistent")).toBeUndefined();
  });
});

describe("MembershipRepository.listByGymForAdmin", () => {
  it("includes pending rows, which listByGym excludes", async () => {
    const { items } = await memberships.listByGymForAdmin("g-1", 0, 50);
    expect(items.map((i) => i.id).sort()).toEqual(["m-1", "m-2", "m-3"]);
  });

  it("its total matches countsByGym for the same gym", async () => {
    const { total } = await memberships.listByGymForAdmin("g-1", 0, 50);
    const counts = await memberships.countsByGym();
    expect(total).toBe(counts.find((r) => r.gymId === "g-1")!.memberCount);
  });

  it("pages without overlap", async () => {
    const first = await memberships.listByGymForAdmin("g-1", 0, 2);
    const second = await memberships.listByGymForAdmin("g-1", 2, 2);
    expect(first.items).toHaveLength(2);
    expect(second.items).toHaveLength(1);
    const ids = [...first.items, ...second.items].map((i) => i.id);
    expect(new Set(ids).size).toBe(3);
  });
});

describe("UserRepository.listWithoutMemberships", () => {
  it("returns only users with zero memberships", async () => {
    const { items, total } = await users.listWithoutMemberships(0, 50);
    expect(items.map((u) => u.id)).toEqual(["u-orphan"]);
    expect(total).toBe(1);
  });

  it("excludes a user who belongs to two gyms", async () => {
    const { items } = await users.listWithoutMemberships(0, 50);
    expect(items.map((u) => u.id)).not.toContain("u-1");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bunx bun test test/admin-members-repository.test.mts`
Expected: FAIL — `countsByGym is not a function`.

- [ ] **Step 3: Implement `countsByGym` and `listByGymForAdmin`**

In `apps/api/src/repositories/membership.repository.mts`, export the counts type above the class:

```ts
export interface GymMemberCounts {
  gymId: string;
  memberCount: number;
  pendingCount: number;
}
```

Add both methods to the class, after `listAll`:

```ts
  /// Counts every membership per gym, in Mongo rather than in memory — the
  /// page needs group totals without loading every row, which is the defect
  /// this replaces. Gyms with no memberships are absent, not zero-valued.
  public async countsByGym(): Promise<GymMemberCounts[]> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const docs = await col
      .aggregate<{ _id: string; memberCount: number; pendingCount: number }>([
        {
          $group: {
            _id: "$gymId",
            memberCount: { $sum: 1 },
            pendingCount: { $sum: { $cond: [{ $eq: ["$status", "pending"] }, 1, 0] } },
          },
        },
      ])
      .toArray();
    return docs.map((d) => ({
      gymId: d._id,
      memberCount: d.memberCount,
      pendingCount: d.pendingCount,
    }));
  }

  /// Every membership for a gym, all statuses, paged.
  ///
  /// `listByGym` cannot serve the admin view: it excludes `pending` in both
  /// branches and is unpaged. Reusing it would hide pending members from the
  /// page that approves them, and its count would never reach `memberCount`,
  /// leaving the UI's "Load more" permanently visible.
  public async listByGymForAdmin(
    gymId: string,
    skip: number,
    limit: number,
  ): Promise<{ items: GymMembership[]; total: number }> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const [docs, total] = await Promise.all([
      col.find({ gymId }).sort({ joinedAt: 1, _id: 1 }).skip(skip).limit(limit).toArray(),
      col.countDocuments({ gymId }),
    ]);
    return { items: docs.map((d) => stripId<GymMembership>(d) as GymMembership), total };
  }
```

The `sort` is required: without a deterministic order, paging can repeat or skip rows across boundaries. `_id` breaks ties on equal `joinedAt`.

- [ ] **Step 4: Implement `listWithoutMemberships`**

In `apps/api/src/repositories/user.repository.mts`, add after `list`:

```ts
  /// Users with no membership in any gym. The set difference runs in Mongo;
  /// computing it client-side would require fetching every user and every
  /// membership just to subtract them.
  public async listWithoutMemberships(
    skip: number,
    limit: number,
  ): Promise<{ items: UserType[]; total: number }> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    const pipeline = [
      {
        $lookup: {
          from: COLLECTIONS.gymMemberships,
          localField: "_id",
          foreignField: "userId",
          as: "memberships",
        },
      },
      { $match: { memberships: { $size: 0 } } },
    ];
    const [docs, counted] = await Promise.all([
      col
        .aggregate<UserDoc>([
          ...pipeline,
          { $project: { memberships: 0 } },
          { $sort: { createdAt: -1, _id: 1 } },
          { $skip: skip },
          { $limit: limit },
        ])
        .toArray(),
      col.aggregate<{ total: number }>([...pipeline, { $count: "total" }]).toArray(),
    ]);
    return {
      items: docs.map((d) => stripId<UserType>(d) as UserType),
      total: counted[0]?.total ?? 0,
    };
  }
```

`$count` returns an empty array when nothing matches, hence `?? 0`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bunx bun test test/admin-members-repository.test.mts`
Expected: PASS (8 tests).

- [ ] **Step 6: Typecheck, lint, commit**

```bash
cd apps/api && bunx tsc --noEmit 2>&1 | grep -E "^src/"   # only the known open-mat.routes.mts:73 error
cd ../.. && bunx eslint --fix apps/api/src/repositories/membership.repository.mts apps/api/src/repositories/user.repository.mts apps/api/test/admin-members-repository.test.mts
git add apps/api/src/repositories/membership.repository.mts apps/api/src/repositories/user.repository.mts apps/api/test/admin-members-repository.test.mts
git commit -m "feat(api): aggregations for per-gym member counts and gymless users"
```

---

## Task 3: AdminMembersFacade

**Files:**
- Create: `apps/api/src/facades/admin-members.facade.mts`
- Modify: `apps/api/src/container.mts`
- Test: `apps/api/test/admin-members-facade.test.mts`

**Interfaces:**
- Consumes: `MembershipRepository.countsByGym`, `MembershipRepository.listByGymForAdmin`, `UserRepository.findByIds`, `UserRepository.listWithoutMemberships`, `GymFacade.list` (Task 2 + existing).
- Produces:
  - `AdminMembersFacade.tree(): Promise<AdminMembersTree>`
  - `AdminMembersFacade.gymRoster(gymId: string, skip: number, limit: number): Promise<{ items: AdminRosterRow[]; total: number }>`
  - `AdminMembersFacade.noGymUsers(skip: number, limit: number): Promise<{ items: NoGymUserRow[]; total: number }>`
- Container exposes `adminMembersFacade: AdminMembersFacade`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/admin-members-facade.test.mts`:

```ts
import { describe, expect, it } from "bun:test";
import type { Gym, GymMembership, User } from "@bjj/contract";
import { AdminMembersFacade } from "../src/facades/admin-members.facade.mts";
import type { GymMemberCounts } from "../src/repositories/membership.repository.mts";

const GYMS: Gym[] = [
  { id: "g-1", name: "Renzo Dallas", address: "A", state: "TX", city: "Dallas", amenities: [], isVerified: true, ownerId: "u-9" },
  { id: "g-2", name: "Alliance Frisco", address: "B", state: "TX", amenities: [], isVerified: false },
  { id: "g-3", name: "Nowhere BJJ", address: "C", amenities: [], isVerified: false },
  { id: "g-4", name: "Empty Gym", address: "D", state: "CA", amenities: [], isVerified: false },
];

const COUNTS: GymMemberCounts[] = [
  { gymId: "g-1", memberCount: 2, pendingCount: 1 },
  { gymId: "g-2", memberCount: 1, pendingCount: 0 },
  { gymId: "g-3", memberCount: 1, pendingCount: 0 },
];

function facade(overrides: Partial<{ memberships: unknown; users: unknown; gyms: unknown }> = {}): AdminMembersFacade {
  const memberships = {
    countsByGym: async (): Promise<GymMemberCounts[]> => COUNTS,
    listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: [], total: 0 }),
    ...(overrides.memberships as object ?? {}),
  };
  const users = {
    findByIds: async (): Promise<User[]> => [],
    listWithoutMemberships: async (): Promise<{ items: User[]; total: number }> => ({ items: [], total: 0 }),
    ...(overrides.users as object ?? {}),
  };
  const gyms = {
    list: async (): Promise<{ items: Gym[]; total: number }> => ({ items: GYMS, total: GYMS.length }),
    ...(overrides.gyms as object ?? {}),
  };
  return new AdminMembersFacade(
    memberships as never,
    users as never,
    gyms as never,
  );
}

describe("AdminMembersFacade.tree", () => {
  it("groups gyms by state and sorts states alphabetically", async () => {
    const tree = await facade().tree();
    expect(tree.states.map((s) => s.state)).toEqual(["TX"]);
    expect(tree.states[0]!.gyms.map((g) => g.name)).toEqual(["Alliance Frisco", "Renzo Dallas"]);
  });

  it("puts a gym with no state into noState", async () => {
    const tree = await facade().tree();
    expect(tree.noState.map((g) => g.id)).toEqual(["g-3"]);
  });

  it("omits gyms with no memberships entirely", async () => {
    const tree = await facade().tree();
    const allIds = [...tree.states.flatMap((s) => s.gyms), ...tree.noState].map((g) => g.id);
    expect(allIds).not.toContain("g-4");
  });

  it("carries counts and ownerId through", async () => {
    const tree = await facade().tree();
    const g1 = tree.states[0]!.gyms.find((g) => g.id === "g-1")!;
    expect(g1.memberCount).toBe(2);
    expect(g1.pendingCount).toBe(1);
    expect(g1.ownerId).toBe("u-9");
  });

  it("reports the gymless user count", async () => {
    const f = facade({
      users: { listWithoutMemberships: async (): Promise<{ items: User[]; total: number }> => ({ items: [], total: 37 }) },
    });
    expect((await f.tree()).noGym.userCount).toBe(37);
  });
});

describe("AdminMembersFacade.gymRoster", () => {
  const rows: GymMembership[] = [
    { id: "m-1", gymId: "g-1", userId: "u-1", status: "active", verifiedMember: true, isHome: true, visibleInRoster: false, joinedAt: "2026-08-01T00:00:00.000Z" } as GymMembership,
    { id: "m-2", gymId: "g-1", userId: "u-missing", status: "pending", verifiedMember: false, isHome: false, visibleInRoster: true, joinedAt: "2026-08-02T00:00:00.000Z" } as GymMembership,
  ];

  it("enriches rows with display name and email", async () => {
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: rows, total: 2 }) },
      users: { findByIds: async (): Promise<User[]> => [{ id: "u-1", email: "d@e.dev", displayName: "Davis", role: "practitioner" } as User] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items[0]!.displayName).toBe("Davis");
    expect(items[0]!.email).toBe("d@e.dev");
    expect(items[0]!.visibleInRoster).toBe(false);
  });

  it("marks an unresolvable user rather than dropping the row", async () => {
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: rows, total: 2 }) },
      users: { findByIds: async (): Promise<User[]> => [] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items).toHaveLength(2);
    expect(items[1]!.unresolved).toBe(true);
    expect(items[1]!.displayName).toBe("u-missing");
  });

  it("defaults a legacy row with no status to active", async () => {
    const legacy = [{ ...rows[0]!, status: undefined }] as GymMembership[];
    const f = facade({
      memberships: { listByGymForAdmin: async (): Promise<{ items: GymMembership[]; total: number }> => ({ items: legacy, total: 1 }) },
      users: { findByIds: async (): Promise<User[]> => [{ id: "u-1", email: "d@e.dev", displayName: "Davis", role: "practitioner" } as User] },
    });
    const { items } = await f.gymRoster("g-1", 0, 50);
    expect(items[0]!.status).toBe("active");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bunx bun test test/admin-members-facade.test.mts`
Expected: FAIL — cannot resolve `../src/facades/admin-members.facade.mts`.

- [ ] **Step 3: Implement the facade**

Create `apps/api/src/facades/admin-members.facade.mts`:

```ts
import type {
  AdminMembersTree,
  AdminRosterRow,
  GymSummary,
  NoGymUserRow,
  StateGroup,
} from "@bjj/contract";
import type { GymMemberCounts, MembershipRepository } from "../repositories/membership.repository.mjs";
import type { UserRepository } from "../repositories/user.repository.mjs";
import type { GymFacade } from "./gym.facade.mjs";

type MembershipRepo = Pick<MembershipRepository, "countsByGym" | "listByGymForAdmin">;
type UserRepo = Pick<UserRepository, "findByIds" | "listWithoutMemberships">;
type GymRepo = Pick<GymFacade, "list">;

/// Gyms are read in one page large enough to cover the directory. The tree is
/// only as complete as this read, which is the documented limit in the spec:
/// past a few thousand gyms the tree itself needs paging.
const GYM_SCAN_LIMIT = 5000;

export class AdminMembersFacade {

  public constructor(
    private readonly memberships: MembershipRepo,
    private readonly users: UserRepo,
    private readonly gyms: GymRepo,
  ) {}

  public async tree(): Promise<AdminMembersTree> {
    const [counts, gymPage, gymless] = await Promise.all([
      this.memberships.countsByGym(),
      this.gyms.list({ skip: 0, limit: GYM_SCAN_LIMIT }),
      this.users.listWithoutMemberships(0, 1),
    ]);

    const countByGymId = new Map<string, GymMemberCounts>(counts.map((c) => [c.gymId, c]));

    // Only gyms that actually have members belong here. Including all of them
    // would bury a handful of real rows under hundreds of empty ones.
    const summaries: GymSummary[] = [];
    const stateByGymId = new Map<string, string | undefined>();
    for (const gym of gymPage.items) {
      const count = countByGymId.get(gym.id);
      if (!count) continue;
      summaries.push({
        id: gym.id,
        name: gym.name,
        ...(gym.city === undefined ? {} : { city: gym.city }),
        ...(gym.ownerId === undefined ? {} : { ownerId: gym.ownerId }),
        memberCount: count.memberCount,
        pendingCount: count.pendingCount,
      });
      stateByGymId.set(gym.id, gym.state);
    }

    const byState = new Map<string, GymSummary[]>();
    const noState: GymSummary[] = [];
    for (const summary of summaries) {
      const state = stateByGymId.get(summary.id);
      if (state === undefined || state.length === 0) {
        noState.push(summary);
        continue;
      }
      const bucket = byState.get(state);
      if (bucket) bucket.push(summary);
      else byState.set(state, [summary]);
    }

    const byName = (a: GymSummary, b: GymSummary): number => a.name.localeCompare(b.name);
    const states: StateGroup[] = [...byState.entries()]
      .map(([state, gyms]): StateGroup => ({ state, gyms: [...gyms].sort(byName) }))
      .sort((a, b) => a.state.localeCompare(b.state));

    return {
      states,
      noState: noState.sort(byName),
      noGym: { userCount: gymless.total },
    };
  }

  public async gymRoster(
    gymId: string,
    skip: number,
    limit: number,
  ): Promise<{ items: AdminRosterRow[]; total: number }> {
    const { items, total } = await this.memberships.listByGymForAdmin(gymId, skip, limit);
    const users = await this.users.findByIds(items.map((m) => m.userId));
    const userById = new Map(users.map((u) => [u.id, u]));

    const rows: AdminRosterRow[] = items.map((m): AdminRosterRow => {
      const user = userById.get(m.userId);
      return {
        membershipId: m.id,
        gymId: m.gymId,
        userId: m.userId,
        // A membership pointing at a deleted user is a data error. Show the id
        // and flag it rather than dropping the row and under-reporting.
        displayName: user?.displayName ?? m.userId,
        email: user?.email ?? "",
        ...(m.gymRole === undefined ? {} : { gymRole: m.gymRole }),
        // Legacy rows predate the status field; the schema default is active.
        status: m.status ?? "active",
        visibleInRoster: m.visibleInRoster,
        verifiedMember: m.verifiedMember,
        joinedAt: m.joinedAt,
        ...(user ? {} : { unresolved: true }),
      };
    });

    return { items: rows, total };
  }

  public async noGymUsers(skip: number, limit: number): Promise<{ items: NoGymUserRow[]; total: number }> {
    const { items, total } = await this.users.listWithoutMemberships(skip, limit);
    return {
      items: items.map((u): NoGymUserRow => ({
        userId: u.id,
        displayName: u.displayName,
        email: u.email,
        createdAt: u.createdAt ?? "",
      })),
      total,
    };
  }
}
```

If `User` has no optional `createdAt`, drop the `?? ""`. Check `packages/contract/src/schemas/user.mts` before assuming.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bunx bun test test/admin-members-facade.test.mts`
Expected: PASS (8 tests).

- [ ] **Step 5: Wire into the container**

In `apps/api/src/container.mts`:

1. Import: `import { AdminMembersFacade } from "./facades/admin-members.facade.mjs";`
2. Add to the `Container` interface, next to `adminFacade` (~line 104): `readonly adminMembersFacade: AdminMembersFacade;`
3. Construct next to `adminFacade` (~line 192): `const adminMembersFacade = new AdminMembersFacade(membershipRepo, userRepo, gymFacade);`
4. Add `adminMembersFacade,` to the returned object, next to `adminFacade,` (~line 236).

- [ ] **Step 6: Typecheck, lint, commit**

```bash
cd apps/api && bunx tsc --noEmit 2>&1 | grep -E "^src/"
cd ../.. && bunx eslint --fix apps/api/src/facades/admin-members.facade.mts apps/api/src/container.mts apps/api/test/admin-members-facade.test.mts
git add apps/api/src/facades/admin-members.facade.mts apps/api/src/container.mts apps/api/test/admin-members-facade.test.mts
git commit -m "feat(api): AdminMembersFacade builds the state/gym members tree"
```

---

## Task 4: Admin routes

**Files:**
- Modify: `apps/api/src/routes/admin.routes.mts`
- Test: `apps/api/test/admin-members-routes.test.mts`

**Interfaces:**
- Consumes: `container.adminMembersFacade` (Task 3), `authPlugin` (PR #60).
- Produces: `GET /api/v1/admin/members/tree`, `GET /api/v1/admin/gyms/:gymId/members`, `GET /api/v1/admin/members/no-gym`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/admin-members-routes.test.mts`. This mirrors the two-app auth setup in `admin-routes.test.mts` — read that file first and copy its `beforeAll`/`afterAll` shape.

```ts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_admin_members_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });

const adminEnv = loadEnv({
  MONGODB_URI: uri, MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-admin",
  DEMO_USER_ID: "u-admin",
  // Not "admin": env.mts forbids it, so the role is promoted from the seeded
  // u-admin record by authPlugin's roleLookup.
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "admin@e.dev",
});
const memberEnv = loadEnv({
  MONGODB_URI: uri, MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-member",
  DEMO_USER_ID: "u-1",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "u1@e.dev",
});

const adminAuth = { Authorization: "Bearer secret-admin" };
let app: ReturnType<typeof buildApp>;
let memberApp: ReturnType<typeof buildApp>;
let base: string;
let memberBase: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection("users").insertMany([
    { _id: "u-admin", email: "admin@e.dev", displayName: "Admin", role: "admin", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-1", email: "u1@e.dev", displayName: "One", role: "practitioner", createdAt: "2026-08-01T00:00:00.000Z" },
    { _id: "u-orphan", email: "orphan@e.dev", displayName: "Orphan", role: "practitioner", createdAt: "2026-08-02T00:00:00.000Z" },
  ] as never);
  await db.collection("gyms").insertMany([
    { _id: "g-1", id: "g-1", name: "Renzo Dallas", address: "A", state: "TX", amenities: [], isVerified: true },
    { _id: "g-2", id: "g-2", name: "Nowhere BJJ", address: "B", amenities: [], isVerified: false },
    { _id: "g-3", id: "g-3", name: "Empty Gym", address: "C", state: "CA", amenities: [], isVerified: false },
  ] as never);
  await db.collection("gymMemberships").insertMany([
    { _id: "m-1", id: "m-1", gymId: "g-1", userId: "u-1", status: "pending", verifiedMember: false, isHome: false, visibleInRoster: true, joinedAt: "2026-08-01T00:00:00.000Z" },
    { _id: "m-2", id: "m-2", gymId: "g-2", userId: "u-1", status: "active", verifiedMember: false, isHome: true, visibleInRoster: true, joinedAt: "2026-08-01T00:00:00.000Z" },
  ] as never);
  app = buildApp(createContainer(db, adminEnv)).listen(0);
  memberApp = buildApp(createContainer(db, memberEnv)).listen(0);
  base = `http://localhost:${app.server?.port}`;
  memberBase = `http://localhost:${memberApp.server?.port}`;
});

afterAll(async () => {
  app.stop();
  memberApp.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

const PATHS = [
  "/api/v1/admin/members/tree",
  "/api/v1/admin/gyms/g-1/members?page=1&limit=50",
  "/api/v1/admin/members/no-gym?page=1&limit=50",
];

describe("admin members routes are guarded", () => {
  for (const path of PATHS) {
    it(`GET ${path} is 401 without a token`, async () => {
      expect((await fetch(`${base}${path}`)).status).toBe(401);
    });
    it(`GET ${path} is 403 for a practitioner`, async () => {
      const res = await fetch(`${memberBase}${path}`, { headers: { Authorization: "Bearer secret-member" } });
      expect(res.status).toBe(403);
    });
  }
});

describe("GET /api/v1/admin/members/tree", () => {
  it("groups by state, buckets a stateless gym, omits an empty gym", async () => {
    const res = await fetch(`${base}/api/v1/admin/members/tree`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { states: { state: string; gyms: { id: string; memberCount: number; pendingCount: number }[] }[]; noState: { id: string }[]; noGym: { userCount: number } } };
    expect(body.data.states.map((s) => s.state)).toEqual(["TX"]);
    expect(body.data.states[0]!.gyms[0]!.id).toBe("g-1");
    expect(body.data.states[0]!.gyms[0]!.pendingCount).toBe(1);
    expect(body.data.noState.map((g) => g.id)).toEqual(["g-2"]);
    const allIds = [...body.data.states.flatMap((s) => s.gyms.map((g) => g.id)), ...body.data.noState.map((g) => g.id)];
    expect(allIds).not.toContain("g-3");
    expect(body.data.noGym.userCount).toBe(2); // u-admin and u-orphan have no memberships
  });
});

describe("GET /api/v1/admin/gyms/:gymId/members", () => {
  it("returns pending rows enriched with the user's name", async () => {
    const res = await fetch(`${base}/api/v1/admin/gyms/g-1/members?page=1&limit=50`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string; displayName: string; status: string }[]; meta: { total: number } };
    expect(body.meta.total).toBe(1);
    expect(body.data[0]!.displayName).toBe("One");
    expect(body.data[0]!.status).toBe("pending");
  });
});

describe("GET /api/v1/admin/members/no-gym", () => {
  it("lists users with no membership anywhere", async () => {
    const res = await fetch(`${base}/api/v1/admin/members/no-gym?page=1&limit=50`, { headers: adminAuth });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string }[]; meta: { total: number } };
    expect(body.data.map((r) => r.userId).sort()).toEqual(["u-admin", "u-orphan"]);
    expect(body.meta.total).toBe(2);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bunx bun test test/admin-members-routes.test.mts`
Expected: FAIL — the three routes 404 (guard tests may pass incidentally; the tree/roster/no-gym tests must fail).

- [ ] **Step 3: Add the routes**

In `apps/api/src/routes/admin.routes.mts`, destructure the new facade at the top of `adminRoutes`:

```ts
  const { adminFacade, adminMembersFacade, gymFacade, openMatFacade } = container;
```

Add the three routes after the existing `.get("/memberships", …)` block. The instance-level `.guard({ requireAdmin: true })` from PR #60 covers them — do not add a per-route guard.

```ts
    .get("/members/tree", async () => data(await adminMembersFacade.tree()))
    .get("/gyms/:gymId/members", async ({ params, query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 50)));
      const { items, total } = await adminMembersFacade.gymRoster(params.gymId, (page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .get("/members/no-gym", async ({ query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 50)));
      const { items, total } = await adminMembersFacade.noGymUsers((page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
```

Route order matters in Elysia: register `/members/tree` and `/members/no-gym` **before** any `/members/:something` pattern. There is none today; keep it that way.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd apps/api && bunx bun test test/admin-members-routes.test.mts
cd apps/api && bunx bun test test/admin-routes.test.mts   # existing guard tests still green
```
Expected: PASS.

- [ ] **Step 5: Typecheck, lint, commit**

```bash
cd apps/api && bunx tsc --noEmit 2>&1 | grep -E "^src/"
cd ../.. && bunx eslint --fix apps/api/src/routes/admin.routes.mts apps/api/test/admin-members-routes.test.mts
git add apps/api/src/routes/admin.routes.mts apps/api/test/admin-members-routes.test.mts
git commit -m "feat(api): members tree, per-gym roster and no-gym endpoints"
```

---

## Task 5: Admin models and API service methods

**Files:**
- Create: `apps/admin/src/app/core/models/admin-members.ts`
- Modify: `apps/admin/src/app/core/models/index.ts`
- Modify: `apps/admin/src/app/core/api/admin-api.service.ts`
- Create: `apps/admin/src/app/core/api/geo-api.service.ts`
- Test: `apps/admin/src/app/core/api/admin-api.service.spec.ts` (extend), `apps/admin/src/app/core/api/geo-api.service.spec.ts` (create)

**Interfaces:**
- Consumes: the three endpoints from Task 4; `GET /api/v1/geo/reverse?lat&lng` (already exists).
- Produces:
  - `AdminApiService.getMembersTree(): Promise<AdminMembersTree>`
  - `AdminApiService.listGymMembers(gymId: string, page?: number, limit?: number): Promise<ListEnvelope<AdminRosterRow>>`
  - `AdminApiService.listNoGymUsers(page?: number, limit?: number): Promise<ListEnvelope<NoGymUserRow>>`
  - `GeoApiService.reverse(lat: number, lng: number): Promise<{ city: string; state: string; label: string }>`
  - `GeoApiService.detectState(): Promise<string | null>`

- [ ] **Step 1: Write the failing tests**

Append to `apps/admin/src/app/core/api/admin-api.service.spec.ts` (inside the existing top-level `describe`):

```ts
  describe('getMembersTree()', () => {
    it('should GET the tree endpoint and unwrap data', async () => {
      const tree = { states: [{ state: 'TX', gyms: [] }], noState: [], noGym: { userCount: 3 } };
      const promise = service.getMembersTree();
      const req = httpMock.expectOne(`${BASE}/api/v1/admin/members/tree`);
      expect(req.request.method).toBe('GET');
      req.flush({ data: tree });
      await expect(promise).resolves.toEqual(tree);
    });
  });

  describe('listGymMembers()', () => {
    it('should GET a gym roster with paging params', async () => {
      const promise = service.listGymMembers('g-1', 2, 25);
      const req = httpMock.expectOne(
        `${BASE}/api/v1/admin/gyms/g-1/members?page=2&limit=25`,
      );
      expect(req.request.method).toBe('GET');
      req.flush({ data: [], meta: { page: 2, limit: 25, total: 0 } });
      await expect(promise).resolves.toEqual({ data: [], meta: { page: 2, limit: 25, total: 0 } });
    });
  });

  describe('listNoGymUsers()', () => {
    it('should GET the no-gym endpoint', async () => {
      const promise = service.listNoGymUsers(1, 50);
      const req = httpMock.expectOne(`${BASE}/api/v1/admin/members/no-gym?page=1&limit=50`);
      req.flush({ data: [], meta: { page: 1, limit: 50, total: 0 } });
      await expect(promise).resolves.toEqual({ data: [], meta: { page: 1, limit: 50, total: 0 } });
    });
  });
```

Create `apps/admin/src/app/core/api/geo-api.service.spec.ts`:

```ts
import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

import { GeoApiService } from './geo-api.service';

const BASE = 'http://localhost:3100';

describe('GeoApiService', () => {
  let service: GeoApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting(), GeoApiService],
    });
    service = TestBed.inject(GeoApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('reverse() unwraps city and state', async () => {
    const promise = service.reverse(33.1, -96.5);
    const req = httpMock.expectOne(`${BASE}/api/v1/geo/reverse?lat=33.1&lng=-96.5`);
    req.flush({ data: { city: 'Van Alstyne', state: 'TX', label: 'Van Alstyne, TX' } });
    await expect(promise).resolves.toEqual({ city: 'Van Alstyne', state: 'TX', label: 'Van Alstyne, TX' });
  });

  it('detectState() resolves null when geolocation is denied', async () => {
    Object.defineProperty(globalThis.navigator, 'geolocation', {
      configurable: true,
      value: {
        getCurrentPosition: (_ok: PositionCallback, fail: PositionErrorCallback): void => {
          fail({ code: 1, message: 'denied' } as GeolocationPositionError);
        },
      },
    });
    await expect(service.detectState()).resolves.toBeNull();
  });

  it('detectState() resolves null when geolocation is unavailable', async () => {
    Object.defineProperty(globalThis.navigator, 'geolocation', { configurable: true, value: undefined });
    await expect(service.detectState()).resolves.toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: FAIL — `getMembersTree is not a function`, and `geo-api.service` not found.

- [ ] **Step 3: Add the models**

Create `apps/admin/src/app/core/models/admin-members.ts`:

```ts
import type { MembershipStatus } from './gym-membership';

export interface GymSummary {
  id: string;
  name: string;
  city?: string;
  ownerId?: string;
  memberCount: number;
  pendingCount: number;
}

export interface StateGroup {
  state: string;
  gyms: GymSummary[];
}

export interface AdminMembersTree {
  states: StateGroup[];
  noState: GymSummary[];
  noGym: { userCount: number };
}

export interface AdminRosterRow {
  membershipId: string;
  gymId: string;
  userId: string;
  displayName: string;
  email: string;
  gymRole?: string;
  status: MembershipStatus;
  visibleInRoster: boolean;
  verifiedMember: boolean;
  joinedAt: string;
  unresolved?: boolean;
}

export interface NoGymUserRow {
  userId: string;
  displayName: string;
  email: string;
  createdAt: string;
}
```

In `apps/admin/src/app/core/models/index.ts` add:

```ts
export type {
  GymSummary,
  StateGroup,
  AdminMembersTree,
  AdminRosterRow,
  NoGymUserRow,
} from './admin-members';
```

- [ ] **Step 4: Add the API service methods**

In `apps/admin/src/app/core/api/admin-api.service.ts`, extend the type import with `AdminMembersTree`, `AdminRosterRow`, `NoGymUserRow`, then add:

```ts
  public getMembersTree(): Promise<AdminMembersTree> {
    return firstValueFrom(
      this.http.get<DataEnvelope<AdminMembersTree>>(
        `${this.base}/api/v1/admin/members/tree`,
      ),
    ).then((res) => res.data);
  }

  public listGymMembers(
    gymId: string,
    page: number = 1,
    limit: number = 50,
  ): Promise<ListEnvelope<AdminRosterRow>> {
    return firstValueFrom(
      this.http.get<ListEnvelope<AdminRosterRow>>(
        `${this.base}/api/v1/admin/gyms/${gymId}/members`,
        { params: { page: page.toString(), limit: limit.toString() } },
      ),
    ).then((res) => ({ data: res.data, meta: res.meta }));
  }

  public listNoGymUsers(
    page: number = 1,
    limit: number = 50,
  ): Promise<ListEnvelope<NoGymUserRow>> {
    return firstValueFrom(
      this.http.get<ListEnvelope<NoGymUserRow>>(
        `${this.base}/api/v1/admin/members/no-gym`,
        { params: { page: page.toString(), limit: limit.toString() } },
      ),
    ).then((res) => ({ data: res.data, meta: res.meta }));
  }
```

- [ ] **Step 5: Add the geo service**

Create `apps/admin/src/app/core/api/geo-api.service.ts`:

```ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

import { environment } from '../../../environments/environment';
import type { DataEnvelope } from '../models';

export interface ReverseGeocode {
  city: string;
  state: string;
  label: string;
}

/**
 * Browser location, resolved to a US state via the API's geocoder.
 *
 * Kept separate from AdminApiService so the members page depends on "what
 * state am I in" rather than on geolocation plumbing, and so the denied /
 * unavailable paths can be tested without a component.
 */
@Injectable({ providedIn: 'root' })
export class GeoApiService {

  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  public reverse(lat: number, lng: number): Promise<ReverseGeocode> {
    return firstValueFrom(
      this.http.get<DataEnvelope<ReverseGeocode>>(
        `${this.base}/api/v1/geo/reverse`,
        { params: { lat: lat.toString(), lng: lng.toString() } },
      ),
    ).then((res) => res.data);
  }

  /**
   * Best-effort. Resolves null on denial, unavailability, timeout, or an
   * unrecognised location — the caller falls back to alphabetical ordering and
   * surfaces no error, because location is a convenience, not a requirement.
   */
  public async detectState(): Promise<string | null> {
    const position = await this.currentPosition();
    if (!position) return null;
    try {
      const { state } = await this.reverse(position.coords.latitude, position.coords.longitude);
      return state.length > 0 ? state : null;
    } catch {
      return null;
    }
  }

  private currentPosition(): Promise<GeolocationPosition | null> {
    if (!navigator.geolocation) return Promise.resolve(null);
    return new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition(
        (position) => resolve(position),
        () => resolve(null),
        { timeout: 10_000, maximumAge: 300_000 },
      );
    });
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: PASS.

- [ ] **Step 7: Lint and commit**

```bash
bunx eslint --fix apps/admin/src/app/core/models/admin-members.ts apps/admin/src/app/core/models/index.ts apps/admin/src/app/core/api/admin-api.service.ts apps/admin/src/app/core/api/geo-api.service.ts apps/admin/src/app/core/api/geo-api.service.spec.ts apps/admin/src/app/core/api/admin-api.service.spec.ts
git add apps/admin/src/app/core/models apps/admin/src/app/core/api
git commit -m "feat(admin): members tree models, API methods and geo state detection"
```

---

## Task 6: Status switcher component

**Files:**
- Create: `apps/admin/src/app/features/members/member-status-switcher.ts`
- Create: `apps/admin/src/app/features/members/member-status-switcher.html`
- Create: `apps/admin/src/app/features/members/member-status-switcher.scss`
- Test: `apps/admin/src/app/features/members/member-status-switcher.spec.ts`

**Interfaces:**
- Consumes: `MembershipStatus` from `@/core/models`.
- Produces: `<app-member-status-switcher>` with inputs `status: MembershipStatus`, `isOwner: boolean`, `busy: boolean`, and output `statusChange: EventEmitter<'active' | 'hidden' | 'inactive'>`.

- [ ] **Step 1: Write the failing test**

Create `apps/admin/src/app/features/members/member-status-switcher.spec.ts`:

```ts
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MemberStatusSwitcher } from './member-status-switcher';

describe('MemberStatusSwitcher', () => {
  let fixture: ComponentFixture<MemberStatusSwitcher>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({ imports: [MemberStatusSwitcher] }).compileComponents();
    fixture = TestBed.createComponent(MemberStatusSwitcher);
  });

  function segments(): HTMLButtonElement[] {
    return Array.from(fixture.nativeElement.querySelectorAll('button[data-status]'));
  }

  it('renders exactly the three settable statuses — pending is never a target', () => {
    fixture.componentRef.setInput('status', 'pending');
    fixture.detectChanges();
    expect(segments().map((b) => b.dataset['status'])).toEqual(['active', 'hidden', 'inactive']);
  });

  it('marks the current status as selected', () => {
    fixture.componentRef.setInput('status', 'hidden');
    fixture.detectChanges();
    const selected = segments().filter((b) => b.getAttribute('aria-pressed') === 'true');
    expect(selected.map((b) => b.dataset['status'])).toEqual(['hidden']);
  });

  it('selects nothing when the status is pending, so approving is an explicit act', () => {
    fixture.componentRef.setInput('status', 'pending');
    fixture.detectChanges();
    expect(segments().filter((b) => b.getAttribute('aria-pressed') === 'true')).toHaveLength(0);
  });

  it('emits the clicked status', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.detectChanges();
    const emitted: string[] = [];
    fixture.componentInstance.statusChange.subscribe((s) => emitted.push(s));
    segments().find((b) => b.dataset['status'] === 'hidden')!.click();
    expect(emitted).toEqual(['hidden']);
  });

  it('does not re-emit when the current status is clicked', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.detectChanges();
    const emitted: string[] = [];
    fixture.componentInstance.statusChange.subscribe((s) => emitted.push(s));
    segments().find((b) => b.dataset['status'] === 'active')!.click();
    expect(emitted).toEqual([]);
  });

  it('disables hidden and inactive for a gym owner but leaves active enabled', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.componentRef.setInput('isOwner', true);
    fixture.detectChanges();
    const byStatus = new Map(segments().map((b) => [b.dataset['status'], b]));
    expect(byStatus.get('hidden')!.disabled).toBe(true);
    expect(byStatus.get('inactive')!.disabled).toBe(true);
    expect(byStatus.get('active')!.disabled).toBe(false);
  });

  it('disables every segment while busy', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.componentRef.setInput('busy', true);
    fixture.detectChanges();
    expect(segments().every((b) => b.disabled)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: FAIL — cannot find `./member-status-switcher`.

- [ ] **Step 3: Implement the component**

Create `apps/admin/src/app/features/members/member-status-switcher.ts`:

```ts
import { ChangeDetectionStrategy, Component, EventEmitter, Output, input } from '@angular/core';

import type { MembershipStatus } from '@/core/models';

/** The statuses an admin may assign. Mirrors ManageableMembershipStatus in the
 *  contract: `pending` is owned by the join flow and the API rejects it. */
export type SettableStatus = 'active' | 'hidden' | 'inactive';

const SEGMENTS: readonly { value: SettableStatus; label: string }[] = [
  { value: 'active', label: 'Active' },
  { value: 'hidden', label: 'Hidden' },
  { value: 'inactive', label: 'Inactive' },
];

/**
 * Segmented status control for one membership.
 *
 * Current state and available actions are the same control, so the row reads
 * once. Clicking Active on a pending member is the approve action; pending is
 * never a target, because the API returns 400 for it.
 */
@Component({
  selector: 'app-member-status-switcher',
  standalone: true,
  templateUrl: './member-status-switcher.html',
  styleUrl: './member-status-switcher.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'data-testid': 'status-switcher' },
})
export class MemberStatusSwitcher {

  public readonly status = input.required<MembershipStatus>();
  public readonly isOwner = input<boolean>(false);
  public readonly busy = input<boolean>(false);

  @Output() public readonly statusChange = new EventEmitter<SettableStatus>();

  public readonly segments = SEGMENTS;

  public isSelected(value: SettableStatus): boolean {
    return this.status() === value;
  }

  /** A gym's owner cannot be hidden or deactivated — the server enforces this,
   *  and disabling here reports the rule instead of discovering it via a 4xx. */
  public isDisabled(value: SettableStatus): boolean {
    if (this.busy()) return true;
    return this.isOwner() && value !== 'active';
  }

  public select(value: SettableStatus): void {
    if (this.isDisabled(value) || this.isSelected(value)) return;
    this.statusChange.emit(value);
  }
}
```

Create `apps/admin/src/app/features/members/member-status-switcher.html`:

```html
<div class="switcher" role="group" aria-label="Membership status">
  @for (segment of segments; track segment.value) {
    <button
      type="button"
      class="switcher__segment"
      [class.switcher__segment--selected]="isSelected(segment.value)"
      [attr.data-status]="segment.value"
      [attr.aria-pressed]="isSelected(segment.value)"
      [disabled]="isDisabled(segment.value)"
      [attr.title]="isOwner() && segment.value !== 'active' ? 'A gym owner cannot be hidden or deactivated' : null"
      (click)="select(segment.value)"
    >
      {{ segment.label }}
    </button>
  }
</div>
```

Create `apps/admin/src/app/features/members/member-status-switcher.scss`:

```scss
.switcher {
  display: inline-flex;
  border: 1px solid var(--border, #d4d4d8);
  border-radius: 0.375rem;
  overflow: hidden;

  &__segment {
    padding: 0.25rem 0.625rem;
    font-size: 0.75rem;
    background: transparent;
    border: 0;
    border-right: 1px solid var(--border, #d4d4d8);
    cursor: pointer;

    &:last-child { border-right: 0; }

    &--selected {
      background: var(--primary, #18181b);
      color: var(--primary-foreground, #fafafa);
    }

    &:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: PASS (7 switcher tests).

- [ ] **Step 5: Lint and commit**

```bash
bunx eslint --fix apps/admin/src/app/features/members/member-status-switcher.ts apps/admin/src/app/features/members/member-status-switcher.spec.ts
git add apps/admin/src/app/features/members/member-status-switcher.*
git commit -m "feat(admin): segmented membership status switcher"
```

---

## Task 7: Members tree page

**Files:**
- Modify: `apps/admin/src/app/features/members/members.ts` (rewrite)
- Modify: `apps/admin/src/app/features/members/members.html` (rewrite)
- Modify: `apps/admin/src/app/features/members/members.scss`
- Test: `apps/admin/src/app/features/members/members.spec.ts`

**Interfaces:**
- Consumes: `AdminApiService.getMembersTree/listGymMembers/listNoGymUsers/updateMembership` (Task 5 + existing), `GeoApiService.detectState` (Task 5), `MemberStatusSwitcher` (Task 6).
- Produces: the `Members` page component (route `/members`, unchanged).

- [ ] **Step 1: Write the failing test**

Create `apps/admin/src/app/features/members/members.spec.ts`:

```ts
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Members } from './members';
import { AdminApiService } from '@/core/api/admin-api.service';
import { GeoApiService } from '@/core/api/geo-api.service';
import type { AdminMembersTree, AdminRosterRow } from '@/core/models';

const TREE: AdminMembersTree = {
  states: [
    { state: 'CA', gyms: [{ id: 'g-ca', name: 'Cali BJJ', memberCount: 1, pendingCount: 0 }] },
    { state: 'TX', gyms: [{ id: 'g-tx', name: 'Renzo Dallas', memberCount: 2, pendingCount: 1, ownerId: 'u-owner' }] },
  ],
  noState: [{ id: 'g-none', name: 'Nowhere BJJ', memberCount: 1, pendingCount: 0 }],
  noGym: { userCount: 3 },
};

function row(over: Partial<AdminRosterRow> = {}): AdminRosterRow {
  return {
    membershipId: 'm-1', gymId: 'g-tx', userId: 'u-1',
    displayName: 'Davis', email: 'd@e.dev',
    status: 'active', visibleInRoster: true, verifiedMember: false,
    joinedAt: '2026-08-01T00:00:00.000Z',
    ...over,
  };
}

function setup(opts: { state?: string | null; api?: Partial<AdminApiService> } = {}): ComponentFixture<Members> {
  const api: Partial<AdminApiService> = {
    getMembersTree: async () => TREE,
    listGymMembers: async () => ({ data: [row()], meta: { page: 1, limit: 50, total: 2 } }),
    listNoGymUsers: async () => ({ data: [], meta: { page: 1, limit: 50, total: 3 } }),
    updateMembership: async () => ({}) as never,
    ...opts.api,
  };
  TestBed.configureTestingModule({
    imports: [Members],
    providers: [
      { provide: AdminApiService, useValue: api },
      { provide: GeoApiService, useValue: { detectState: async () => opts.state ?? null } },
    ],
  });
  return TestBed.createComponent(Members);
}

async function settle(fixture: ComponentFixture<Members>): Promise<void> {
  fixture.detectChanges();
  await fixture.whenStable();
  fixture.detectChanges();
}

describe('Members page', () => {
  it('orders the detected state first, then the rest alphabetically', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['TX', 'CA']);
  });

  it('expands the detected state and only that one', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.isStateExpanded('TX')).toBe(true);
    expect(fixture.componentInstance.isStateExpanded('CA')).toBe(false);
  });

  it('falls back to alphabetical with nothing expanded when location is denied', async () => {
    const fixture = setup({ state: null });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['CA', 'TX']);
    expect(fixture.componentInstance.isStateExpanded('CA')).toBe(false);
    expect(fixture.componentInstance.error()).toBeNull();
  });

  it('ignores a detected state that matches no group', async () => {
    const fixture = setup({ state: 'ZZ' });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['CA', 'TX']);
  });

  it('loads a gym roster on expand and appends on load-more', async () => {
    let call = 0;
    const fixture = setup({
      state: 'TX',
      api: {
        listGymMembers: async () => {
          call += 1;
          return call === 1
            ? { data: [row({ membershipId: 'm-1' })], meta: { page: 1, limit: 1, total: 2 } }
            : { data: [row({ membershipId: 'm-2', userId: 'u-2' })], meta: { page: 2, limit: 1, total: 2 } };
        },
      },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleGym('g-tx');
    await settle(fixture);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1']);
    expect(fixture.componentInstance.hasMore('g-tx', 2)).toBe(true);

    await fixture.componentInstance.loadMore('g-tx');
    await settle(fixture);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1', 'm-2']);
    expect(fixture.componentInstance.hasMore('g-tx', 2)).toBe(false);
  });

  it('rolls back and records a row error when the status update fails', async () => {
    const fixture = setup({
      state: 'TX',
      api: { updateMembership: async () => { throw new Error('nope'); } },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleGym('g-tx');
    await settle(fixture);

    await fixture.componentInstance.setStatus('g-tx', fixture.componentInstance.rowsFor('g-tx')[0]!, 'hidden');
    await settle(fixture);

    expect(fixture.componentInstance.rowsFor('g-tx')[0]!.status).toBe('active');
    expect(fixture.componentInstance.rowError('m-1')).not.toBeNull();
  });

  it('treats the gym owner row as owner-locked', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.isOwnerRow('g-tx', row({ userId: 'u-owner' }))).toBe(true);
    expect(fixture.componentInstance.isOwnerRow('g-tx', row({ userId: 'u-1' }))).toBe(false);
  });

  it('exposes the no-gym count from the tree', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.noGymCount()).toBe(3);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: FAIL — `orderedStates is not a function`.

- [ ] **Step 3: Rewrite the component**

Replace `apps/admin/src/app/features/members/members.ts` entirely:

```ts
import { HttpErrorResponse } from '@angular/common/http';
import type { OnInit } from '@angular/core';
import { Component, computed, inject, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import { GeoApiService } from '@/core/api/geo-api.service';
import type {
  AdminMembersTree,
  AdminRosterRow,
  GymSummary,
  NoGymUserRow,
  StateGroup,
} from '@/core/models';
import { ZardBadgeComponent, type ZardBadgeTypeVariants } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { MemberStatusSwitcher, type SettableStatus } from './member-status-switcher';

const PAGE_SIZE = 50;
const DEFAULT_UPDATE_ERROR = 'Could not update that member. Please try again.';

function isHttpErrorResponse(err: unknown): err is HttpErrorResponse {
  return err instanceof HttpErrorResponse;
}

/**
 * Narrows an unknown thrown value down to the API's error envelope
 * (`{ error: { code, message, details? } }`) and extracts its message,
 * falling back to a generic message when the shape doesn't match.
 */
function extractErrorMessage(err: unknown): string {
  if (!isHttpErrorResponse(err)) return DEFAULT_UPDATE_ERROR;
  const body: unknown = err.error;
  if (typeof body !== 'object' || body === null || !('error' in body)) return DEFAULT_UPDATE_ERROR;
  const inner: unknown = (body as { error: unknown }).error;
  if (typeof inner !== 'object' || inner === null || !('message' in inner)) return DEFAULT_UPDATE_ERROR;
  const message: unknown = (inner as { message: unknown }).message;
  return typeof message === 'string' && message.length > 0 ? message : DEFAULT_UPDATE_ERROR;
}

@Component({
  selector: 'app-members',
  standalone: true,
  imports: [
    ZardBadgeComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    MemberStatusSwitcher,
  ],
  templateUrl: './members.html',
  styleUrl: './members.scss',
  host: { 'data-testid': 'members-page' },
})
export class Members implements OnInit {

  private readonly api = inject(AdminApiService);
  private readonly geo = inject(GeoApiService);

  public readonly tree = signal<AdminMembersTree | null>(null);
  public readonly loading = signal<boolean>(true);
  public readonly error = signal<string | null>(null);
  public readonly detectedState = signal<string | null>(null);

  private readonly expandedStates = signal<ReadonlySet<string>>(new Set<string>());
  private readonly expandedGyms = signal<ReadonlySet<string>>(new Set<string>());
  private readonly rows = signal<ReadonlyMap<string, AdminRosterRow[]>>(new Map());
  private readonly pages = signal<ReadonlyMap<string, number>>(new Map());
  private readonly busyRows = signal<ReadonlySet<string>>(new Set<string>());
  private readonly rowErrors = signal<ReadonlyMap<string, string>>(new Map());
  private readonly groupErrors = signal<ReadonlyMap<string, string>>(new Map());

  public readonly noGymUsers = signal<NoGymUserRow[]>([]);

  public readonly noGymCount = computed<number>(() => this.tree()?.noGym.userCount ?? 0);
  public readonly noStateGyms = computed<GymSummary[]>(() => this.tree()?.noState ?? []);

  /**
   * Detected state first, everything else alphabetically. Detection only
   * changes order and which group starts open — no group is ever hidden, so a
   * wrong or missing detection costs nothing but a scroll.
   */
  public readonly orderedStates = computed<StateGroup[]>(() => {
    const groups: StateGroup[] = [...(this.tree()?.states ?? [])];
    groups.sort((a, b) => a.state.localeCompare(b.state));
    const detected: string | null = this.detectedState();
    if (detected === null) return groups;
    const index: number = groups.findIndex((g) => g.state === detected);
    if (index < 0) return groups;
    const [match] = groups.splice(index, 1);
    return match ? [match, ...groups] : groups;
  });

  public async ngOnInit(): Promise<void> {
    await this.load();
  }

  public isStateExpanded(state: string): boolean {
    return this.expandedStates().has(state);
  }

  public isGymExpanded(gymId: string): boolean {
    return this.expandedGyms().has(gymId);
  }

  public rowsFor(gymId: string): AdminRosterRow[] {
    return this.rows().get(gymId) ?? [];
  }

  public hasMore(gymId: string, memberCount: number): boolean {
    return this.rowsFor(gymId).length < memberCount;
  }

  public isRowBusy(membershipId: string): boolean {
    return this.busyRows().has(membershipId);
  }

  public rowError(membershipId: string): string | null {
    return this.rowErrors().get(membershipId) ?? null;
  }

  public groupError(gymId: string): string | null {
    return this.groupErrors().get(gymId) ?? null;
  }

  public isOwnerRow(gymId: string, row: AdminRosterRow): boolean {
    const gym: GymSummary | undefined = this.findGym(gymId);
    return gym?.ownerId !== undefined && gym.ownerId === row.userId;
  }

  public badgeType(status: AdminRosterRow['status']): ZardBadgeTypeVariants {
    if (status === 'active') return 'default';
    if (status === 'inactive') return 'destructive';
    if (status === 'pending') return 'secondary';
    return 'outline';
  }

  public toggleState(state: string): void {
    this.expandedStates.update((set) => toggle(set, state));
  }

  public async toggleGym(gymId: string): Promise<void> {
    const wasExpanded: boolean = this.isGymExpanded(gymId);
    this.expandedGyms.update((set) => toggle(set, gymId));
    if (wasExpanded || this.rows().has(gymId)) return;
    await this.fetchPage(gymId, 1);
  }

  public async loadMore(gymId: string): Promise<void> {
    const next: number = (this.pages().get(gymId) ?? 1) + 1;
    await this.fetchPage(gymId, next);
  }

  public async toggleNoGym(): Promise<void> {
    const wasExpanded: boolean = this.isGymExpanded('__no_gym__');
    this.expandedGyms.update((set) => toggle(set, '__no_gym__'));
    if (wasExpanded || this.noGymUsers().length > 0) return;
    const envelope = await this.api.listNoGymUsers(1, PAGE_SIZE);
    this.noGymUsers.set(envelope.data);
  }

  /**
   * Optimistic: the row moves immediately and reverts if the API rejects it.
   * The error lands on the row rather than the page, because one member's
   * failed toggle is not a broken page.
   */
  public async setStatus(gymId: string, row: AdminRosterRow, status: SettableStatus): Promise<void> {
    if (this.isRowBusy(row.membershipId)) return;
    const previous: AdminRosterRow['status'] = row.status;

    this.busyRows.update((s) => addToSet(s, row.membershipId));
    this.rowErrors.update((map) => withoutEntry(map, row.membershipId));
    this.patchRow(gymId, row.membershipId, { status });

    try {
      await this.api.updateMembership(gymId, row.userId, { status });
    } catch (err) {
      this.patchRow(gymId, row.membershipId, { status: previous });
      this.rowErrors.update((map) => withEntry(map, row.membershipId, extractErrorMessage(err)));
    } finally {
      this.busyRows.update((s) => removeFromSet(s, row.membershipId));
    }
  }

  public async retryTree(): Promise<void> {
    await this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const tree: AdminMembersTree = await this.api.getMembersTree();
      this.tree.set(tree);
      // Detection runs after the tree so the page never waits on the browser's
      // permission prompt to render.
      void this.applyDetectedState();
    } catch (err) {
      this.error.set(extractErrorMessage(err));
    } finally {
      this.loading.set(false);
    }
  }

  private async applyDetectedState(): Promise<void> {
    const state: string | null = await this.geo.detectState();
    if (state === null) return;
    const known: boolean = (this.tree()?.states ?? []).some((g) => g.state === state);
    if (!known) return;
    this.detectedState.set(state);
    this.expandedStates.update((s) => addToSet(s, state));
  }

  private async fetchPage(gymId: string, page: number): Promise<void> {
    this.groupErrors.update((map) => withoutEntry(map, gymId));
    try {
      const envelope = await this.api.listGymMembers(gymId, page, PAGE_SIZE);
      this.rows.update((map) => {
        const next = new Map(map);
        next.set(gymId, [...(map.get(gymId) ?? []), ...envelope.data]);
        return next;
      });
      this.pages.update((map) => new Map(map).set(gymId, page));
    } catch (err) {
      this.groupErrors.update((map) => withEntry(map, gymId, extractErrorMessage(err)));
    }
  }

  private patchRow(gymId: string, membershipId: string, patch: Partial<AdminRosterRow>): void {
    this.rows.update((map) => {
      const current: AdminRosterRow[] = map.get(gymId) ?? [];
      const next = new Map(map);
      next.set(gymId, current.map((r) => (r.membershipId === membershipId ? { ...r, ...patch } : r)));
      return next;
    });
  }

  private findGym(gymId: string): GymSummary | undefined {
    const t: AdminMembersTree | null = this.tree();
    if (!t) return undefined;
    for (const group of t.states) {
      const found: GymSummary | undefined = group.gyms.find((g) => g.id === gymId);
      if (found) return found;
    }
    return t.noState.find((g) => g.id === gymId);
  }
}

// Sets and maps are replaced rather than mutated, so signal `update` always
// sees a new reference. Separate helpers per container type — one generic
// `remove` cannot be typed across both a Set and a Map.
function toggle(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  const next = new Set(current);
  if (!next.delete(key)) next.add(key);
  return next;
}

function addToSet(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  return new Set(current).add(key);
}

function removeFromSet(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  const next = new Set(current);
  next.delete(key);
  return next;
}

function withEntry(
  current: ReadonlyMap<string, string>,
  key: string,
  value: string,
): ReadonlyMap<string, string> {
  return new Map(current).set(key, value);
}

function withoutEntry(
  current: ReadonlyMap<string, string>,
  key: string,
): ReadonlyMap<string, string> {
  const next = new Map(current);
  next.delete(key);
  return next;
}
```

- [ ] **Step 4: Rewrite the template**

Replace `apps/admin/src/app/features/members/members.html`:

```html
@if (loading()) {
  <div class="members-loading">
    <z-spinner class="size-8" />
    <span>Loading…</span>
  </div>
} @else if (error()) {
  <div class="members-error-wrapper">
    <p class="members-error" data-testid="members-error">{{ error() }}</p>
    <button type="button" class="row-action" (click)="retryTree()">Retry</button>
  </div>
} @else if (!tree()) {
  <div class="members-empty-wrapper" data-testid="members-empty">
    <z-empty zIcon="lucideUsers" zTitle="No members found" zDescription="There are no memberships to display yet." />
  </div>
} @else {
  <div class="members-container">
    <h1 class="members-title">Members</h1>
    @if (detectedState()) {
      <p class="members-detected" data-testid="members-detected">Showing {{ detectedState() }} first, based on your location.</p>
    }

    @for (group of orderedStates(); track group.state) {
      <section class="state-group" data-testid="state-group" [attr.data-state]="group.state">
        <button type="button" class="state-header" (click)="toggleState(group.state)">
          <span>{{ group.state }}</span>
          <span class="muted">{{ group.gyms.length }} gyms</span>
        </button>

        @if (isStateExpanded(group.state)) {
          @for (gym of group.gyms; track gym.id) {
            <ng-container *ngTemplateOutlet="gymBlock; context: { $implicit: gym }" />
          }
        }
      </section>
    }

    @if (noStateGyms().length > 0) {
      <section class="state-group" data-testid="state-group" data-state="(No State)">
        <button type="button" class="state-header" (click)="toggleState('__no_state__')">
          <span>(No State)</span>
          <span class="muted">{{ noStateGyms().length }} gyms</span>
        </button>
        @if (isStateExpanded('__no_state__')) {
          @for (gym of noStateGyms(); track gym.id) {
            <ng-container *ngTemplateOutlet="gymBlock; context: { $implicit: gym }" />
          }
        }
      </section>
    }

    <section class="state-group" data-testid="no-gym-group">
      <button type="button" class="state-header" (click)="toggleNoGym()">
        <span>No Gym</span>
        <span class="muted">{{ noGymCount() }} users</span>
      </button>
      @if (isGymExpanded('__no_gym__')) {
        <table class="roster">
          <tbody>
            @for (user of noGymUsers(); track user.userId) {
              <tr data-testid="no-gym-row">
                <td>{{ user.displayName }}</td>
                <td class="muted">{{ user.email }}</td>
                <td class="muted">{{ user.createdAt }}</td>
              </tr>
            }
          </tbody>
        </table>
      }
    </section>
  </div>

  <ng-template #gymBlock let-gym>
    <div class="gym-block">
      <button type="button" class="gym-header" data-testid="gym-header" [attr.data-gym]="gym.id" (click)="toggleGym(gym.id)">
        <span>{{ gym.name }}</span>
        @if (gym.city) { <span class="muted">{{ gym.city }}</span> }
        <span class="muted">{{ gym.memberCount }} members</span>
        @if (gym.pendingCount > 0) {
          <z-badge zType="secondary" data-testid="gym-pending">{{ gym.pendingCount }} pending</z-badge>
        }
      </button>

      @if (isGymExpanded(gym.id)) {
        @if (groupError(gym.id)) {
          <p class="members-error" data-testid="group-error">{{ groupError(gym.id) }}</p>
        }
        <table class="roster">
          <tbody>
            @for (row of rowsFor(gym.id); track row.membershipId) {
              <tr data-testid="member-row">
                <td>
                  {{ row.displayName }}
                  @if (row.unresolved) { <span class="warn" title="User record not found">⚠</span> }
                </td>
                <td class="muted">{{ row.email }}</td>
                <td>
                  @if (row.gymRole) { <z-badge zType="outline">{{ row.gymRole }}</z-badge> }
                </td>
                <td>
                  <z-badge [zType]="badgeType(row.status)" data-testid="member-status">{{ row.status }}</z-badge>
                  @if (!row.visibleInRoster) {
                    <span class="self-hidden" data-testid="member-self-hidden" title="This member hid themselves from the roster">self-hidden</span>
                  }
                </td>
                <td>
                  <app-member-status-switcher
                    [status]="row.status"
                    [isOwner]="isOwnerRow(gym.id, row)"
                    [busy]="isRowBusy(row.membershipId)"
                    (statusChange)="setStatus(gym.id, row, $event)"
                  />
                  @if (rowError(row.membershipId)) {
                    <span class="row-error" data-testid="row-error">{{ rowError(row.membershipId) }}</span>
                  }
                </td>
              </tr>
            }
          </tbody>
        </table>

        @if (hasMore(gym.id, gym.memberCount)) {
          <button type="button" class="row-action" data-testid="load-more" (click)="loadMore(gym.id)">
            Load more ({{ rowsFor(gym.id).length }} of {{ gym.memberCount }})
          </button>
        }
      }
    </div>
  </ng-template>
}
```

`*ngTemplateOutlet` requires `NgTemplateOutlet` in the component's `imports` — add `import { NgTemplateOutlet } from '@angular/common';` and list it. If you prefer to avoid the outlet, inline the gym block twice; the outlet is here to keep it DRY.

- [ ] **Step 5: Extend the stylesheet**

Append to `apps/admin/src/app/features/members/members.scss`:

```scss
.state-group { margin-bottom: 1rem; }

.state-header,
.gym-header {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  width: 100%;
  padding: 0.5rem 0.75rem;
  background: transparent;
  border: 0;
  border-bottom: 1px solid var(--border, #e4e4e7);
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}

.gym-header { padding-left: 1.5rem; font-weight: 500; }
.gym-block { margin-bottom: 0.5rem; }

.roster {
  width: 100%;
  border-collapse: collapse;

  td { padding: 0.375rem 0.75rem 0.375rem 2.25rem; }
}

.muted { color: var(--muted-foreground, #71717a); font-weight: 400; font-size: 0.8125rem; }
.warn { color: var(--destructive, #dc2626); margin-left: 0.25rem; }

.self-hidden {
  margin-left: 0.375rem;
  font-size: 0.6875rem;
  color: var(--muted-foreground, #71717a);
}

.row-error {
  display: block;
  margin-top: 0.25rem;
  font-size: 0.75rem;
  color: var(--destructive, #dc2626);
}

.members-detected { color: var(--muted-foreground, #71717a); font-size: 0.8125rem; }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd apps/admin && bunx ng test --watch=false`
Expected: PASS (all Members page tests plus the earlier suites).

- [ ] **Step 7: Build, lint, commit**

```bash
cd apps/admin && bunx ng build --configuration production
cd ../.. && bunx eslint --fix apps/admin/src/app/features/members/members.ts apps/admin/src/app/features/members/members.spec.ts
git add apps/admin/src/app/features/members
git commit -m "feat(admin): members grouped by state and gym with status switcher"
```

---

## Task 8: Full verification and docs

**Files:**
- Modify: `docs/FEATURE-LOG.md`

- [ ] **Step 1: Run every gate**

```bash
cd apps/api && bunx bun test 2>&1 | tail -5
cd apps/api && bunx tsc --noEmit 2>&1 | grep -E "^src/"
cd apps/admin && bunx ng test --watch=false
cd apps/admin && bunx ng build --configuration production
```

Expected: API suite green except the 5 known `device.routes` timeouts; `tsc` shows only the known `open-mat.routes.mts:73` error; admin tests pass; admin builds.

- [ ] **Step 2: Add the feature-log entry**

In `docs/FEATURE-LOG.md`, add a new entry under **Unreleased** *above* the Gym Search entry, following the template at the bottom of that file. Cover: members grouped by state and gym, No Gym group, names instead of ObjectIds, four status badges, self-hidden marker, one-click switcher, paging that reaches every member. Note under **Internal** that `/admin/*` now requires an admin identity (PR #60) and that the portal is still local-only.

This page is admin-only, so it does not belong in App Store or Play release notes — mark the user-visible lines as internal-tooling in the entry so the release-notes pass skips them.

- [ ] **Step 3: Commit**

```bash
git add docs/FEATURE-LOG.md
git commit -m "docs: log the admin members-by-gym rework"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| Three endpoints | 4 |
| `countsByGym`, `listWithoutMemberships`, `listByGymForAdmin` | 2 |
| `AdminMembersFacade`, tree shape, `(No State)`, gyms-with-members only, `ownerId` | 3 |
| Enriched roster rows, unresolved-user marker, legacy status default | 3 |
| State ordering + GPS default + non-blocking fallback | 5 (detection), 7 (ordering) |
| Four badges, self-hidden marker, No Gym rows without controls | 7 |
| Segmented switcher, pending-as-approve, owner lock | 6 |
| Paging, `Load more`, counts from the tree | 7 |
| Optimistic update + rollback, per-row errors, group/page errors | 7 |
| API repository + route tests | 2, 4 |
| Admin component tests | 5, 6, 7 |
| Non-goal: Auth0/hosting | excluded throughout; noted in Task 8 |

**Placeholder scan:** No TBD/TODO. Every code step carries real code. The one deliberate instruction-without-code is Task 8 Step 2, which is prose content for a log file, with the required subject matter enumerated.

**Type consistency:** `AdminMembersTree`, `GymSummary`, `StateGroup`, `AdminRosterRow`, `NoGymUserRow` are defined in Task 1 and used identically in Tasks 3, 4, 5, 7. `GymMemberCounts` is defined in Task 2 and consumed in Task 3. `SettableStatus` is defined in Task 6 and consumed in Task 7's `setStatus`. `AdminApiService.updateMembership(gymId, userId, { status })` matches the existing signature. The signal helpers in Task 7 (`toggle`, `addToSet`, `removeFromSet`, `withEntry`, `withoutEntry`) are each used with the container type they are declared for — sets for `expandedStates`/`expandedGyms`/`busyRows`, maps for `rowErrors`/`groupErrors`.

**Fixed during review:** the first draft of Task 7 declared a single `remove` helper that could not type-check against both a `Set` and a `Map`, then corrected it in prose. A plan that ships known-broken code and relies on the reader noticing the follow-up is a plan defect, so the helpers are now correct in the only place they appear.
