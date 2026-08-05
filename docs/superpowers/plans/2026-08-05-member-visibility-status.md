# Member Visibility Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let gym owners, coaches, and admins mark a gym member as `hidden` (off the public roster, privileges intact) or `inactive` (off the roster and stripped of member privileges), with both states clearly badged for managers.

**Architecture:** One widened `MembershipStatus` enum (`pending | active | hidden | inactive`) plus a shared `hasMemberPrivileges()` helper that the authorization guards call instead of comparing to `'active'`. Roster filtering lives in exactly one place — `MembershipRepository.listByGym` — and managers opt into the wider list with an explicit `?includeHidden=true` query parameter so no existing consumer's payload changes.

**Tech Stack:** Bun, Elysia, TypeBox (`@bjj/contract`), MongoDB 7 driver, Angular 22 + ZardUI (admin), Flutter + Riverpod (mobile), `bun test`, Playwright.

**Spec:** `docs/superpowers/specs/2026-08-05-member-visibility-status-design.md`

## Global Constraints

- TypeScript strict mode. **Never `any`** — use explicit types, interfaces, or `unknown`.
- Explicit return types and access modifiers on all functions and methods.
- TypeBox for all schema validation. Never Zod.
- `.mts` source files import each other with `.mjs` specifiers.
- Single quotes, trailing commas in multiline expressions, named exports.
- Blank line after a class's opening brace, before the first property or method.
- Backend (`apps/api`, `packages/*`): Winston logger, no `console.*`. Angular may use `console.*`.
- Run `bunx eslint --fix` on changed TypeScript after every task; fix all lint errors before the task is complete.
- Conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). **Never add Co-Authored-By lines.**
- `bun test` is run from `apps/api`. The repository tests need MongoDB on `localhost:27017`.
- Branch: `feature/member-visibility-status` (already checked out).

## File Structure

**`packages/contract`**
- Modify `src/enums/membership-status.mts` — widen the union, add `ManageableMembershipStatus`, add `hasMemberPrivileges()`.
- Modify `src/schemas/gym-membership.mts` — add `statusUpdatedAt`, `statusUpdatedBy`.
- Modify `src/schemas/roster-member.mts` — add `status`.
- Modify `src/schemas/requests/membership-requests.mts` — add `status` to `UpdateMembershipRequest`.

**`apps/api`**
- Modify `src/facades/gym-authz.mts` — both guards call `hasMemberPrivileges()`.
- Modify `src/repositories/membership.repository.mts` — `listByGym` status filter, new index.
- Modify `src/facades/membership.facade.mts` — `roster()` takes `includeHidden` + caller, `updateMembership()` handles `status` with guard rails.
- Modify `src/routes/membership.routes.mts` — `includeHidden` query on the roster route.
- Modify `src/facades/admin.facade.mts` — `updateMembership()`.
- Modify `src/routes/admin.routes.mts` — `PATCH /memberships/:gymId/:userId`.
- Modify `src/openapi.mts` — the new parameter and summaries.

**`apps/admin`**
- Modify `src/app/core/models/gym-membership.ts`, `src/app/core/api/admin-api.service.ts`.
- Modify `src/app/features/members/members.ts`, `members.html`, `members.scss`.
- Modify `e2e/seed/fixtures.ts`, `e2e/serve-api.ts`, `e2e/grids.spec.ts`.

**`apps/mobile`**
- Modify `lib/features/membership/models/roster_member.dart`, `models/gym_membership.dart`.
- Modify `lib/features/membership/data/membership_repository.dart` — `status` on `manageMember`, `manageRoster()`, `manageRosterProvider`.
- Modify `lib/core/api/endpoints.dart` — manage-roster URL.
- Modify `lib/features/gyms/data/gym_permissions.dart` — derive self-role from own memberships, not the roster.
- Modify `lib/features/membership/screens/roster_screen.dart` — badges, dimming, status actions.

---

### Task 1: Contract — widen the status enum and add the privilege helper

**Files:**
- Modify: `packages/contract/src/enums/membership-status.mts`
- Modify: `packages/contract/src/schemas/gym-membership.mts:11-19`
- Modify: `packages/contract/src/schemas/roster-member.mts:6-22`
- Modify: `packages/contract/src/schemas/requests/membership-requests.mts:5-11`
- Test: `apps/api/test/contract-membership-status.test.mts` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `MembershipStatus` — `'pending' | 'active' | 'hidden' | 'inactive'`
  - `ManageableMembershipStatus` — `'active' | 'hidden' | 'inactive'` (TypeBox union, `$id: 'ManageableMembershipStatus'`)
  - `hasMemberPrivileges(status: MembershipStatus | undefined): boolean`
  - `GymMembership.statusUpdatedAt?: string`, `GymMembership.statusUpdatedBy?: string`
  - `RosterMember.status: MembershipStatus`
  - `UpdateMembershipRequest.status?: ManageableMembershipStatus`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/contract-membership-status.test.mts`:

```ts
// apps/api/test/contract-membership-status.test.mts
import { describe, expect, it } from 'bun:test';
import { Value } from '@sinclair/typebox/value';
import {
  GymMembership,
  MembershipStatus,
  ManageableMembershipStatus,
  RosterMember,
  UpdateMembershipRequest,
  hasMemberPrivileges,
} from '@bjj/contract';

describe('membership status contract', () => {
  it('accepts all four statuses', () => {
    for (const s of ['pending', 'active', 'hidden', 'inactive']) {
      expect(Value.Check(MembershipStatus, s)).toBe(true);
    }
    expect(Value.Check(MembershipStatus, 'bogus')).toBe(false);
  });

  it('ManageableMembershipStatus rejects pending', () => {
    expect(Value.Check(ManageableMembershipStatus, 'hidden')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'inactive')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'active')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'pending')).toBe(false);
  });

  it('hasMemberPrivileges is true only for active and hidden', () => {
    expect(hasMemberPrivileges('active')).toBe(true);
    expect(hasMemberPrivileges('hidden')).toBe(true);
    expect(hasMemberPrivileges('inactive')).toBe(false);
    expect(hasMemberPrivileges('pending')).toBe(false);
    // Legacy docs may omit the field; the schema default is 'active'.
    expect(hasMemberPrivileges(undefined)).toBe(true);
  });

  it('UpdateMembershipRequest carries status', () => {
    expect(Value.Check(UpdateMembershipRequest, { status: 'hidden' })).toBe(true);
    expect(Value.Check(UpdateMembershipRequest, { status: 'pending' })).toBe(false);
  });

  it('GymMembership carries the status audit fields', () => {
    const m = {
      id: 'm1', gymId: 'g1', userId: 'u1', status: 'hidden', verifiedMember: false,
      gymRole: 'member', isHome: false, visibleInRoster: true, joinMethod: 'self',
      joinedAt: 't', statusUpdatedAt: 't', statusUpdatedBy: 'owner1',
    };
    expect(Value.Check(GymMembership, m)).toBe(true);
  });

  it('RosterMember requires status', () => {
    const base = {
      userId: 'u1', name: 'A', gymRole: 'member', verifiedMember: false, hasProfile: true,
    };
    expect(Value.Check(RosterMember, base)).toBe(false);
    expect(Value.Check(RosterMember, { ...base, status: 'active' })).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && bun test test/contract-membership-status.test.mts`
Expected: FAIL — `hasMemberPrivileges` and `ManageableMembershipStatus` are not exported from `@bjj/contract`.

- [ ] **Step 3: Widen the enum and add the helper**

Replace the whole of `packages/contract/src/enums/membership-status.mts`:

```ts
import { type Static, Type as t } from "@sinclair/typebox";

export const MembershipStatus = t.Union(
  [t.Literal("pending"), t.Literal("active"), t.Literal("hidden"), t.Literal("inactive")],
  { $id: "MembershipStatus" },
);
export type MembershipStatus = Static<typeof MembershipStatus>;

/// The statuses a gym owner, coach, or admin may assign. `pending` is owned by
/// the join flow and is deliberately not settable through the manage endpoints.
export const ManageableMembershipStatus = t.Union(
  [t.Literal("active"), t.Literal("hidden"), t.Literal("inactive")],
  { $id: "ManageableMembershipStatus" },
);
export type ManageableMembershipStatus = Static<typeof ManageableMembershipStatus>;

/// True when a membership grants gym-member privileges (forum access, DMs,
/// member-only content).
///
/// `hidden` keeps privileges — it only removes the member from rosters and
/// member-facing pickers. `inactive` revokes them. `undefined` is treated as
/// `active` because the schema default is `active` and legacy documents predate
/// the field.
export function hasMemberPrivileges(status: MembershipStatus | undefined): boolean {
  return status === undefined || status === "active" || status === "hidden";
}
```

- [ ] **Step 4: Add the audit fields to `GymMembership`**

In `packages/contract/src/schemas/gym-membership.mts`, add two properties after `createdAt` (line 18):

```ts
    createdAt: t.Optional(t.String()),
    // Set whenever an owner/coach/admin changes `status`.
    statusUpdatedAt: t.Optional(t.String()),
    statusUpdatedBy: t.Optional(t.String()),
```

- [ ] **Step 5: Add `status` to `RosterMember`**

In `packages/contract/src/schemas/roster-member.mts`, add the import and the property:

```ts
import { MembershipStatus } from "../enums/membership-status.mts";
```

and inside the object, after `verifiedMember: t.Boolean(),`:

```ts
    // Public responses only ever contain 'active'; managers also see
    // 'hidden' and 'inactive'.
    status: MembershipStatus,
```

- [ ] **Step 6: Add `status` to `UpdateMembershipRequest`**

In `packages/contract/src/schemas/requests/membership-requests.mts`, add the import and the field:

```ts
import { ManageableMembershipStatus } from "../../enums/membership-status.mts";
```

```ts
export const UpdateMembershipRequest = t.Object(
  {
    verifiedMember: t.Optional(t.Boolean()),
    gymRole: t.Optional(GymRole),
    status: t.Optional(ManageableMembershipStatus),
  },
  { $id: "UpdateMembershipRequest" },
);
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd apps/api && bun test test/contract-membership-status.test.mts`
Expected: PASS (6 tests)

- [ ] **Step 8: Confirm nothing else broke**

Run: `cd apps/api && bun test 2>&1 | tail -20`
Expected: the only failures are ones that construct a `RosterMember` without `status` — that is a type error surfaced by the widened contract. Fix each by adding `status: 'active'` to the literal. Do not weaken the schema to make them pass.

- [ ] **Step 9: Lint and commit**

```bash
cd packages/contract && bunx eslint --fix src
cd ../../apps/api && bunx eslint --fix test/contract-membership-status.test.mts
git add packages/contract apps/api/test
git commit -m "feat(contract): widen MembershipStatus with hidden and inactive"
```

---

### Task 2: Authorization guards honour the privilege helper

**Files:**
- Modify: `apps/api/src/facades/gym-authz.mts:22,37`
- Test: `apps/api/test/gym-authz-member.test.mts`

**Interfaces:**
- Consumes: `hasMemberPrivileges` from Task 1.
- Produces: no signature changes. `assertCanManageGym` and `assertActiveMember` now admit `hidden` and reject `inactive`.

- [ ] **Step 1: Write the failing test**

Append to `apps/api/test/gym-authz-member.test.mts`:

```ts
describe('gym authz vs membership status', () => {
  const gym: Gym = { id: 'g1', name: 'Atos', address: 'x', amenities: [], isVerified: true };

  function deps(status: MembershipStatus, gymRole: GymRole = 'member'): GymAuthzDeps {
    return {
      gyms: { findById: async (): Promise<Gym | null> => gym },
      memberships: {
        find: async (): Promise<GymMembership | null> => ({
          id: 'm1', gymId: 'g1', userId: 'u1', status, verifiedMember: false, gymRole,
          isHome: false, visibleInRoster: true, joinMethod: 'self', joinedAt: 't',
        }),
      },
    };
  }

  it('a hidden member keeps member privileges', async () => {
    await expect(assertActiveMember(deps('hidden'), 'u1', 'g1', 'practitioner')).resolves.toBeUndefined();
  });

  it('an inactive member loses member privileges', async () => {
    await expect(assertActiveMember(deps('inactive'), 'u1', 'g1', 'practitioner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it('a hidden coach can still manage the gym', async () => {
    await expect(assertCanManageGym(deps('hidden', 'coach'), 'u1', 'g1', 'practitioner')).resolves.toBeUndefined();
  });

  it('an inactive coach cannot manage the gym', async () => {
    await expect(assertCanManageGym(deps('inactive', 'coach'), 'u1', 'g1', 'practitioner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });
});
```

Add whatever is missing from that file's import list: `assertActiveMember`, `assertCanManageGym`, `type GymAuthzDeps` from `../src/facades/gym-authz.mts`, and `type Gym, GymMembership, GymRole, MembershipStatus` from `@bjj/contract`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && bun test test/gym-authz-member.test.mts`
Expected: FAIL — "a hidden member keeps member privileges" throws `forbidden`, because the guards still compare to `'active'`.

- [ ] **Step 3: Point both guards at the helper**

In `apps/api/src/facades/gym-authz.mts`, add to the contract import:

```ts
import { hasMemberPrivileges } from '@bjj/contract';
import type { Gym, GymMembership, UserRole } from '@bjj/contract';
```

Line 22 becomes:

```ts
  if (membership && hasMemberPrivileges(membership.status) && (role === 'coach' || role === 'owner')) return;
```

Line 37 becomes:

```ts
  if (membership && hasMemberPrivileges(membership.status)) return;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/gym-authz-member.test.mts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd apps/api && bunx eslint --fix src/facades/gym-authz.mts test/gym-authz-member.test.mts
git add apps/api/src/facades/gym-authz.mts apps/api/test/gym-authz-member.test.mts
git commit -m "feat(api): gym authz admits hidden members and rejects inactive"
```

---

### Task 3: Repository filters the roster by status

**Files:**
- Modify: `apps/api/src/repositories/membership.repository.mts:17-22,42-47`
- Test: `apps/api/test/membership.repository.test.mts`

**Interfaces:**
- Consumes: nothing from earlier tasks (uses raw status strings).
- Produces: `listByGym(gymId: string, includeHidden: boolean)` — unchanged signature, new semantics:
  - `includeHidden === false` → `{ gymId, status: { $nin: ['pending', 'hidden', 'inactive'] }, visibleInRoster: { $ne: false } }`
  - `includeHidden === true` → `{ gymId, status: { $ne: 'pending' } }`

Both `$nin` and `$ne` also match documents where `status` is absent, which is how legacy rows stay visible — the same trick the existing `visibleInRoster: { $ne: false }` uses.

- [ ] **Step 1: Write the failing test**

Add to `apps/api/test/membership.repository.test.mts` inside the existing `describe`:

```ts
  it('listByGym excludes hidden and inactive from the public roster', async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: 'sa', gymId: 'gS', userId: 'act', status: 'active' }));
    await repo.upsertJoin(m({ id: 'sh', gymId: 'gS', userId: 'hid', status: 'hidden' }));
    await repo.upsertJoin(m({ id: 'si', gymId: 'gS', userId: 'ina', status: 'inactive' }));
    await repo.upsertJoin(m({ id: 'sp', gymId: 'gS', userId: 'pen', status: 'pending' }));

    const publicRoster = await repo.listByGym('gS', false);
    expect(publicRoster.map((x) => x.userId).sort()).toEqual(['act']);

    const managerRoster = await repo.listByGym('gS', true);
    expect(managerRoster.map((x) => x.userId).sort()).toEqual(['act', 'hid', 'ina']);
  });

  it('listByGym keeps legacy docs that have no status field', async () => {
    const col = db.collection('gymMemberships');
    await col.insertOne({
      _id: 'legacy', id: 'legacy', gymId: 'gL', userId: 'old',
      verifiedMember: false, isHome: false, visibleInRoster: true, joinedAt: 't',
    });
    expect((await repo0(db).listByGym('gL', false)).map((x) => x.userId)).toEqual(['old']);
    expect((await repo0(db).listByGym('gL', true)).map((x) => x.userId)).toEqual(['old']);
  });

  it('a self-hidden active member is still absent from the public roster', async () => {
    const repo = new MembershipRepository(db);
    await repo.upsertJoin(m({ id: 'sv', gymId: 'gV', userId: 'shy', status: 'active', visibleInRoster: false }));
    expect(await repo.listByGym('gV', false)).toEqual([]);
    expect((await repo.listByGym('gV', true)).map((x) => x.userId)).toEqual(['shy']);
  });
```

Add this helper above the `describe` block (the legacy test needs a repo without calling `upsertJoin`):

```ts
function repo0(database: typeof db): MembershipRepository {
  return new MembershipRepository(database);
}
```

The existing `m()` helper hardcodes `status: "active"` before spreading `over`, so `m({ status: 'hidden' })` already overrides correctly — no change needed there.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/api && bun test test/membership.repository.test.mts`
Expected: FAIL — the public roster returns all four users because `listByGym` does not filter on status.

- [ ] **Step 3: Implement the filter and the index**

In `apps/api/src/repositories/membership.repository.mts`, replace `listByGym` (lines 42-47):

```ts
  public async listByGym(gymId: string, includeHidden: boolean): Promise<GymMembership[]> {
    // `$nin` / `$ne` also match documents where `status` is absent, which is how
    // legacy rows written before the field existed stay visible. Same reason
    // `visibleInRoster` uses `$ne: false` rather than `true`.
    const filter = includeHidden
      ? { gymId, status: { $ne: 'pending' } }
      : { gymId, status: { $nin: ['pending', 'hidden', 'inactive'] }, visibleInRoster: { $ne: false } };
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).find(filter).toArray();
    return docs.map((d) => stripId<GymMembership>(d) as GymMembership);
  }
```

Add the supporting index in `ensureIndexes` after line 21:

```ts
    await col.createIndex({ gymId: 1, status: 1 });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/api && bun test test/membership.repository.test.mts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd apps/api && bunx eslint --fix src/repositories/membership.repository.mts test/membership.repository.test.mts
git add apps/api/src/repositories/membership.repository.mts apps/api/test/membership.repository.test.mts
git commit -m "feat(api): filter roster by membership status"
```

---

### Task 4: Facade — manager roster and status mutation with guard rails

**Files:**
- Modify: `apps/api/src/facades/membership.facade.mts:78-98,117-131`
- Test: `apps/api/test/membership.facade.test.mts`

**Interfaces:**
- Consumes: `hasMemberPrivileges` (Task 1), `listByGym` semantics (Task 3).
- Produces:
  - `roster(gymId: string, includeHidden?: boolean, caller?: RosterCaller): Promise<RosterMember[]>` where `RosterCaller` is `{ readonly userId: string; readonly role: UserRole }`. `includeHidden` defaults to `false`. When `includeHidden` is `true`, `caller` is required and must pass `assertCanManageGym`; a missing caller throws `unauthorized`.
  - `updateMembership(...)` — unchanged signature, now applies `status` and stamps `statusUpdatedAt` / `statusUpdatedBy`.
  - Manager rosters are sorted: privileged members first, then hidden, then inactive.

- [ ] **Step 1: Write the failing tests**

Add to `apps/api/test/membership.facade.test.mts`. The file's `facade()` helper stub for `listByGym` must first be updated to match the real repository semantics:

```ts
    listByGym: async (g: string, incl: boolean): Promise<GymMembership[]> =>
      [...memberships.values()].filter((m) => {
        if (m.gymId !== g) return false;
        if (m.status === 'pending') return false;
        if (incl) return true;
        return m.status !== 'hidden' && m.status !== 'inactive' && m.visibleInRoster !== false;
      }),
```

Then add the tests:

```ts
  it('public roster omits hidden and inactive members', async () => {
    const { f } = facade({
      memberships: [
        member('g1', 'act'),
        member('g1', 'hid', { status: 'hidden' }),
        member('g1', 'ina', { status: 'inactive' }),
      ],
    });
    const roster = await f.roster('g1');
    expect(roster.map((r) => r.userId)).toEqual(['act']);
    expect(roster[0]?.status).toBe('active');
  });

  it('a manager roster includes hidden and inactive, active first', async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [
        member('g1', 'ina', { status: 'inactive' }),
        member('g1', 'hid', { status: 'hidden' }),
        member('g1', 'act'),
      ],
    });
    const roster = await f.roster('g1', true, { userId: owner, role: 'gym_owner' });
    expect(roster.map((r) => r.userId)).toEqual(['act', 'hid', 'ina']);
    expect(roster.map((r) => r.status)).toEqual(['active', 'hidden', 'inactive']);
  });

  it('includeHidden requires a caller who can manage the gym', async () => {
    const { f } = facade({ memberships: [member('g1', 'plain')] });
    await expect(f.roster('g1', true)).rejects.toMatchObject({ code: 'unauthorized' });
    await expect(f.roster('g1', true, { userId: 'plain', role: 'practitioner' }))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it('an owner can hide a member and the change is stamped', async () => {
    const owner = 'owner1';
    const { f, memberships } = facade({ gymOwnerId: owner, memberships: [member('g1', 'student')] });
    const updated = await f.updateMembership(owner, 'g1', 'student', { status: 'hidden' }, 'gym_owner');
    expect(updated.status).toBe('hidden');
    expect(updated.statusUpdatedBy).toBe(owner);
    expect(typeof updated.statusUpdatedAt).toBe('string');
    expect(memberships.get('g1:student')?.status).toBe('hidden');
  });

  it('a caller cannot change their own status', async () => {
    const owner = 'owner1';
    const { f } = facade({ gymOwnerId: owner, memberships: [member('g1', owner, { gymRole: 'owner' })] });
    await expect(f.updateMembership(owner, 'g1', owner, { status: 'inactive' }, 'gym_owner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it("the gym's owner cannot be hidden or deactivated", async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [member('g1', owner, { gymRole: 'owner' }), member('g1', 'coach1', { gymRole: 'coach' })],
    });
    await expect(f.updateMembership('coach1', 'g1', owner, { status: 'hidden' }, 'practitioner'))
      .rejects.toMatchObject({ code: 'forbidden' });
  });

  it('status changes leave verifiedMember and gymRole untouched', async () => {
    const owner = 'owner1';
    const { f } = facade({
      gymOwnerId: owner,
      memberships: [member('g1', 'student', { verifiedMember: true, gymRole: 'coach' })],
    });
    const updated = await f.updateMembership(owner, 'g1', 'student', { status: 'inactive' }, 'gym_owner');
    expect(updated.verifiedMember).toBe(true);
    expect(updated.gymRole).toBe('coach');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/api && bun test test/membership.facade.test.mts`
Expected: FAIL — `roster` takes one argument and `updateMembership` ignores `status`.

- [ ] **Step 3: Implement `roster` with the manager path**

In `apps/api/src/facades/membership.facade.mts`, add the caller interface above the class (after the `type` aliases at line 28):

```ts
export interface RosterCaller {
  readonly userId: string;
  readonly role: UserRole;
}

/// Manager rosters sort privileged members first, then hidden, then inactive,
/// so a manager scanning the list reads the exceptions at the bottom.
const STATUS_ORDER: Record<string, number> = { active: 0, hidden: 1, inactive: 2 };
```

Replace `roster` (lines 78-98):

```ts
  public async roster(
    gymId: string,
    includeHidden: boolean = false,
    caller?: RosterCaller,
  ): Promise<RosterMember[]> {
    if (includeHidden) {
      if (!caller) throw new AppError('unauthorized', 'Authentication required');
      await this.assertCanManage(caller.userId, gymId, caller.role);
    }
    const rows: GymMembership[] = await this.memberships.listByGym(gymId, includeHidden);
    const built: RosterMember[] = await Promise.all(
      rows.map(async (m): Promise<RosterMember> => {
        const u: User | null = await this.users.findById(m.userId);
        return {
          userId: m.userId,
          name: u?.displayName ?? 'Member',
          beltRank: u?.beltRank,
          beltStripes: u?.beltStripes,
          verifiedBeltRank: u?.verifiedBeltRank,
          verifiedBeltStripes: u?.verifiedBeltStripes,
          avatarUrl: u?.avatarUrl,
          gymRole: m.gymRole ?? 'member',
          verifiedMember: m.verifiedMember,
          status: m.status ?? 'active',
          hasProfile: u !== null,
        };
      }),
    );
    return built.sort(
      (a, b) => (STATUS_ORDER[a.status] ?? 0) - (STATUS_ORDER[b.status] ?? 0),
    );
  }
```

- [ ] **Step 4: Implement the status branch of `updateMembership`**

Replace `updateMembership` (lines 117-131):

```ts
  public async updateMembership(
    callerId: string,
    gymId: string,
    targetUserId: string,
    req: UpdateMembershipRequest,
    callerRole: UserRole,
  ): Promise<GymMembership> {
    await this.assertCanManage(callerId, gymId, callerRole);
    const target: GymMembership | null = await this.memberships.find(gymId, targetUserId);
    if (!target) throw new AppError('not_found', 'Target is not a member of this gym');
    const patch: Partial<GymMembership> = {};
    if (req.verifiedMember !== undefined) patch.verifiedMember = req.verifiedMember;
    if (req.gymRole !== undefined) patch.gymRole = req.gymRole;
    if (req.status !== undefined) {
      // Mirrors the self-promotion block: a manager must not be able to hide or
      // deactivate themselves, and the gym's owner must stay visible in their
      // own gym (transfer ownership first).
      if (callerId === targetUserId) {
        throw new AppError('forbidden', 'Cannot change your own membership status');
      }
      const gym: Gym | null = await this.gyms.findById(gymId);
      if (gym?.ownerId === targetUserId && req.status !== 'active') {
        throw new AppError('forbidden', "Cannot hide or deactivate the gym's owner");
      }
      patch.status = req.status;
      patch.statusUpdatedAt = new Date().toISOString();
      patch.statusUpdatedBy = callerId;
    }
    return (await this.memberships.update(gymId, targetUserId, patch)) ?? target;
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/membership.facade.test.mts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd apps/api && bunx eslint --fix src/facades/membership.facade.mts test/membership.facade.test.mts
git add apps/api/src/facades/membership.facade.mts apps/api/test/membership.facade.test.mts
git commit -m "feat(api): manager roster and member status mutation"
```

---

### Task 5: Roster route accepts `includeHidden`

**Files:**
- Modify: `apps/api/src/routes/membership.routes.mts:35-41`
- Modify: `apps/api/src/openapi.mts:246-271`
- Test: `apps/api/test/membership.routes.test.mts`

**Interfaces:**
- Consumes: `roster(gymId, includeHidden, caller)` from Task 4.
- Produces: `GET /api/v1/gyms/:id/members?includeHidden=true`. Without the parameter the response is unchanged. `PATCH /:id/members/:userId` already accepts `status` through the widened `UpdateMembershipRequest`.

- [ ] **Step 1: Write the failing test**

The existing `testApp` helper stubs `roster: async (g: string)`. Widen the stub so it records its arguments:

```ts
    roster: async (g: string, incl?: boolean, caller?: { userId: string }): Promise<RosterMember[]> => {
      calls.push(`roster:${g}:${String(incl ?? false)}:${caller?.userId ?? 'anon'}`);
      return [];
    },
```

Then add:

```ts
  it('GET roster without includeHidden calls the facade in public mode', async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request('http://localhost/api/v1/gyms/g1/members'));
    expect(res.status).toBe(200);
    expect(calls).toContain('roster:g1:false:anon');
  });

  it('GET roster passes includeHidden and the caller through', async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request('http://localhost/api/v1/gyms/g1/members?includeHidden=true', {
      headers: { authorization: 'Bearer t' },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain('roster:g1:true:u1');
  });

  it('PATCH member forwards a status change', async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request('http://localhost/api/v1/gyms/g1/members/u2', {
      method: 'PATCH',
      headers: { authorization: 'Bearer t', 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'hidden' }),
    }));
    expect(res.status).toBe(200);
  });

  it('PATCH member rejects pending as a status', async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request('http://localhost/api/v1/gyms/g1/members/u2', {
      method: 'PATCH',
      headers: { authorization: 'Bearer t', 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'pending' }),
    }));
    expect(res.status).toBe(422);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/api && bun test test/membership.routes.test.mts`
Expected: FAIL — the recorded call is `roster:g1` with no mode or caller suffix.

- [ ] **Step 3: Implement the route**

Replace the `GET /:id/members` handler in `apps/api/src/routes/membership.routes.mts` (lines 35-41):

```ts
    .get(
      "/:id/members",
      async ({ identity, params, query }) => {
        // Explicit opt-in rather than inferring from the caller's role: the same
        // roster feeds the mobile DM picker, class assignment, and permission
        // checks, and those must not silently widen for managers.
        const includeHidden = query["includeHidden"] === "true";
        const caller = identity ? { userId: identity.userId, role: identity.role } : undefined;
        const roster = await membershipFacade.roster(params.id, includeHidden, caller);
        return list(roster, { page: 1, limit: roster.length, total: roster.length });
      },
    )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/membership.routes.test.mts`
Expected: PASS

- [ ] **Step 5: Update the OpenAPI document**

In `apps/api/src/openapi.mts`, replace the roster `get` (lines 246-250) and the member `patch` summary (line 267):

```ts
        get: {
          summary: "List gym roster",
          description:
            "Public callers receive active, roster-visible members only. Owners, coaches, and admins may pass includeHidden=true to also receive hidden and inactive members, each carrying its status.",
          parameters: [
            ...gymIdParam,
            {
              name: "includeHidden",
              in: "query",
              required: false,
              schema: { type: "boolean" },
              description: "Owner/coach/admin only. 403 for anyone else.",
            },
          ],
          responses: ok(listOf("RosterMember")),
        },
```

```ts
          summary: "Update member (admin/owner — verify, change role, set status)",
```

- [ ] **Step 6: Verify the app still boots and the docs render**

Run: `cd apps/api && bun test test/boot.test.mts`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd apps/api && bunx eslint --fix src/routes/membership.routes.mts src/openapi.mts test/membership.routes.test.mts
git add apps/api/src/routes/membership.routes.mts apps/api/src/openapi.mts apps/api/test/membership.routes.test.mts
git commit -m "feat(api): includeHidden query on the gym roster route"
```

---

### Task 6: Admin API can set membership status

**Files:**
- Modify: `apps/api/src/facades/admin.facade.mts:47-49`
- Modify: `apps/api/src/routes/admin.routes.mts`
- Modify: `apps/api/src/openapi.mts`
- Test: `apps/api/test/admin-facade.test.mts`, `apps/api/test/admin-routes.test.mts`

**Interfaces:**
- Consumes: `MembershipFacade.updateMembership` (Task 4).
- Produces:
  - `AdminFacade.updateMembership(gymId: string, userId: string, req: UpdateMembershipRequest): Promise<GymMembership>` — calls through with callerId `'admin'` and role `'admin'`, matching how `adminRoutes` already calls `openMatFacade.update('admin', 'admin', ...)`.
  - `PATCH /api/v1/admin/memberships/:gymId/:userId`, body `UpdateMembershipRequest`, returns `data(GymMembership)`.

- [ ] **Step 1: Write the failing facade test**

`apps/api/test/admin-facade.test.mts` builds its facade in a local `makeFacade()` that passes `{} as never` for the memberships argument (the 5th constructor parameter). Add a self-contained test that supplies a real stub instead. Append inside the existing `describe("AdminFacade", ...)`:

```ts
  it("updateMembership delegates with the admin identity", async () => {
    const calls: string[] = [];
    const memberships = {
      updateMembership: async (
        callerId: string,
        gymId: string,
        userId: string,
        req: { status?: string },
        role: string,
      ): Promise<Record<string, unknown>> => {
        calls.push(`${callerId}:${gymId}:${userId}:${String(req.status)}:${role}`);
        return { id: "m1", gymId, userId, status: req.status };
      },
    };
    const facade = new AdminFacade(
      {} as never, {} as never, {} as never, {} as never, memberships as never, {} as never,
    );
    const out = await facade.updateMembership("g-1", "u-1", { status: "inactive" });
    expect(out.status).toBe("inactive");
    expect(calls).toEqual(["admin:g-1:u-1:inactive:admin"]);
  });
```

- [ ] **Step 2: Write the failing route test**

`apps/api/test/admin-routes.test.mts` is a real integration test — it boots `buildApp` against MongoDB and seeds `g-1`, `u-1`, and membership `m-1`. Note that `m-1` is seeded **without** a `status` field, which makes it a useful legacy-document case, and `g-1` has no `ownerId`, so the owner guard rail does not fire. Append inside the existing `describe`:

```ts
  it("PATCH /api/v1/admin/memberships/:gymId/:userId sets status", async () => {
    const res = await fetch(`${base}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ status: "hidden" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { status: string; statusUpdatedBy: string } };
    expect(body.data.status).toBe("hidden");
    expect(body.data.statusUpdatedBy).toBe("admin");
  });

  it("PATCH /api/v1/admin/memberships rejects pending", async () => {
    const res = await fetch(`${base}/api/v1/admin/memberships/g-1/u-1`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ status: "pending" }),
    });
    expect(res.status).toBe(422);
  });

  it("a hidden member drops out of the public roster", async () => {
    // Runs after the PATCH above, which set m-1 to hidden.
    const res = await fetch(`${base}/api/v1/gyms/g-1/members`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: { userId: string }[] };
    expect(body.data.map((r) => r.userId)).not.toContain("u-1");
  });

  it("includeHidden without a manager token is refused", async () => {
    const res = await fetch(`${base}/api/v1/gyms/g-1/members?includeHidden=true`);
    expect(res.status).toBe(401);
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd apps/api && bun test test/admin-facade.test.mts test/admin-routes.test.mts`
Expected: FAIL — `updateMembership` is not a method on `AdminFacade`, and the route 404s.

- [ ] **Step 4: Add the facade method**

In `apps/api/src/facades/admin.facade.mts`, add `UpdateMembershipRequest` to the type-only contract import, then add after `listMemberships`:

```ts
  /// Admin-scoped membership update. Passes 'admin' as the caller id and role,
  /// matching the convention adminRoutes already uses for open mats — the admin
  /// router carries no per-user identity.
  public async updateMembership(
    gymId: string,
    userId: string,
    req: UpdateMembershipRequest,
  ): Promise<GymMembership> {
    return this.memberships.updateMembership('admin', gymId, userId, req, 'admin');
  }
```

- [ ] **Step 5: Add the route**

In `apps/api/src/routes/admin.routes.mts`, add `UpdateMembershipRequest` to the contract import and this route after the `PUT /gyms/:id` route:

```ts
    .patch(
      "/memberships/:gymId/:userId",
      async ({ params, body }) => data(await adminFacade.updateMembership(params.gymId, params.userId, body)),
      { body: UpdateMembershipRequest },
    )
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/admin-facade.test.mts test/admin-routes.test.mts`
Expected: PASS

- [ ] **Step 7: Document the route**

In `apps/api/src/openapi.mts`, add alongside the other admin paths:

```ts
      "/api/v1/admin/memberships/{gymId}/{userId}": {
        patch: {
          summary: "Admin — update a membership (verify, change role, set status)",
          parameters: [
            { name: "gymId", in: "path", required: true, schema: { type: "string" } },
            { name: "userId", in: "path", required: true, schema: { type: "string" } },
          ],
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateMembershipRequest") } } },
          responses: ok(dataOf("GymMembership")),
        },
      },
```

- [ ] **Step 8: Run the whole API suite**

Run: `cd apps/api && bun test`
Expected: all PASS. Fix any remaining `RosterMember` literals missing `status`.

- [ ] **Step 9: Commit**

```bash
cd apps/api && bunx eslint --fix src/facades/admin.facade.mts src/routes/admin.routes.mts src/openapi.mts test
git add apps/api/src apps/api/test
git commit -m "feat(api): admin endpoint to update membership status"
```

---

### Task 7: Admin portal shows and sets member status

**Files:**
- Modify: `apps/admin/src/app/core/models/gym-membership.ts`
- Modify: `apps/admin/src/app/core/api/admin-api.service.ts:113-120`
- Modify: `apps/admin/src/app/features/members/members.ts`
- Modify: `apps/admin/src/app/features/members/members.html`
- Modify: `apps/admin/src/app/features/members/members.scss`

**Interfaces:**
- Consumes: `PATCH /api/v1/admin/memberships/:gymId/:userId` (Task 6).
- Produces:
  - `MembershipStatus` type in the admin models: `'pending' | 'active' | 'hidden' | 'inactive'`
  - `GymMembership.status?: MembershipStatus`, `statusUpdatedAt?: string`, `statusUpdatedBy?: string`
  - `AdminApiService.updateMembership(gymId: string, userId: string, body: { status: MembershipStatus }): Promise<GymMembership>`
  - Row test ids: `member-status`, `member-visible`, `member-hide`, `member-deactivate`, `member-reactivate`

- [ ] **Step 1: Widen the admin model**

Replace `apps/admin/src/app/core/models/gym-membership.ts`:

```ts
export type MembershipStatus = 'pending' | 'active' | 'hidden' | 'inactive';

export interface GymMembership {
  id: string;
  gymId: string;
  userId: string;
  status?: MembershipStatus;
  verifiedMember: boolean;
  gymRole?: string;
  isHome: boolean;
  visibleInRoster: boolean;
  joinMethod?: string;
  joinedAt: string;
  createdAt?: string;
  statusUpdatedAt?: string;
  statusUpdatedBy?: string;
}
```

Confirm `apps/admin/src/app/core/models/index.ts` re-exports this file with `export *` (it already exports `GymMembership`); if it names exports explicitly, add `MembershipStatus`.

- [ ] **Step 2: Add the service method**

In `apps/admin/src/app/core/api/admin-api.service.ts`, add `MembershipStatus` to the type-only import from `../models`, then add after `listMembers`:

```ts
  public updateMembership(
    gymId: string,
    userId: string,
    body: { status: MembershipStatus },
  ): Promise<GymMembership> {
    return firstValueFrom(
      this.http.patch<DataEnvelope<GymMembership>>(
        `${this.base}/api/v1/admin/memberships/${gymId}/${userId}`,
        body,
      ),
    ).then((res) => res.data);
  }
```

- [ ] **Step 3: Add the component logic**

Replace `apps/admin/src/app/features/members/members.ts`:

```ts
import { Component, inject, OnInit, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { GymMembership, MembershipStatus } from '@/core/models';
import { ZardBadgeComponent } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

@Component({
  selector: 'app-members',
  standalone: true,
  imports: [
    ZardBadgeComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
  ],
  templateUrl: './members.html',
  styleUrl: './members.scss',
  host: { 'data-testid': 'members-page' },
})
export class Members implements OnInit {

  private readonly api = inject(AdminApiService);

  public readonly members = signal<GymMembership[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly total = signal<number>(0);
  public readonly busyId = signal<string | null>(null);
  public readonly error = signal<string | null>(null);

  public async ngOnInit(): Promise<void> {
    await this.load();
  }

  public async setStatus(member: GymMembership, status: MembershipStatus): Promise<void> {
    if (this.busyId() !== null) return;
    this.busyId.set(member.id);
    this.error.set(null);
    try {
      const updated = await this.api.updateMembership(member.gymId, member.userId, { status });
      this.members.update((rows) => rows.map((r) => (r.id === updated.id ? updated : r)));
    } catch {
      this.error.set('Could not update that member. Please try again.');
    } finally {
      this.busyId.set(null);
    }
  }

  public badgeType(status: MembershipStatus | undefined): 'default' | 'destructive' | 'outline' {
    if (status === 'active' || status === undefined) return 'default';
    if (status === 'inactive') return 'destructive';
    return 'outline';
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    try {
      const envelope = await this.api.listMembers(1, 50);
      this.members.set(envelope.data);
      this.total.set(envelope.meta.total);
    } finally {
      this.loading.set(false);
    }
  }
}
```

If `ZardBadgeComponent`'s `zType` does not accept `'destructive'`, check the union in `apps/admin/src/app/shared/components/badge` and use the closest destructive-looking variant it does accept; keep `badgeType`'s return type in sync.

- [ ] **Step 4: Add the columns and actions to the template**

In `apps/admin/src/app/features/members/members.html`, add an error banner after the count paragraph:

```html
    @if (error()) {
      <p class="members-error" data-testid="members-error">{{ error() }}</p>
    }
```

Add two headers after `<th z-table-head>Status</th>`:

```html
            <th z-table-head>Visible</th>
            <th z-table-head>Actions</th>
```

Replace the status cell and add the two new cells before `</tr>`:

```html
              <td z-table-cell>
                <z-badge [zType]="badgeType(member.status)" data-testid="member-status">
                  {{ member.status ?? 'active' }}
                </z-badge>
              </td>
              <td z-table-cell>
                @if (member.visibleInRoster) {
                  <z-badge zType="outline" data-testid="member-visible">Visible</z-badge>
                } @else {
                  <z-badge zType="outline" data-testid="member-visible">Self-hidden</z-badge>
                }
              </td>
              <td z-table-cell>
                @if (busyId() === member.id) {
                  <z-spinner class="size-4" />
                } @else {
                  <div class="member-actions">
                    @if (member.status !== 'hidden') {
                      <button type="button" class="row-action" data-testid="member-hide"
                        (click)="setStatus(member, 'hidden')">Hide</button>
                    }
                    @if (member.status !== 'inactive') {
                      <button type="button" class="row-action" data-testid="member-deactivate"
                        (click)="setStatus(member, 'inactive')">Deactivate</button>
                    }
                    @if (member.status === 'hidden' || member.status === 'inactive') {
                      <button type="button" class="row-action" data-testid="member-reactivate"
                        (click)="setStatus(member, 'active')">Reactivate</button>
                    }
                  </div>
                }
              </td>
```

- [ ] **Step 5: Style the additions**

Append to `apps/admin/src/app/features/members/members.scss`:

```scss
.members-error {
  color: var(--destructive, #b3261e);
  font-size: 0.875rem;
  margin: 0 0 0.75rem;
}

.member-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

.row-action {
  background: none;
  border: none;
  padding: 0;
  font: inherit;
  font-weight: 600;
  color: var(--foreground, inherit);
  cursor: pointer;

  &:hover {
    text-decoration: underline;
  }
}
```

Check the variable names against the existing SCSS in `apps/admin/src/app/features/gyms/gyms.scss` and reuse whatever that file uses for its row actions rather than inventing new ones.

- [ ] **Step 6: Verify it builds**

Run: `cd apps/admin && bunx ng build`
Expected: build succeeds with no TypeScript errors.

- [ ] **Step 7: Commit**

```bash
cd apps/admin && bunx eslint --fix src/app/features/members src/app/core
git add apps/admin/src
git commit -m "feat(admin): member status column and status actions"
```

---

### Task 8: E2E coverage for the admin status change

**Files:**
- Modify: `apps/admin/e2e/seed/fixtures.ts`
- Modify: `apps/admin/e2e/serve-api.ts:60-75`
- Modify: `apps/admin/e2e/grids.spec.ts`

**Interfaces:**
- Consumes: the admin Members page from Task 7, the admin PATCH route from Task 6.
- Produces: `SeedMembership` interface and `gymMemberships` fixture array, both exported from `fixtures.ts`.

The seed currently inserts no memberships at all, which is why the Members page renders its empty state.

- [ ] **Step 1: Add the membership fixtures**

In `apps/admin/e2e/seed/fixtures.ts`, add the interface after `SeedOpenMat` (line 49):

```ts
export interface SeedMembership {
  _id: string;
  id: string;
  gymId: string;
  userId: string;
  status: 'pending' | 'active' | 'hidden' | 'inactive';
  verifiedMember: boolean;
  gymRole: 'member' | 'coach' | 'owner';
  isHome: boolean;
  visibleInRoster: boolean;
  joinMethod: 'self' | 'code' | 'invite';
  joinedAt: string;
  createdAt: string;
}
```

Add the fixture array at the end of the file. The ids below are the ones this file already seeds — `gym-e2e-001` (Austin BJJ Academy, line 67) and `user-e2e-001` through `user-e2e-004` from `buildUsers()` — so they resolve against real documents. `PAST_2025_01` and friends are the module-level timestamp constants at lines 55-59.

```ts
// ---------------------------------------------------------------------------
// Memberships — one per status so the admin grid exercises every badge
// ---------------------------------------------------------------------------

export const gymMemberships: SeedMembership[] = [
  {
    _id: 'mem-e2e-001', id: 'mem-e2e-001',
    gymId: 'gym-e2e-001', userId: 'user-e2e-001',
    status: 'active', verifiedMember: true, gymRole: 'member',
    isHome: true, visibleInRoster: true, joinMethod: 'self',
    joinedAt: PAST_2025_01, createdAt: PAST_2025_01,
  },
  {
    _id: 'mem-e2e-002', id: 'mem-e2e-002',
    gymId: 'gym-e2e-001', userId: 'user-e2e-002',
    status: 'hidden', verifiedMember: false, gymRole: 'member',
    isHome: false, visibleInRoster: true, joinMethod: 'code',
    joinedAt: PAST_2025_03, createdAt: PAST_2025_03,
  },
  {
    _id: 'mem-e2e-003', id: 'mem-e2e-003',
    gymId: 'gym-e2e-001', userId: 'user-e2e-003',
    status: 'inactive', verifiedMember: false, gymRole: 'member',
    isHome: false, visibleInRoster: true, joinMethod: 'invite',
    joinedAt: PAST_2025_06, createdAt: PAST_2025_06,
  },
  {
    _id: 'mem-e2e-004', id: 'mem-e2e-004',
    gymId: 'gym-e2e-001', userId: 'user-e2e-004',
    status: 'active', verifiedMember: true, gymRole: 'coach',
    isHome: false, visibleInRoster: false, joinMethod: 'self',
    joinedAt: PAST_2025_09, createdAt: PAST_2025_09,
  },
];
```

- [ ] **Step 2: Insert them in the seeder**

In `apps/admin/e2e/serve-api.ts`, add `gymMemberships` and `type SeedMembership` to the fixtures imports, then inside `seed()` add the drop alongside the others:

```ts
    await db.collection('gymMemberships').drop().catch(() => undefined);
```

and the insert after the open-mats insert:

```ts
    const membershipsResult = await db
      .collection<SeedMembership>('gymMemberships')
      .insertMany(gymMemberships);
    console.log(`[serve-api] Inserted ${membershipsResult.insertedCount} memberships`);
```

- [ ] **Step 3: Write the failing E2E test**

Append to `apps/admin/e2e/grids.spec.ts`:

```ts
test('members grid shows every status', async ({ page }) => {
  await page.goto('/members');
  await expect(page.getByTestId('members-grid')).toBeVisible();
  const statuses = await page.getByTestId('member-status').allInnerTexts();
  expect(statuses).toContain('active');
  expect(statuses).toContain('hidden');
  expect(statuses).toContain('inactive');
});

test('hiding a member updates its status badge', async ({ page }) => {
  await page.goto('/members');
  const row = page.getByTestId('member-row').filter({ hasText: 'active' }).first();
  await row.getByTestId('member-hide').click();
  await expect(row.getByTestId('member-status')).toHaveText('hidden');
});

test('reactivating a member restores active', async ({ page }) => {
  await page.goto('/members');
  const row = page.getByTestId('member-row').filter({ hasText: 'inactive' }).first();
  await row.getByTestId('member-reactivate').click();
  await expect(row.getByTestId('member-status')).toHaveText('active');
});
```

- [ ] **Step 4: Run the E2E suite**

MongoDB must be listening on `localhost:27017` first. If no local mongod is installed, start the in-memory one (`mongodb-memory-server` is already a devDependency of `apps/api`):

```bash
cd apps/api
cat > .tmp-mongo-mem.mts <<'EOF'
import './src/db/bson-bun-shim.mjs';
const { MongoMemoryServer } = await import('mongodb-memory-server');
const server = await MongoMemoryServer.create({ instance: { port: 27017 } });
console.log(`[mongo-mem] listening at ${server.getUri()}`);
await new Promise<void>(() => {});
EOF
bun .tmp-mongo-mem.mts &
```

Then:

```bash
cd apps/admin && bunx playwright test
```

Expected: PASS, including the two pre-existing grid tests. Note that the three new tests mutate the seeded data and the seeder drops collections on every run, so they are order-dependent within a run but repeatable across runs. Delete `apps/api/.tmp-mongo-mem.mts` and stop the background process when finished — it is a scratch helper, not a committed file.

- [ ] **Step 5: Commit**

```bash
cd apps/admin && bunx eslint --fix e2e
git add apps/admin/e2e
git commit -m "test(admin): e2e coverage for member status changes"
```

---

### Task 9: Mobile data layer — manage roster and status mutation

**Files:**
- Modify: `apps/mobile/lib/features/membership/models/roster_member.dart`
- Modify: `apps/mobile/lib/features/membership/models/gym_membership.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart:60-66`
- Modify: `apps/mobile/lib/features/membership/data/membership_repository.dart`

**Interfaces:**
- Consumes: `GET /api/v1/gyms/:id/members?includeHidden=true` (Task 5), `PATCH /api/v1/gyms/:id/members/:userId` with `status` (Task 5).
- Produces:
  - `RosterMember.status` — `String`, defaulting to `'active'` when absent so an older API build still parses.
  - `GymMembership.statusUpdatedAt`, `GymMembership.statusUpdatedBy` — `String?`.
  - `Endpoints.gymMembersManage(String gymId)` → `/api/v1/gyms/$gymId/members?includeHidden=true`
  - `MembershipRepository.manageRoster(String gymId)` → `Future<List<RosterMember>>`
  - `MembershipRepository.manageMember(..., {bool? verifiedMember, String? gymRole, String? status})`
  - `manageRosterProvider` — `FutureProvider.family<List<RosterMember>, String>`
  - `rosterProvider` unchanged, so every existing consumer keeps its current behaviour.

- [ ] **Step 1: Add `status` to the roster model**

In `apps/mobile/lib/features/membership/models/roster_member.dart`, add the field, the constructor parameter, and the parse:

```dart
  final String status;
```

```dart
    this.status = 'active',
```

```dart
        status: json['status'] as String? ?? 'active',
```

Also add two convenience getters at the end of the class:

```dart
  bool get isHidden => status == 'hidden';
  bool get isInactive => status == 'inactive';
```

- [ ] **Step 2: Add the audit fields to the membership model**

In `apps/mobile/lib/features/membership/models/gym_membership.dart`, add:

```dart
  final String? statusUpdatedAt;
  final String? statusUpdatedBy;
```

```dart
    this.statusUpdatedAt,
    this.statusUpdatedBy,
```

```dart
        statusUpdatedAt: json['statusUpdatedAt'] as String?,
        statusUpdatedBy: json['statusUpdatedBy'] as String?,
```

- [ ] **Step 3: Add the endpoint**

In `apps/mobile/lib/core/api/endpoints.dart`, after `gymMembers`:

```dart
  /// Owner/coach/admin roster — also returns hidden and inactive members.
  static String gymMembersManage(String gymId) => '/api/v1/gyms/$gymId/members?includeHidden=true';
```

- [ ] **Step 4: Extend the repository**

In `apps/mobile/lib/features/membership/data/membership_repository.dart`, add to the abstract class:

```dart
  Future<List<RosterMember>> manageRoster(String gymId);
```

and change the `manageMember` signature there to:

```dart
  Future<GymMembership> manageMember(
    String gymId,
    String userId, {
    bool? verifiedMember,
    String? gymRole,
    String? status,
  });
```

In `ApiMembershipRepository`, add the new method next to `roster`:

```dart
  @override
  Future<List<RosterMember>> manageRoster(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymMembersManage(gymId));
      return unwrapList(res.data as Map<String, dynamic>).items.map(RosterMember.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
```

and update `manageMember`:

```dart
  @override
  Future<GymMembership> manageMember(
    String gymId,
    String userId, {
    bool? verifiedMember,
    String? gymRole,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{
        if (verifiedMember != null) 'verifiedMember': verifiedMember,
        if (gymRole != null) 'gymRole': gymRole,
        if (status != null) 'status': status,
      };
      final res = await _dio.patch(Endpoints.gymMember(gymId, userId), data: body);
      return GymMembership.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
```

- [ ] **Step 5: Add the provider**

At the bottom of the same file, after `rosterProvider`:

```dart
/// Manager-only roster: also carries hidden and inactive members. Deliberately
/// separate from [rosterProvider] so the DM picker, class assignment, and
/// permission derivations keep seeing only active, visible members.
final manageRosterProvider = FutureProvider.family<List<RosterMember>, String>((ref, gymId) {
  return ref.read(membershipRepositoryProvider).manageRoster(gymId);
});
```

- [ ] **Step 6: Verify it analyzes clean**

Run: `cd apps/mobile && flutter analyze`
Expected: no new errors. Any test fake implementing `MembershipRepository` will now fail to compile — add `manageRoster` and the `status` parameter to each fake. Search for them with:

Run: `cd apps/mobile && grep -rln "implements MembershipRepository" test lib`

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): manage-roster provider and member status mutation"
```

---

### Task 10: Mobile roster UI — badges, dimming, and status actions

**Files:**
- Modify: `apps/mobile/lib/features/gyms/data/gym_permissions.dart`
- Modify: `apps/mobile/lib/features/membership/screens/roster_screen.dart`

**Interfaces:**
- Consumes: `manageRosterProvider`, `manageMember(..., status:)`, `RosterMember.status/isHidden/isInactive` (Task 9); `myMembershipsProvider` (existing).
- Produces: no new public API.

**Why `gym_permissions` changes:** both derivations currently read the caller's own `gymRole` and membership out of `rosterProvider`. A member who is hidden — by their own `visibleInRoster` toggle today, or by an owner after this feature ships — is absent from that list, so the UI would silently revoke their forum access even though the server still grants it. Deriving the caller's own membership from `myMembershipsProvider` fixes that and is a prerequisite for the roster screen, which can no longer compute `canManage` from a list it has to know `canManage` to fetch.

- [ ] **Step 1: Derive self-membership from the caller's own memberships**

Replace the body of both functions in `apps/mobile/lib/features/gyms/data/gym_permissions.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../membership/data/membership_repository.dart';

/// Shared gym-permission derivations.
///
/// Both the gym detail screen and the My Gym tab need to know whether the
/// current user can manage a gym (owner/coach/admin) or access its forum
/// (member/owner/admin). These mirror the server-side checks
/// (`assertCanManageGym`, `assertActiveMember`) so a gated UI action never
/// points at an endpoint that will reject it. Kept in one place so the two
/// call sites can't drift.
///
/// The caller's own membership comes from [myMembershipsProvider], never from
/// [rosterProvider]: a hidden member is absent from the roster but still holds
/// their privileges server-side, so deriving from the roster would revoke
/// access the API would have granted.

/// True when a membership status grants gym-member privileges. Mirrors
/// `hasMemberPrivileges` in @bjj/contract.
bool _hasPrivileges(String status) => status == 'active' || status == 'hidden';

/// True when the current user can manage [gymId] — i.e. the gym's owner, an
/// admin, or holds `owner`/`coach` role on an active or hidden membership.
bool deriveCanManageGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId && myId != null;
  final mine = ref.watch(myMembershipsProvider).maybeWhen(
        data: (rows) => rows.where((m) => m.gymId == gymId).firstOrNull,
        orElse: () => null,
      );
  final canManageViaRole =
      mine != null && _hasPrivileges(mine.status) && (mine.gymRole == 'owner' || mine.gymRole == 'coach');
  return isAdmin || isOwner || canManageViaRole;
}

/// True when the current user can access [gymId]'s forum — i.e. holds member
/// privileges there, owns the gym, or is an admin.
bool deriveCanAccessForumGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  if (myId == null) return false;
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId;
  final mine = ref.watch(myMembershipsProvider).maybeWhen(
        data: (rows) => rows.where((m) => m.gymId == gymId).firstOrNull,
        orElse: () => null,
      );
  return isAdmin || isOwner || (mine != null && _hasPrivileges(mine.status));
}
```

The `join_gym_button.dart` import is no longer needed here — remove it only if nothing else in the file uses it; `flutter analyze` will flag it as unused.

- [ ] **Step 2: Compute `canManage` before choosing the roster provider**

In `apps/mobile/lib/features/membership/screens/roster_screen.dart`, replace the `build` method of `RosterScreen`:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymOwnerId = ref
        .watch(gymByIdProvider(gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);

    // canManage must be derived WITHOUT the roster: a manager needs it to
    // decide which roster to request in the first place. Own membership comes
    // from myMembershipsProvider, which is not visibility-filtered.
    final canManage = deriveCanManageGym(ref, gymId: gymId, ownerId: gymOwnerId);
    final async = canManage
        ? ref.watch(manageRosterProvider(gymId))
        : ref.watch(rosterProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
        title: Text('Members', style: t.h2Style),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load roster", style: t.bodyStyle.copyWith(color: t.muted)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.invalidate(rosterProvider(gymId));
                  ref.invalidate(manageRosterProvider(gymId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) => members.isEmpty
            ? Center(child: Text('No members yet.', style: t.bodyStyle.copyWith(color: t.muted)))
            : _RosterGrid(t: t, members: members, gymId: gymId, canManage: canManage),
      ),
    );
  }
```

Add the import for the permission helper:

```dart
import '../../gyms/data/gym_permissions.dart';
```

The old `build` computed `myMember`, `myGymRole`, `isAdmin`, and `isOwner` inline; all four are gone, replaced by `deriveCanManageGym`. `currentUserIdProvider` and `authStateProvider` are no longer referenced in this file — let `flutter analyze` point out the unused `core/auth/auth_service.dart` import and remove it if nothing else in the file uses it.

- [ ] **Step 3: Dim and badge non-active cells**

In `_RosterCell.build`, wrap the returned `InkWell` in an `Opacity` and add the status badge. Replace the `return InkWell(` line with:

```dart
    return Opacity(
      opacity: member.status == 'active' ? 1.0 : 0.55,
      child: InkWell(
```

and close the extra widget at the end of that method — the closing `);` of the `InkWell` becomes `),\n    );`.

Add the badge immediately after the existing role-badge block, still inside the `Column`'s `children`:

```dart
          if (member.isHidden || member.isInactive) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (member.isInactive ? t.red : t.muted).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: (member.isInactive ? t.red : t.muted).withValues(alpha: 0.35)),
              ),
              child: Text(
                member.isInactive ? 'Inactive' : 'Hidden',
                style: t.miniStyle.copyWith(
                  fontSize: 9,
                  color: member.isInactive ? t.red : t.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
```

Check `AppTokens` in `apps/mobile/lib/core/design/tokens.dart` for the actual destructive colour name — the file already exposes `green`, `gold`, and `primary`; if there is no `red`, use whichever token that file defines for errors and keep the two references consistent.

- [ ] **Step 4: Add the status actions to the manage row**

In `_ManageRowState`, invalidate both providers in `_runAction`:

```dart
      await action();
      ref.invalidate(rosterProvider(widget.gymId));
      ref.invalidate(manageRosterProvider(widget.gymId));
```

Add the three action methods after `_makeCoach`:

```dart
  Future<void> _setStatus(String status) => _runAction(() async {
        await ref.read(membershipRepositoryProvider).manageMember(
              widget.gymId,
              widget.member.userId,
              status: status,
            );
      });
```

and add the buttons to the `Wrap`'s children, after the "Make coach" button:

```dart
        if (widget.member.status == 'active')
          _SmallIconBtn(
            icon: Icons.visibility_off,
            tooltip: 'Hide from roster',
            color: widget.t.muted,
            onTap: () => _setStatus('hidden'),
          ),
        if (widget.member.status != 'inactive')
          _SmallIconBtn(
            icon: Icons.person_off,
            tooltip: 'Mark inactive',
            color: widget.t.red,
            onTap: () => _setStatus('inactive'),
          ),
        if (widget.member.isHidden || widget.member.isInactive)
          _SmallIconBtn(
            icon: Icons.restart_alt,
            tooltip: 'Reactivate',
            color: widget.t.green,
            onTap: () => _setStatus('active'),
          ),
```

- [ ] **Step 5: Analyze and format**

Run: `cd apps/mobile && flutter analyze && dart format lib`
Expected: no errors.

- [ ] **Step 6: Run the mobile test suite**

Run: `cd apps/mobile && flutter test`
Expected: PASS. Any widget test that pumps `RosterScreen` now also needs `gymByIdProvider` and `myMembershipsProvider` overrides — add them to the affected tests' `ProviderScope` overrides rather than reverting the derivation change.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): badge hidden and inactive members with status actions"
```

---

### Task 11: Full verification

**Files:** none — this task only runs things.

- [ ] **Step 1: API suite**

Run: `cd apps/api && bun test 2>&1 | tail -15`
Expected: all PASS, zero skipped.

- [ ] **Step 2: Admin build**

Run: `cd apps/admin && bunx ng build 2>&1 | tail -10`
Expected: success.

- [ ] **Step 3: Admin E2E**

With mongod on 27017: `cd apps/admin && bunx playwright test 2>&1 | tail -10`
Expected: all PASS.

- [ ] **Step 4: Mobile**

Run: `cd apps/mobile && flutter analyze && flutter test 2>&1 | tail -10`
Expected: no analyzer errors, all tests PASS.

- [ ] **Step 5: Lint the whole change**

Run: `cd apps/api && bunx eslint src test` and `cd apps/admin && bunx eslint src e2e`
Expected: zero errors.

- [ ] **Step 6: Manual smoke against a running stack**

Start the API and hit both roster modes to confirm the public payload really is unchanged:

```bash
curl -s "http://localhost:3100/api/v1/gyms/gym-e2e-001/members" | head -c 400
curl -s "http://localhost:3100/api/v1/gyms/gym-e2e-001/members?includeHidden=true" | head -c 400
```

Expected: the first returns only active, roster-visible members; the second returns 403 without a manager token. Confirm the 403 — an unauthenticated `includeHidden=true` that returns data is a security failure, not a passing test.

- [ ] **Step 7: Verify no scratch files are committed**

Run: `git status --short`
Expected: no `.tmp-*` files, no `screenshots/`, no `test-results/`.

- [ ] **Step 8: Commit any remaining fixes**

```bash
git add -A apps packages
git commit -m "test: fix fallout from widened membership status"
```

(Skip this step if the tree is already clean.)
