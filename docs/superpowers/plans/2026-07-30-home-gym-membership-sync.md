# Home Gym / Membership Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Setting a home gym on the profile screen also joins that gym, so the roster stops disagreeing with the profile.

**Architecture:** `MembershipFacade` gains one composed method, `ensureHome`. `UserFacade` calls it when a profile patch changes `homeGymId`. A one-off script backfills the users who already diverged. No mobile changes.

**Tech Stack:** Bun, Elysia, TypeBox, MongoDB.

**Spec:** `docs/superpowers/specs/2026-07-30-home-gym-membership-sync-design.md`

**Branch:** `feature/home-gym-membership-sync` (already created; spec committed as `9c5c404`)

## Global Constraints

- TypeScript strict. **Never use `any`** — this holds in test files too. Explicit return types and access modifiers on all methods. Explicit types on all variables.
- Validation uses TypeBox. Never Zod.
- Layering: router handles HTTP only → facade holds business logic → repository owns data access.
- Services resolve through the DI container (`apps/api/src/container.mts`). No `new` inside facades or routes.
- Conventional commits. **Never add Co-Authored-By lines.**
- `bunx eslint --fix` on changed `.mts` files must end clean.
- `bun test` must pass. Run it as `TEST_MONGODB_URI="mongodb://localhost:27021" bun test` from `apps/api` — a preload pins tests to a local database, and this repo's local Mongo container maps host port **27021**. Baseline is **253 passing**; each task should raise it, never lower it.
- **Dependency direction is one-way.** `MembershipFacade` depends on the user *repository*, not `UserFacade`. Adding `UserFacade → MembershipFacade` creates no cycle. Do not introduce the reverse edge.
- Existing interfaces you will consume, verbatim:
  - `MembershipFacade.join(userId: string, gymId: string): Promise<GymMembership>` (`membership.facade.mts:40`) — already throws `AppError('not_found')` for an unknown gym and already uses `upsertJoin`, so it is idempotent.
  - `MembershipRepository.setHome(userId: string, gymId: string): Promise<void>` (`membership.repository.mts:60`)
  - `MembershipRepository.find(gymId: string, userId: string): Promise<GymMembership | null>`
  - `UserFacade.updateProfile(id: string, patch: UpdateUserRequest, isSocialUser = false): Promise<User>` (`user.facade.mts:61`)
  - `UserRepository.findById(id: string): Promise<User | null>`

---

### Task 1: `MembershipFacade.ensureHome`

**Files:**
- Modify: `apps/api/src/facades/membership.facade.mts`
- Test: `apps/api/test/membership-ensure-home.test.mts` (create)

**Interfaces:**
- Consumes: `MembershipFacade.join`, `MembershipRepository.find`, `MembershipRepository.setHome`
- Produces: `MembershipFacade.ensureHome(userId: string, gymId: string): Promise<void>`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/membership-ensure-home.test.mts`:

```typescript
import { describe, expect, test } from "bun:test";
import type { GymMembership } from "@bjj/contract";
import { MembershipFacade } from "../src/facades/membership.facade.mts";
import { AppError } from "../src/http/errors.mts";

interface Calls {
  readonly upserts: GymMembership[];
  readonly setHomes: { userId: string; gymId: string }[];
}

function makeFacade(opts: { existing?: GymMembership | null; gymExists?: boolean }): {
  facade: MembershipFacade;
  calls: Calls;
} {
  const calls: Calls = { upserts: [], setHomes: [] };
  const memberships = {
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      calls.upserts.push(m);
      return m;
    },
    find: async (): Promise<GymMembership | null> => opts.existing ?? null,
    setHome: async (userId: string, gymId: string): Promise<void> => {
      calls.setHomes.push({ userId, gymId });
    },
    remove: async (): Promise<void> => {},
    listByGym: async (): Promise<GymMembership[]> => [],
    listByUser: async (): Promise<GymMembership[]> => [],
    update: async (): Promise<GymMembership | null> => null,
  };
  const promotions = { insert: async (): Promise<never> => { throw new Error("unused"); }, listByUser: async (): Promise<[]> => [] };
  const gyms = {
    findById: async (): Promise<{ id: string; name: string } | null> =>
      opts.gymExists === false ? null : { id: "g1", name: "Test Gym" },
  };
  const users = { findById: async (): Promise<null> => null, update: async (): Promise<null> => null };

  const facade = new MembershipFacade(
    memberships as unknown as ConstructorParameters<typeof MembershipFacade>[0],
    promotions as unknown as ConstructorParameters<typeof MembershipFacade>[1],
    gyms as unknown as ConstructorParameters<typeof MembershipFacade>[2],
    users as unknown as ConstructorParameters<typeof MembershipFacade>[3],
    (): string => "generated-id",
  );
  return { facade, calls };
}

function membership(overrides: Partial<GymMembership> = {}): GymMembership {
  return {
    id: "m1",
    gymId: "g1",
    userId: "u1",
    status: "active",
    verifiedMember: false,
    gymRole: "member",
    isHome: false,
    visibleInRoster: true,
    joinMethod: "self",
    joinedAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("MembershipFacade.ensureHome", () => {
  test("joins then marks home when no membership exists", async () => {
    const { facade, calls } = makeFacade({ existing: null });
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(1);
    expect(calls.upserts[0]?.userId).toBe("u1");
    expect(calls.upserts[0]?.gymId).toBe("g1");
    expect(calls.setHomes).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("marks home without a second join when already a member", async () => {
    const { facade, calls } = makeFacade({ existing: membership() });
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("propagates not_found for an unknown gym and writes nothing", async () => {
    const { facade, calls } = makeFacade({ existing: null, gymExists: false });
    await expect(facade.ensureHome("u1", "missing")).rejects.toThrow(AppError);
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toHaveLength(0);
  });

  test("is idempotent across repeated calls", async () => {
    const { facade, calls } = makeFacade({ existing: membership({ isHome: true }) });
    await facade.ensureHome("u1", "g1");
    await facade.ensureHome("u1", "g1");
    expect(calls.upserts).toHaveLength(0);
    expect(calls.setHomes).toHaveLength(2);
  });
});
```

If the `ConstructorParameters<...>` casts do not typecheck against the real constructor,
build properly-typed stub objects instead. **Do not reach for `any`** — that is a hard
project constraint. Read `membership.facade.mts:22-28` for the exact `Pick<>` shapes.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/membership-ensure-home.test.mts`
Expected: FAIL — `ensureHome` is not a function.

- [ ] **Step 3: Implement `ensureHome`**

In `apps/api/src/facades/membership.facade.mts`, add directly after `join`:

```typescript
  /// Guarantees the user is a member of [gymId] and that it is their home gym.
  ///
  /// Composed from the existing paths rather than reimplementing them: [join]
  /// already rejects an unknown gym and already upserts, so this is safe to
  /// call repeatedly. Deliberately does NOT call `setMine`, which would write
  /// `users.homeGymId` a second time — the caller owns that field.
  public async ensureHome(userId: string, gymId: string): Promise<void> {
    const existing: GymMembership | null = await this.memberships.find(gymId, userId);
    if (!existing) {
      await this.join(userId, gymId);
    }
    await this.memberships.setHome(userId, gymId);
  }
```

Note the argument order: `find(gymId, userId)` but `setHome(userId, gymId)`. That is the
existing convention in this file — check both signatures rather than assuming they match.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/membership-ensure-home.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Lint and run the suite**

Run: `cd apps/api && bunx eslint --fix src/facades/membership.facade.mts test/membership-ensure-home.test.mts && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: lint clean; all pass (257 total).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/membership.facade.mts apps/api/test/membership-ensure-home.test.mts
git commit -m "feat(api): add MembershipFacade.ensureHome

Composes the existing join and setHome so a caller can guarantee a home
membership without reimplementing either."
```

---

### Task 2: Sync from the profile update path

**Files:**
- Modify: `apps/api/src/facades/user.facade.mts`
- Modify: `apps/api/src/container.mts` — **construction order must change**
- Test: `apps/api/test/user-home-gym-sync.test.mts` (create)

**Interfaces:**
- Consumes: `MembershipFacade.ensureHome` (Task 1), `UserRepository.findById`
- Produces: `UserFacade` constructor gains a second parameter — a `Pick<MembershipFacade, "ensureHome">`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/user-home-gym-sync.test.mts`:

```typescript
import { describe, expect, test } from "bun:test";
import type { User } from "@bjj/contract";
import { UserFacade } from "../src/facades/user.facade.mts";
import { AppError } from "../src/http/errors.mts";

function makeFacade(opts: { current?: string | null; ensureHomeThrows?: boolean }): {
  facade: UserFacade;
  ensureHomeCalls: { userId: string; gymId: string }[];
  updates: Record<string, unknown>[];
} {
  const ensureHomeCalls: { userId: string; gymId: string }[] = [];
  const updates: Record<string, unknown>[] = [];

  const users = {
    findById: async (): Promise<User> =>
      ({ id: "u1", email: "u@x.test", homeGymId: opts.current ?? undefined }) as User,
    update: async (_id: string, patch: Record<string, unknown>): Promise<User> => {
      updates.push(patch);
      return { id: "u1", email: "u@x.test", ...patch } as User;
    },
    upsertByAuth0Id: async (): Promise<never> => { throw new Error("unused"); },
    insert: async (): Promise<never> => { throw new Error("unused"); },
  };

  const memberships = {
    ensureHome: async (userId: string, gymId: string): Promise<void> => {
      if (opts.ensureHomeThrows === true) throw new AppError("not_found", `Gym ${gymId} not found`);
      ensureHomeCalls.push({ userId, gymId });
    },
  };

  const facade = new UserFacade(
    users as unknown as ConstructorParameters<typeof UserFacade>[0],
    memberships,
  );
  return { facade, ensureHomeCalls, updates };
}

describe("UserFacade.updateProfile home gym sync", () => {
  test("joins the gym when homeGymId changes", async () => {
    const { facade, ensureHomeCalls } = makeFacade({ current: null });
    await facade.updateProfile("u1", { homeGymId: "g1" });
    expect(ensureHomeCalls).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("does nothing extra when homeGymId is unchanged", async () => {
    const { facade, ensureHomeCalls } = makeFacade({ current: "g1" });
    await facade.updateProfile("u1", { homeGymId: "g1" });
    expect(ensureHomeCalls).toHaveLength(0);
  });

  test("does nothing extra when the patch omits homeGymId", async () => {
    const { facade, ensureHomeCalls, updates } = makeFacade({ current: "g1" });
    await facade.updateProfile("u1", { bio: "hello" });
    expect(ensureHomeCalls).toHaveLength(0);
    expect(updates[0]).toEqual({ bio: "hello" });
  });

  test("rejects the whole update when the gym does not exist", async () => {
    const { facade, updates } = makeFacade({ current: null, ensureHomeThrows: true });
    await expect(facade.updateProfile("u1", { homeGymId: "missing" })).rejects.toThrow(AppError);
    expect(updates).toHaveLength(0);
  });
});
```

The last test pins an ordering requirement: the sync runs **before** the user write, so a bad
gym id leaves no partial state. If the implementation writes first, that test fails.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/user-home-gym-sync.test.mts`
Expected: FAIL — `UserFacade` takes one constructor argument.

- [ ] **Step 3: Implement the sync**

In `apps/api/src/facades/user.facade.mts`, add the import:

```typescript
import type { MembershipFacade } from "./membership.facade.mts";
```

Change the constructor to take the collaborator:

```typescript
  public constructor(
    private readonly users: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert">,
    private readonly memberships: Pick<MembershipFacade, "ensureHome">,
  ) {}
```

Replace `updateProfile` with:

```typescript
  public async updateProfile(id: string, patch: UpdateUserRequest, isSocialUser = false): Promise<User> {
    const effective: UpdateUserRequest = isSocialUser ? this.socialAllowed(patch) : patch;

    // A home gym now means a roster entry. Sync BEFORE writing the user, so an
    // unknown gym rejects the whole update rather than leaving the profile
    // pointing at a gym the user was never joined to.
    const nextHomeGymId: string | undefined = effective.homeGymId;
    if (nextHomeGymId !== undefined && nextHomeGymId !== "") {
      const current: User | null = await this.users.findById(id);
      if (current?.homeGymId !== nextHomeGymId) {
        await this.memberships.ensureHome(id, nextHomeGymId);
      }
    }

    const updated = await this.users.update(id, effective);
    if (!updated) throw new AppError("not_found", `User ${id} not found`);
    return updated;
  }
```

- [ ] **Step 4: Rewire the container**

In `apps/api/src/container.mts`, `userFacade` is currently constructed at line 143 and
`membershipFacade` at line 150. **`membershipFacade` must now be constructed first.** Move its
construction above `userFacade`'s into a local, then pass it in:

```typescript
    const membershipFacade = new MembershipFacade(membershipRepo, promotionRepo, gymRepo, userRepo, id);
```

and reference that local in both places in the returned object:

```typescript
    userFacade: new UserFacade(userRepo, membershipFacade),
    ...
    membershipFacade,
```

Keep every other container entry unchanged.

- [ ] **Step 5: Run tests and lint**

Run: `cd apps/api && bunx eslint --fix src/facades/user.facade.mts src/container.mts test/user-home-gym-sync.test.mts && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: lint clean; all pass (261 total). If other tests construct `UserFacade`, update those call sites to pass a stub with `ensureHome` — do not introduce `any`.

- [ ] **Step 6: Verify the app still boots**

A passing unit suite does not prove the container wires up. Run:

```bash
cd apps/api && MONGODB_URI="mongodb://localhost:27021" MONGODB_DB="bjj_bootcheck" PORT=3197 bun src/index.mts &
sleep 12
curl -s -o /dev/null -w "health: %{http_code}\n" http://localhost:3197/health
curl -s -o /dev/null -w "ready:  %{http_code}\n" http://localhost:3197/ready
pkill -f "bun src/index.mts"
```

Expected: both `200`. A construction-order mistake shows up here as a boot failure, not as a
failing unit test.

- [ ] **Step 7: Commit**

```bash
git add apps/api/src/facades/user.facade.mts apps/api/src/container.mts apps/api/test/user-home-gym-sync.test.mts
git commit -m "feat(api): join the gym when a profile sets a home gym

The profile path wrote users.homeGymId and nothing else, so a declared
home gym never produced a roster entry. Sync before the user write, so an
unknown gym rejects the update instead of leaving them inconsistent."
```

---

### Task 3: Backfill script for already-diverged users

**Files:**
- Create: `apps/api/scripts/backfill-home-gym-memberships.mts`
- Test: `apps/api/test/backfill-home-gym.test.mts` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks — it talks to Mongo directly, like the other one-off scripts
- Produces:
  - `planBackfill(users: BackfillUser[], gymIds: Set<string>, membershipKeys: Set<string>): BackfillPlan`
  - types `BackfillUser`, `BackfillPlan`

- [ ] **Step 1: Write the failing test**

The planning logic is pure and gets real tests; the Mongo I/O around it does not.

Create `apps/api/test/backfill-home-gym.test.mts`:

```typescript
import { describe, expect, test } from "bun:test";
import { planBackfill } from "../scripts/backfill-home-gym-memberships.mts";

describe("planBackfill", () => {
  const gyms = new Set<string>(["g1", "g2"]);

  test("plans a membership for a user with a home gym and none", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>());
    expect(plan.toCreate).toEqual([{ userId: "u1", gymId: "g1" }]);
    expect(plan.skippedExisting).toHaveLength(0);
    expect(plan.skippedMissingGym).toHaveLength(0);
  });

  test("skips a user who already has that membership", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>(["g1::u1"]));
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedExisting).toEqual([{ userId: "u1", gymId: "g1" }]);
  });

  test("reports rather than fails on a home gym that no longer exists", () => {
    const plan = planBackfill([{ id: "u1", homeGymId: "gone" }], gyms, new Set<string>());
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedMissingGym).toEqual([{ userId: "u1", gymId: "gone" }]);
  });

  test("ignores users with no home gym", () => {
    const plan = planBackfill([{ id: "u1" }], gyms, new Set<string>());
    expect(plan.toCreate).toHaveLength(0);
    expect(plan.skippedExisting).toHaveLength(0);
    expect(plan.skippedMissingGym).toHaveLength(0);
  });

  test("is idempotent — a second run over its own output plans nothing", () => {
    const first = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, new Set<string>());
    const after = new Set<string>(first.toCreate.map((c) => `${c.gymId}::${c.userId}`));
    const second = planBackfill([{ id: "u1", homeGymId: "g1" }], gyms, after);
    expect(second.toCreate).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/backfill-home-gym.test.mts`
Expected: FAIL — the script does not exist.

- [ ] **Step 3: Write the script**

Create `apps/api/scripts/backfill-home-gym-memberships.mts`:

```typescript
/**
 * Backfills gym memberships for users whose profile names a home gym but who
 * have no matching membership — the divergence caused by the profile path
 * writing `users.homeGymId` without joining the gym.
 *
 * Dry run by default. Pass --commit to write, matching the gate used by
 * scripts/fb-open-mat/insert.mts.
 */
export interface BackfillUser {
  readonly id: string;
  readonly homeGymId?: string;
}

export interface BackfillPair {
  readonly userId: string;
  readonly gymId: string;
}

export interface BackfillPlan {
  readonly toCreate: BackfillPair[];
  readonly skippedExisting: BackfillPair[];
  readonly skippedMissingGym: BackfillPair[];
}

/// Pure planner. `membershipKeys` holds `${gymId}::${userId}` for every
/// existing membership.
export function planBackfill(
  users: BackfillUser[],
  gymIds: Set<string>,
  membershipKeys: Set<string>,
): BackfillPlan {
  const toCreate: BackfillPair[] = [];
  const skippedExisting: BackfillPair[] = [];
  const skippedMissingGym: BackfillPair[] = [];

  for (const u of users) {
    const gymId: string | undefined = u.homeGymId;
    if (gymId === undefined || gymId === "") continue;
    const pair: BackfillPair = { userId: u.id, gymId };
    if (!gymIds.has(gymId)) {
      skippedMissingGym.push(pair);
    } else if (membershipKeys.has(`${gymId}::${u.id}`)) {
      skippedExisting.push(pair);
    } else {
      toCreate.push(pair);
    }
  }
  return { toCreate, skippedExisting, skippedMissingGym };
}
```

Then add the Mongo driver below it, guarded so importing the module in a test does not
connect. Follow this shape:

```typescript
const isMain: boolean = import.meta.main === true;

if (isMain) {
  const COMMIT: boolean = process.argv.includes("--commit");

  // Bun 1.3.x exposes v8.startupSnapshot.isBuildingSnapshot as a throwing stub,
  // which bson@7 calls at module load. Shim it, THEN dynamic-import mongodb.
  const v8 = (globalThis as unknown as { process: { getBuiltinModule?: (m: string) => unknown } })
    .process.getBuiltinModule?.("v8") as { startupSnapshot?: Record<string, unknown> } | undefined;
  if (v8) {
    v8.startupSnapshot = { ...(v8.startupSnapshot ?? {}), isBuildingSnapshot: (): boolean => false };
  }
  const { MongoClient } = await import("mongodb");

  const uri: string = process.env["MONGODB_URI"] ?? "";
  const dbName: string = process.env["MONGODB_DB"] ?? "";
  if (!uri || !dbName) {
    console.error("MONGODB_URI and MONGODB_DB are required.");
    process.exit(1);
  }

  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db(dbName);

  const users = (await db.collection("users")
    .find({ homeGymId: { $exists: true, $ne: null } }, { projection: { homeGymId: 1 } })
    .toArray()).map((u): BackfillUser => ({ id: String(u["_id"]), homeGymId: u["homeGymId"] as string }));

  const gymIds = new Set<string>(
    (await db.collection("gyms").find({}, { projection: { _id: 1 } }).toArray()).map((g) => String(g["_id"])),
  );

  const membershipKeys = new Set<string>(
    (await db.collection("gymMemberships").find({}, { projection: { gymId: 1, userId: 1 } }).toArray())
      .map((m) => `${String(m["gymId"])}::${String(m["userId"])}`),
  );

  const plan: BackfillPlan = planBackfill(users, gymIds, membershipKeys);

  console.log(`users with a home gym : ${users.length}`);
  console.log(`  to create           : ${plan.toCreate.length}`);
  console.log(`  already a member    : ${plan.skippedExisting.length}`);
  console.log(`  home gym missing    : ${plan.skippedMissingGym.length}`);
  for (const p of plan.toCreate) console.log(`   + ${p.userId} -> ${p.gymId}`);
  for (const p of plan.skippedMissingGym) console.log(`   ! ${p.userId} -> ${p.gymId} (gym not found)`);

  if (!COMMIT) {
    console.log(`\nDRY RUN — nothing written. Re-run with --commit to apply.`);
  } else {
    const now: string = new Date().toISOString();
    for (const p of plan.toCreate) {
      // membership.repository.mts:28 stores `{ ...m, _id: m.id }`, so `_id` and
      // `id` MUST be the same value. Two different UUIDs writes a row the app
      // reads back with the wrong id.
      const membershipId: string = crypto.randomUUID();
      await db.collection("gymMemberships").insertOne({
        _id: membershipId,
        id: membershipId,
        gymId: p.gymId,
        userId: p.userId,
        status: "active",
        verifiedMember: false,
        gymRole: "member",
        isHome: true,
        visibleInRoster: true,
        joinMethod: "self",
        joinedAt: now,
        createdAt: now,
      });
    }
    console.log(`\nWrote ${plan.toCreate.length} membership(s).`);
  }

  await client.close();
}
```

The document shape matches `upsertJoin` (`membership.repository.mts:24-30`), which inserts
`{ ...m, _id: m.id }` — every `GymMembership` field plus an `_id` mirroring `id`. Reads go
through `stripId`, so an `_id` that disagrees with `id` produces a row the app reads back with
the wrong identifier. Keep them equal.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test test/backfill-home-gym.test.mts`
Expected: PASS (5 tests).

- [ ] **Step 5: Dry-run it against production and report**

```bash
cd apps/api
MONGODB_URI="$(grep '^MONGODB_URI=' .env | cut -d= -f2-)" \
MONGODB_DB="$(grep '^MONGODB_DB=' .env | cut -d= -f2-)" \
  bun run scripts/backfill-home-gym-memberships.mts
```

Expected: 3 users with a home gym, 3 to create, 0 already members, 0 missing gyms — and the
words `DRY RUN`. **Do NOT pass `--commit`.** Writing to production is the human's call; paste
the exact output into your report so they can approve it.

- [ ] **Step 6: Lint and run the suite**

Run: `cd apps/api && bunx eslint --fix scripts/backfill-home-gym-memberships.mts test/backfill-home-gym.test.mts && TEST_MONGODB_URI="mongodb://localhost:27021" bun test`
Expected: lint clean; all pass (266 total).

- [ ] **Step 7: Commit**

```bash
git add apps/api/scripts/backfill-home-gym-memberships.mts apps/api/test/backfill-home-gym.test.mts
git commit -m "feat(api): add home-gym membership backfill script

Dry run by default; --commit to write. Skips users whose home gym no
longer exists rather than failing the run."
```

---

## Notes for the implementer

- Tasks are sequential: Task 2 needs Task 1's `ensureHome`; Task 3 is independent of both but ships with them.
- **Do not run the backfill with `--commit`.** Dry-run output goes in your report; the human decides whether to apply it.
- **Do not touch gym ownership.** 0 of 847 gyms have an `ownerId`; that is a separate gap with its own product question and is explicitly out of scope.
- No mobile changes. The profile screen already sends `homeGymId`; only the server's behaviour changes.
