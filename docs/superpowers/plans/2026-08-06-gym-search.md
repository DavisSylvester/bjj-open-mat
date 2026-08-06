# Gym Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let students search for gyms near them by GPS or ZIP, see full gym details, and lay a ranking seam for future paid placement.

**Architecture:** Extend the existing `GET /api/v1/gyms/nearby` into a real search endpoint — one `$geoNear` pipeline gains text matching, a rank-then-distance sort, and `$facet` paging. Auto-widening of the radius is a facade-level product policy, not a query concern. The mobile app adds an `Open Mats | Gyms` toggle to the existing `/search` screen, reusing its radius/ZIP/location chrome.

**Tech Stack:** Bun, Elysia, TypeBox (`@bjj/contract`), MongoDB 7 driver, Flutter + Riverpod, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-06-gym-search-design.md`

## Global Constraints

- TypeScript strict mode. No `any`. Explicit return types and access modifiers on all functions/methods.
- TypeBox for all validation. Never Zod.
- `.mts` source files; import specifiers use `.mjs`.
- Single quotes, trailing commas in multiline, named exports.
- Conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). **Never add Co-Authored-By lines.**
- Branch is `feature/gym-search`, already created off `main`.
- **`bun test` does not type-check.** After each API task run `cd apps/api && bunx tsc --noEmit 2>&1 | grep -cE "^src/"` — must print `0`.
- **Known pre-existing failures — do not chase:** `test/device.routes.test.mts` (5 tests, 5s timeouts). Repo-wide `eslint` reports ~250 pre-existing errors; lint only files you changed.
- API tests needing MongoDB expect a mongod on `localhost:27017`.
- Validation failures return **400**, not 422 (`apps/api/src/http/error-handler.mts:17`).
- Health endpoints are `/health` and `/ready`. Never `/healthz`.
- Never run `dart format` in `apps/mobile` — it rewrites 226 of 260 files.
- Distances: the API speaks **kilometres**; the mobile UI speaks **miles**. Convert at the UI boundary only (`mi * 1.60934`).

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `apps/api/test/gym-search.e2e.test.mts` | HTTP E2E: ZIP 75495 → 50-mile widening. CI gate. |
| `.github/workflows/ci.yml` | Runs the E2E on PR + push to main; blocks deploy. |
| `apps/mobile/lib/features/gyms/data/gym_search_query.dart` | Immutable query value object → query params. |
| `apps/mobile/lib/features/gyms/models/gym_search_page.dart` | One page of results: items, total, effectiveRadiusKm. |
| `apps/mobile/lib/features/gyms/data/gym_search_repository.dart` | HTTP call + envelope unwrap. |
| `apps/mobile/lib/features/gyms/data/gym_search_controller.dart` | Paging StateNotifier: accumulates pages. |
| `apps/mobile/integration_test/gym_search_test.dart` | Local-only Flutter e2e. |
| `scripts/e2e-gym-search.mjs` | Emulator driver for the above. |
| `apps/mobile/test/gyms/gym_search_query_test.dart` | Unit test for query param building. |
| `apps/mobile/test/gyms/gym_search_page_test.dart` | Unit test for page parsing. |
| `apps/mobile/test/gyms/gym_search_controller_test.dart` | Unit test for paging/accumulation. |

**Modify:**

| Path | Change |
|---|---|
| `packages/contract/src/schemas/requests/gym-requests.mts:53` | `NearbyQuery` gains `zip`, `q`, `page`, `limit`; `lat`/`lng` optional. |
| `packages/contract/src/schemas/gym.mts` | `Gym` gains `rankBoost`, `sponsored`. |
| `packages/contract/src/schemas/responses/envelope.mts:3` | `ListMeta` gains optional `effectiveRadiusKm`. |
| `apps/api/src/repositories/gym.repository.mts:85` | `findNearby` → `searchNearby`. |
| `apps/api/src/facades/gym.facade.mts:76` | `nearby` → `searchNearby` with widening + origin resolution. |
| `apps/api/src/routes/gym.routes.mts` | `/nearby` handler wires the new query and meta. |
| `apps/api/test/gym.repository.test.mts` | Updated for `searchNearby`. |
| `.github/workflows/api-deploy.yml` | Gains `needs: [ci]`. |
| `apps/mobile/lib/features/gyms/models/gym.dart` | Parse `sponsored`, `rankBoost`. |
| `apps/mobile/lib/features/search/screens/search_screen.dart` | Mode toggle + gym results branch. |
| `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` | Contact block + amenities. |
| `apps/mobile/lib/core/api/endpoints.dart` | (No change — `gymsNearby` already exists.) |
| `package.json` | `mobile:e2e:gyms` script. |

---

## Task 1: Contract — query, gym fields, list meta

**Files:**
- Modify: `packages/contract/src/schemas/requests/gym-requests.mts:53-61`
- Modify: `packages/contract/src/schemas/gym.mts:27`
- Modify: `packages/contract/src/schemas/responses/envelope.mts:3-6`

**Interfaces:**
- Consumes: nothing.
- Produces: `NearbyQuery` with `{ lat?: number; lng?: number; zip?: string; q?: string; radiusKm?: number; page?: number; limit?: number }`; `Gym` with `rankBoost?: number` and `sponsored?: boolean`; `ListMeta` with `effectiveRadiusKm?: number`.

- [ ] **Step 1: Widen `NearbyQuery`**

Replace lines 53-61 of `packages/contract/src/schemas/requests/gym-requests.mts`:

```ts
// lat/lng are optional because `zip` is an alternative origin. The route
// enforces that exactly one origin resolves; TypeBox cannot express "one of"
// across sibling optionals without an awkward union, and a union here would
// degrade the generated OpenAPI for a rule that is one line of code.
export const NearbyQuery = t.Object(
  {
    lat: t.Optional(t.Number()),
    lng: t.Optional(t.Number()),
    zip: t.Optional(t.String({ pattern: '^\\d{5}$' })),
    q: t.Optional(t.String({ maxLength: 100 })),
    radiusKm: t.Optional(t.Number({ minimum: 1, maximum: 500, default: 25 })),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 50, default: 20 })),
  },
  { $id: 'NearbyQuery' },
);
export type NearbyQuery = Static<typeof NearbyQuery>;
```

- [ ] **Step 2: Add the ranking seam to `Gym`**

In `packages/contract/src/schemas/gym.mts`, insert after `distanceKm` (line 27):

```ts
    // Ranking seam for future paid placement. Nothing writes rankBoost today;
    // the search sort reads it so that selling placement later is a write path
    // plus a badge, not a contract change. `sponsored` is derived at read time
    // as rankBoost > 0 and is never persisted.
    rankBoost: t.Optional(t.Integer({ default: 0 })),
    sponsored: t.Optional(t.Boolean({ default: false })),
```

- [ ] **Step 3: Add `effectiveRadiusKm` to `ListMeta`**

Replace lines 3-6 of `packages/contract/src/schemas/responses/envelope.mts`:

```ts
export const ListMeta = t.Object(
  {
    page: t.Integer({ minimum: 1 }),
    limit: t.Integer({ minimum: 1 }),
    total: t.Integer({ minimum: 0 }),
    // Present only on geo searches. The radius that actually produced these
    // results — differs from the requested radius when the search auto-widened.
    effectiveRadiusKm: t.Optional(t.Number({ minimum: 0 })),
  },
  { $id: 'ListMeta' },
);
```

Optional, so every existing `list()` call site stays valid.

- [ ] **Step 4: Type-check the contract package**

Run: `cd packages/contract && bunx tsc --noEmit`
Expected: no errors. If `apps/api` now fails to compile, that is expected — Task 2 and 3 fix it.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/schemas/requests/gym-requests.mts packages/contract/src/schemas/gym.mts packages/contract/src/schemas/responses/envelope.mts
git commit -m "feat(contract): add gym search query, ranking seam, and effectiveRadiusKm"
```

---

## Task 2: Repository — `searchNearby`

**Files:**
- Modify: `apps/api/src/repositories/gym.repository.mts:85-100`
- Test: `apps/api/test/gym.repository.test.mts`

**Interfaces:**
- Consumes: `Gym` from Task 1.
- Produces:
  ```ts
  export interface GymSearchOptions {
    lat: number;
    lng: number;
    radiusKm: number;
    q?: string;
    skip: number;
    limit: number;
  }
  public async searchNearby(opts: GymSearchOptions): Promise<{ items: Gym[]; total: number }>
  ```
  `findNearby` is **removed**, not kept alongside.

- [ ] **Step 1: Write the failing tests**

Replace the whole body of `apps/api/test/gym.repository.test.mts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { MongoClient } from 'mongodb';
import { GymRepository } from '../src/repositories/gym.repository.mts';

const client = new MongoClient(process.env['MONGODB_URI'] ?? 'mongodb://localhost:27017', { timeoutMS: 4000 });
const db = client.db('bjj_test_gyms');
const repo = new GymRepository(db);

// San Diego. ~0.1 km apart so ordering is driven by rankBoost, not distance.
const ORIGIN = { lat: 32.9, lng: -117.21 };

beforeAll(async () => {
  await db.dropDatabase();
  await repo.ensureIndexes();
  await repo.insert({
    id: 'g-1', name: 'Atos', address: '9587 Distribution Ave', city: 'San Diego',
    amenities: [], isVerified: true, location: { lat: 32.901, lng: -117.213 },
    joinCode: 'SECRET1', ownerId: 'owner-1',
  });
  await repo.insert({
    id: 'g-2', name: 'Alliance (North)', address: '100 Main St', city: 'Poway',
    amenities: [], isVerified: false, location: { lat: 32.902, lng: -117.214 },
    joinCode: 'SECRET2', ownerId: 'owner-2',
  });
  // Far away — outside every radius used below.
  await repo.insert({
    id: 'g-3', name: 'Gracie Barra', address: '1 Far Rd', city: 'Phoenix',
    amenities: [], isVerified: false, location: { lat: 33.45, lng: -112.07 },
  });
});

afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe('GymRepository.searchNearby', () => {
  it('returns gyms in radius with distanceKm, nearest first', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.total).toBe(2);
    expect(r.items.map((g) => g.id)).toEqual(['g-1', 'g-2']);
    expect(r.items[0]?.distanceKm).toBeGreaterThanOrEqual(0);
  });

  it('excludes gyms outside the radius', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.items.some((g) => g.id === 'g-3')).toBe(false);
  });

  it('filters by q on name', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: 'atos', skip: 0, limit: 20 });
    expect(r.total).toBe(1);
    expect(r.items[0]?.id).toBe('g-1');
  });

  it('filters by q on city', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: 'poway', skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(['g-2']);
  });

  it('treats regex metacharacters in q as literal text', async () => {
    // Unescaped, "(North)" is a capture group and would match "Atos" too.
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, q: 'Alliance (North)', skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(['g-2']);
  });

  it('orders a boosted gym ahead of a nearer unboosted one', async () => {
    await repo.update('g-2', { rankBoost: 10 } as never);
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(['g-2', 'g-1']);
    await repo.update('g-2', { rankBoost: 0 } as never);
  });

  it('pages: total is the full count, items is the page', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 1 });
    expect(r.total).toBe(2);
    expect(r.items).toHaveLength(1);
  });

  it('never returns joinCode or ownerId', async () => {
    const r = await repo.searchNearby({ ...ORIGIN, radiusKm: 25, skip: 0, limit: 20 });
    for (const gym of r.items) {
      expect(gym.joinCode).toBeUndefined();
      expect(gym.ownerId).toBeUndefined();
    }
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/api && bun test test/gym.repository.test.mts`
Expected: FAIL — `repo.searchNearby is not a function`.

- [ ] **Step 3: Implement `searchNearby`**

In `apps/api/src/repositories/gym.repository.mts`, add above the class (after `fromDoc`):

```ts
/**
 * Escape regex metacharacters so user text is matched literally. Without this a
 * gym named "Alliance (North)" is unsearchable (the parens become a group) and
 * a crafted `q` is a ReDoS vector.
 */
function escapeRegex(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export interface GymSearchOptions {
  lat: number;
  lng: number;
  radiusKm: number;
  q?: string;
  skip: number;
  limit: number;
}

interface FacetResult {
  total: { n: number }[];
  items: (GymDoc & { distanceMeters: number })[];
}
```

Then replace `findNearby` (lines 85-100) with:

```ts
  public async searchNearby(opts: GymSearchOptions): Promise<{ items: Gym[]; total: number }> {
    const col = this.collection<GymDoc>(COLLECTIONS.gyms);
    const q = opts.q?.trim();

    const pipeline: Document[] = [
      {
        // $geoNear must be the first stage in the pipeline. It both filters by
        // maxDistance and emits distanceMeters for the sort below.
        $geoNear: {
          near: { type: 'Point', coordinates: [opts.lng, opts.lat] },
          distanceField: 'distanceMeters',
          maxDistance: opts.radiusKm * 1000,
          spherical: true,
        },
      },
    ];

    if (q) {
      const rx = { $regex: escapeRegex(q), $options: 'i' };
      pipeline.push({ $match: { $or: [{ name: rx }, { city: rx }] } });
    }

    // Normalize the missing field to 0 before sorting: no document carries
    // rankBoost today, and sorting on a missing field orders by BSON
    // null-vs-integer rules rather than by distance.
    pipeline.push({ $addFields: { rankBoost: { $ifNull: ['$rankBoost', 0] } } });

    // joinCode is a gym's roster-join secret and this endpoint is public.
    // ownerId is not the caller's business either. getById is unaffected.
    pipeline.push({ $project: { joinCode: 0, ownerId: 0 } });

    pipeline.push({
      $facet: {
        total: [{ $count: 'n' }],
        items: [{ $sort: { rankBoost: -1, distanceMeters: 1 } }, { $skip: opts.skip }, { $limit: opts.limit }],
      },
    });

    const [res] = await col.aggregate<FacetResult>(pipeline).toArray();
    return {
      items: (res?.items ?? []).map((d) => fromDoc(d) as Gym),
      total: res?.total[0]?.n ?? 0,
    };
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/gym.repository.test.mts`
Expected: 8 pass, 0 fail. `apps/api` will still fail `tsc` because `gym.facade.mts` references the removed `findNearby` — Task 3 fixes that.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/gym.repository.mts apps/api/test/gym.repository.test.mts
git commit -m "feat(api): replace findNearby with paged, text-filtered searchNearby"
```

---

## Task 3: Facade — origin resolution, auto-widening, `sponsored`

**Files:**
- Modify: `apps/api/src/facades/gym.facade.mts:20` (constructor `Pick`), `:76-78` (`nearby`)
- Test: `apps/api/test/gym.facade.test.mts`

**Interfaces:**
- Consumes: `GymRepository.searchNearby` (Task 2), `Geocoder.lookupZip`.
- Produces:
  ```ts
  export interface GymSearchRequest {
    lat?: number;
    lng?: number;
    zip?: string;
    q?: string;
    radiusKm: number;
    page: number;
    limit: number;
  }
  public async searchNearby(req: GymSearchRequest):
    Promise<{ items: Gym[]; total: number; effectiveRadiusKm: number }>
  ```
  `nearby` is removed.

- [ ] **Step 1: Write the failing tests**

Append to `apps/api/test/gym.facade.test.mts` (keep existing imports; add `GymFacade` and `AppError` if absent):

```ts
describe('GymFacade.searchNearby', () => {
  // Minimal stubs. `calls` records every radius the facade tried, in order —
  // that sequence IS the widening behaviour under test.
  function makeFacade(resultsByRadius: Record<number, string[]>): {
    facade: GymFacade;
    calls: number[];
  } {
    const calls: number[] = [];
    const gyms = {
      searchNearby: async (opts: { radiusKm: number; skip: number; limit: number }) => {
        calls.push(opts.radiusKm);
        const ids = resultsByRadius[opts.radiusKm] ?? [];
        return {
          items: ids.slice(opts.skip, opts.skip + opts.limit).map((id) => ({
            id, name: id, address: 'a', amenities: [], isVerified: false,
          })),
          total: ids.length,
        };
      },
    };
    const geocoder = { lookupZip: (zip: string) => (zip === '75495' ? { lat: 33.4292, lng: -96.5486 } : null) };
    const facade = new GymFacade(
      gyms as never, {} as never, () => 'id', geocoder as never, {} as never,
    );
    return { facade, calls };
  }

  it('resolves a zip to coordinates', async () => {
    const { facade } = makeFacade({ 40: ['g-1'] });
    const r = await facade.searchNearby({ zip: '75495', radiusKm: 40, page: 1, limit: 20 });
    expect(r.items.map((g) => g.id)).toEqual(['g-1']);
    expect(r.effectiveRadiusKm).toBe(40);
  });

  it('rejects a request with no origin', async () => {
    const { facade } = makeFacade({});
    await expect(facade.searchNearby({ radiusKm: 40, page: 1, limit: 20 })).rejects.toThrow('lat/lng or zip is required');
  });

  it('rejects an unresolvable zip', async () => {
    const { facade } = makeFacade({});
    await expect(facade.searchNearby({ zip: '00000', radiusKm: 40, page: 1, limit: 20 })).rejects.toThrow('Unknown ZIP code');
  });

  it('prefers explicit coordinates over zip', async () => {
    const { facade } = makeFacade({ 40: ['g-1'] });
    const r = await facade.searchNearby({ lat: 1, lng: 2, zip: '00000', radiusKm: 40, page: 1, limit: 20 });
    expect(r.items).toHaveLength(1);
  });

  it('widens the radius when page 1 is empty', async () => {
    const { facade, calls } = makeFacade({ 80: ['g-1'] });
    const r = await facade.searchNearby({ lat: 33.4292, lng: -96.5486, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40, 80]);
    expect(r.effectiveRadiusKm).toBe(80);
    expect(r.items.map((g) => g.id)).toEqual(['g-1']);
  });

  it('stops widening at the 161 km cap after two steps', async () => {
    const { facade, calls } = makeFacade({});
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40, 80, 160]);
    expect(r.effectiveRadiusKm).toBe(160);
    expect(r.items).toHaveLength(0);
  });

  it('does not widen when page 1 has results', async () => {
    const { facade, calls } = makeFacade({ 40: ['g-1'], 80: ['g-1', 'g-2'] });
    await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(calls).toEqual([40]);
  });

  it('does not widen on page 2', async () => {
    const { facade, calls } = makeFacade({ 80: [] });
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 80, page: 2, limit: 20 });
    expect(calls).toEqual([80]);
    expect(r.effectiveRadiusKm).toBe(80);
  });

  it('derives sponsored from rankBoost', async () => {
    const gyms = {
      searchNearby: async () => ({
        items: [
          { id: 'a', name: 'a', address: 'x', amenities: [], isVerified: false, rankBoost: 5 },
          { id: 'b', name: 'b', address: 'x', amenities: [], isVerified: false },
        ],
        total: 2,
      }),
    };
    const facade = new GymFacade(gyms as never, {} as never, () => 'id', {} as never, {} as never);
    const r = await facade.searchNearby({ lat: 1, lng: 2, radiusKm: 40, page: 1, limit: 20 });
    expect(r.items[0]?.sponsored).toBe(true);
    expect(r.items[1]?.sponsored).toBe(false);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/api && bun test test/gym.facade.test.mts`
Expected: FAIL — `facade.searchNearby is not a function`.

- [ ] **Step 3: Implement the facade method**

In `apps/api/src/facades/gym.facade.mts`, change the constructor's first parameter type (line 20) from `"findNearby"` to `"searchNearby"`:

```ts
    private readonly gyms: Pick<GymRepository, 'insert' | 'findById' | 'update' | 'list' | 'listByOwner' | 'searchNearby'>,
```

Add above the class:

```ts
/** 100 miles. Widening never exceeds this. */
const WIDEN_CAP_KM = 161;
/** Number of doublings attempted after the requested radius. */
const WIDEN_STEPS = 2;

export interface GymSearchRequest {
  lat?: number;
  lng?: number;
  zip?: string;
  q?: string;
  radiusKm: number;
  page: number;
  limit: number;
}
```

Replace `nearby` (lines 76-78) with:

```ts
  /**
   * Geo gym search. Resolves the origin (coords win over zip), then walks a
   * widening radius ladder until something is found.
   *
   * Widening is a product policy, not a query concern, which is why it lives
   * here and not in the repository: an empty first page in a rural area should
   * quietly reach further rather than show the user nothing. It applies ONLY to
   * an empty page 1 — a partial page is a real answer, and widening mid-paging
   * would shuffle the result set under the user. Clients page through the
   * returned effectiveRadiusKm to stay on one stable set.
   */
  public async searchNearby(
    req: GymSearchRequest,
  ): Promise<{ items: Gym[]; total: number; effectiveRadiusKm: number }> {
    const origin = this.resolveOrigin(req);
    const skip = (req.page - 1) * req.limit;
    const ladder = req.page === 1 ? buildRadiusLadder(req.radiusKm) : [req.radiusKm];

    let last = { items: [] as Gym[], total: 0 };
    let effectiveRadiusKm = req.radiusKm;

    for (const radiusKm of ladder) {
      effectiveRadiusKm = radiusKm;
      last = await this.gyms.searchNearby({ ...origin, radiusKm, q: req.q, skip, limit: req.limit });
      if (last.items.length > 0) break;
    }

    return {
      items: last.items.map((gym) => ({ ...gym, sponsored: (gym.rankBoost ?? 0) > 0 })),
      total: last.total,
      effectiveRadiusKm,
    };
  }

  private resolveOrigin(req: GymSearchRequest): { lat: number; lng: number } {
    if (typeof req.lat === 'number' && typeof req.lng === 'number') {
      return { lat: req.lat, lng: req.lng };
    }
    if (req.zip) {
      const resolved = this.geocoder.lookupZip(req.zip);
      if (!resolved) throw new AppError('bad_request', 'Unknown ZIP code');
      return { lat: resolved.lat, lng: resolved.lng };
    }
    throw new AppError('bad_request', 'lat/lng or zip is required');
  }
```

And add this module-level helper below `WIDEN_STEPS`:

```ts
/**
 * [requested, requested*2, requested*4], each clamped to WIDEN_CAP_KM, with
 * duplicates dropped so a request already at the cap yields a single attempt.
 */
function buildRadiusLadder(requestedKm: number): number[] {
  const ladder: number[] = [Math.min(requestedKm, WIDEN_CAP_KM)];
  for (let i = 0; i < WIDEN_STEPS; i += 1) {
    const next = Math.min((ladder[ladder.length - 1] as number) * 2, WIDEN_CAP_KM);
    if (next > (ladder[ladder.length - 1] as number)) ladder.push(next);
  }
  return ladder;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/gym.facade.test.mts`
Expected: all pass, including the 9 new cases.

- [ ] **Step 5: Type-check**

Run: `cd apps/api && bunx tsc --noEmit 2>&1 | grep -cE "^src/"`
Expected: `0`. If the route still calls `gymFacade.nearby`, that error is expected here and fixed in Task 4 — note it and continue.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/gym.facade.mts apps/api/test/gym.facade.test.mts
git commit -m "feat(api): add gym search facade with zip origin and radius widening"
```

---

## Task 4: Route — wire the query and meta

**Files:**
- Modify: `apps/api/src/routes/gym.routes.mts` (the `/nearby` handler)
- Test: `apps/api/test/gym-nearby-route.test.mts` (create)

**Interfaces:**
- Consumes: `GymFacade.searchNearby` (Task 3), `NearbyQuery` (Task 1), `list()` from `http/envelope.mts`.
- Produces: `GET /api/v1/gyms/nearby` returning `{ data: Gym[], meta: { page, limit, total, effectiveRadiusKm } }`.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/gym-nearby-route.test.mts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { MongoClient } from 'mongodb';
import { loadEnv } from '../src/config/env.mts';
import { createContainer } from '../src/container.mts';
import { buildApp } from '../src/app.mts';

const TEST_DB = 'bjj_test_gym_nearby_route';
const uri = process.env['MONGODB_URI'] ?? 'mongodb://localhost:27017';
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: 'secret-nearby',
  DEMO_USER_ID: 'demo-nearby-user',
  DEMO_USER_ROLE: 'practitioner',
  DEMO_USER_EMAIL: 'demo-nearby@d.dev',
});
let app: ReturnType<typeof buildApp>;
let base: string;

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.collection('gyms').createIndex({ geo: '2dsphere' });
  await db.collection('gyms').insertOne({
    _id: 'g-near' as never,
    name: 'Van Alstyne BJJ',
    address: '1 Main St',
    city: 'Van Alstyne',
    amenities: [],
    isVerified: true,
    geo: { type: 'Point', coordinates: [-96.5486, 33.4292] },
  } as never);
  app = buildApp(createContainer(db, env)).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe('GET /api/v1/gyms/nearby', () => {
  it('returns paging meta including effectiveRadiusKm', async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?lat=33.4292&lng=-96.5486&radiusKm=40`);
    expect(res.status).toBe(200);
    const body = await res.json() as { data: unknown[]; meta: Record<string, number> };
    expect(body.data).toHaveLength(1);
    expect(body.meta.page).toBe(1);
    expect(body.meta.limit).toBe(20);
    expect(body.meta.total).toBe(1);
    expect(body.meta.effectiveRadiusKm).toBe(40);
  });

  it('400s when neither coordinates nor zip are supplied', async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?radiusKm=40`);
    expect(res.status).toBe(400);
  });

  it('400s on an unresolvable zip', async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=00000&radiusKm=40`);
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd apps/api && bun test test/gym-nearby-route.test.mts`
Expected: FAIL — `gymFacade.nearby is not a function` (or a compile error on the handler).

- [ ] **Step 3: Rewrite the handler**

In `apps/api/src/routes/gym.routes.mts`, replace the `/nearby` route:

```ts
    .get(
      '/nearby',
      async ({ query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const result = await gymFacade.searchNearby({
          lat: query.lat,
          lng: query.lng,
          zip: query.zip,
          q: query.q,
          radiusKm: query.radiusKm ?? 25,
          page,
          limit,
        });
        return list(result.items, {
          page,
          limit,
          total: result.total,
          effectiveRadiusKm: result.effectiveRadiusKm,
        });
      },
      { query: NearbyQuery },
    )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/api && bun test test/gym-nearby-route.test.mts`
Expected: 3 pass.

- [ ] **Step 5: Type-check and run the broader suite**

Run: `cd apps/api && bunx tsc --noEmit 2>&1 | grep -cE "^src/"`
Expected: `0`.

Run: `cd apps/api && bun test`
Expected: only the 5 known `device.routes.test.mts` timeouts fail. Any other failure is a regression from this task — fix it before committing.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/routes/gym.routes.mts apps/api/test/gym-nearby-route.test.mts
git commit -m "feat(api): wire gym search query and effectiveRadiusKm into /gyms/nearby"
```

---

## Task 5: E2E test + CI gate

**Files:**
- Create: `apps/api/test/gym-search.e2e.test.mts`
- Create: `.github/workflows/ci.yml`
- Modify: `.github/workflows/api-deploy.yml`

**Interfaces:**
- Consumes: the running app from Task 4.
- Produces: a CI job named `e2e` that `api-deploy.yml` depends on.

- [ ] **Step 1: Write the E2E test**

Create `apps/api/test/gym-search.e2e.test.mts`:

```ts
/**
 * End-to-end gate for gym search. Boots the real app against a real MongoDB and
 * drives it over HTTP — no stubs — because the behaviour under test spans ZIP
 * geocoding, the geo pipeline, and the widening policy, and a stub at any of
 * those seams would prove nothing.
 *
 * The required scenario: search ZIP 75495 (Van Alstyne, TX) at 25 miles, find
 * nothing, and auto-expand to 50 miles.
 */
import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { MongoClient } from 'mongodb';
import { loadEnv } from '../src/config/env.mts';
import { createContainer } from '../src/container.mts';
import { buildApp } from '../src/app.mts';

const TEST_DB = 'bjj_test_gym_search_e2e';
const uri = process.env['MONGODB_URI'] ?? 'mongodb://localhost:27017';
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: 'secret-gym-search-e2e',
  DEMO_USER_ID: 'demo-gym-search-user',
  DEMO_USER_ROLE: 'practitioner',
  DEMO_USER_EMAIL: 'demo-gym-search@d.dev',
});

// 75495 → Van Alstyne, TX. Same fix the mobile e2e mocks.
const RADIUS_25_MI_KM = 40;

let app: ReturnType<typeof buildApp>;
let base: string;

interface SearchBody {
  data: { id: string; name: string; distanceKm: number; joinCode?: string; ownerId?: string }[];
  meta: { page: number; limit: number; total: number; effectiveRadiusKm: number };
}

beforeAll(async () => {
  await client.connect();
  const db = client.db(TEST_DB);
  await db.dropDatabase();
  await db.collection('gyms').createIndex({ geo: '2dsphere' });
  await db.collection('gyms').insertMany([
    {
      // Plano, TX — ~62 km from Van Alstyne. Outside 25 mi, inside 50 mi.
      _id: 'g-plano' as never,
      name: 'Plano Jiu-Jitsu',
      address: '1000 Legacy Dr',
      city: 'Plano',
      amenities: ['showers'],
      isVerified: true,
      joinCode: 'PLANO-SECRET',
      ownerId: 'owner-plano',
      geo: { type: 'Point', coordinates: [-96.6989, 33.0198] },
    },
    {
      // Austin, TX — ~330 km away. Outside every rung of the ladder.
      _id: 'g-austin' as never,
      name: 'Austin BJJ',
      address: '1 Congress Ave',
      city: 'Austin',
      amenities: [],
      isVerified: false,
      geo: { type: 'Point', coordinates: [-97.7431, 30.2672] },
    },
  ] as never);
  app = buildApp(createContainer(db, env)).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe('gym search E2E — ZIP 75495', () => {
  it('expands from 25 to 50 miles to find the nearest gym', async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=75495&radiusKm=${RADIUS_25_MI_KM}`);
    expect(res.status).toBe(200);

    const body = await res.json() as SearchBody;

    // The search widened: 40 km found nothing, 80 km did.
    expect(body.meta.effectiveRadiusKm).toBe(80);

    const ids = body.data.map((g) => g.id);
    expect(ids).toContain('g-plano');
    expect(ids).not.toContain('g-austin');

    const plano = body.data.find((g) => g.id === 'g-plano');
    expect(plano?.distanceKm).toBeGreaterThan(RADIUS_25_MI_KM);
    expect(plano?.distanceKm).toBeLessThan(80);

    // The public search projection must never leak the roster-join secret.
    expect(plano?.joinCode).toBeUndefined();
    expect(plano?.ownerId).toBeUndefined();
  });

  it('exhausts the ladder and returns empty when nothing is in range', async () => {
    const res = await fetch(`${base}/api/v1/gyms/nearby?zip=75495&radiusKm=${RADIUS_25_MI_KM}&q=nonexistent-gym`);
    expect(res.status).toBe(200);

    const body = await res.json() as SearchBody;
    expect(body.data).toHaveLength(0);
    expect(body.meta.total).toBe(0);
    expect(body.meta.effectiveRadiusKm).toBe(160);
  });
});
```

- [ ] **Step 2: Run it against a local mongod**

Run: `cd apps/api && bun test test/gym-search.e2e.test.mts`
Expected: 2 pass. If `distanceKm` for Plano lands outside the 40–80 km window, verify the seeded coordinates rather than loosening the assertion — the window is the point of the test.

- [ ] **Step 3: Add the CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest

    # The gym-search E2E drives the real app against a real MongoDB. A memory
    # server would not exercise the 2dsphere index the search depends on.
    services:
      mongo:
        image: mongo:7
        ports:
          - 27017:27017
        options: >-
          --health-cmd "mongosh --quiet --eval 'db.runCommand({ping:1})'"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 10

    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install --frozen-lockfile

      # Scoped deliberately to the gym-search E2E. The full suite has 5
      # pre-existing failures in device.routes.test.mts (5s timeouts, unrelated
      # to this feature) that would red every build. Widening this to `bun test`
      # is a one-line change once those are fixed.
      - name: Gym search E2E
        working-directory: apps/api
        env:
          # test/setup.mts (preloaded via bunfig.toml) OVERWRITES MONGODB_URI
          # with TEST_MONGODB_URI to keep tests off any ambient cluster. Setting
          # MONGODB_URI here would be inert — this is the variable that lands.
          TEST_MONGODB_URI: mongodb://localhost:27017
        run: bun test test/gym-search.e2e.test.mts
```

Also change `ci.yml`'s trigger to pull requests only — the push-to-main path is covered by the copy in `api-deploy.yml` added in Step 4:

```yaml
on:
  pull_request:
```

- [ ] **Step 4: Make the deploy depend on the gate**

GitHub Actions has no cross-workflow `needs` — a `deploy` job cannot depend on a job defined in `ci.yml`. So the gate is duplicated into the deploy workflow.

In `.github/workflows/api-deploy.yml`, add an `e2e` job **identical** to the one in Step 3 (same `services:` block, same steps, same `TEST_MONGODB_URI`) above the existing `deploy` job, and make `deploy` depend on it:

```yaml
jobs:
  # Duplicated from .github/workflows/ci.yml — GitHub Actions has no
  # cross-workflow `needs`, so the gate must live in this file to block the
  # deploy. Keep the two copies in sync.
  e2e:
    runs-on: ubuntu-latest
    services:
      # ... identical to ci.yml ...
    steps:
      # ... identical to ci.yml ...

  deploy:
    needs: [e2e]
    runs-on: ubuntu-latest
    steps:
      # ... existing deploy steps, unchanged ...
```

Add the matching comment in `ci.yml` pointing back at this file.

This duplicates ~25 lines of YAML. That is the accepted cost: the alternatives (a reusable workflow via `workflow_call`, or `workflow_run` chaining) add indirection disproportionate to one job.

- [ ] **Step 5: Validate the workflow YAML parses**

Run: `bunx js-yaml .github/workflows/ci.yml > /dev/null && bunx js-yaml .github/workflows/api-deploy.yml > /dev/null`
Expected: no output, exit 0. (If `js-yaml` is unavailable, any YAML linter is fine — the point is catching an indentation error before pushing.)

- [ ] **Step 6: Commit**

```bash
git add apps/api/test/gym-search.e2e.test.mts .github/workflows/ci.yml .github/workflows/api-deploy.yml
git commit -m "test(api): add gym search E2E and gate deploys on it"
```

---

## Task 6: Mobile — query, page model, repository

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/gym_search_query.dart`
- Create: `apps/mobile/lib/features/gyms/models/gym_search_page.dart`
- Create: `apps/mobile/lib/features/gyms/data/gym_search_repository.dart`
- Modify: `apps/mobile/lib/features/gyms/models/gym.dart`
- Test: `apps/mobile/test/gyms/gym_search_query_test.dart`, `apps/mobile/test/gyms/gym_search_page_test.dart`

**Interfaces:**
- Consumes: `Gym.fromJson`, `unwrapList` (`core/data/api_envelope.dart`), `apiClientProvider`, `Endpoints.gymsNearby`.
- Produces:
  ```dart
  class GymSearchQuery { final String? q, zip; final double? lat, lng; final double radiusKm; final int page, limit;
    Map<String, dynamic> toQueryParameters(); GymSearchQuery copyWith({...}); }
  class GymSearchPage { final List<Gym> items; final int total; final double effectiveRadiusKm; }
  abstract class GymSearchRepository { Future<GymSearchPage> search(GymSearchQuery query); }
  final gymSearchRepositoryProvider = Provider<GymSearchRepository>(...);
  ```

- [ ] **Step 1: Write the failing tests**

Create `apps/mobile/test/gyms/gym_search_query_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_query.dart';

void main() {
  test('sends coordinates and omits zip when both are present', () {
    const q = GymSearchQuery(lat: 33.4292, lng: -96.5486, zip: '75495', radiusKm: 40);
    final params = q.toQueryParameters();
    expect(params['lat'], 33.4292);
    expect(params['lng'], -96.5486);
    expect(params.containsKey('zip'), isFalse);
  });

  test('sends zip when no coordinates are available', () {
    const q = GymSearchQuery(zip: '75495', radiusKm: 40);
    final params = q.toQueryParameters();
    expect(params['zip'], '75495');
    expect(params.containsKey('lat'), isFalse);
  });

  test('omits blank text', () {
    const q = GymSearchQuery(lat: 1, lng: 2, q: '   ', radiusKm: 40);
    expect(q.toQueryParameters().containsKey('q'), isFalse);
  });

  test('trims text that is sent', () {
    const q = GymSearchQuery(lat: 1, lng: 2, q: '  atos ', radiusKm: 40);
    expect(q.toQueryParameters()['q'], 'atos');
  });

  test('always sends page and limit', () {
    const q = GymSearchQuery(lat: 1, lng: 2, radiusKm: 40, page: 3, limit: 20);
    final params = q.toQueryParameters();
    expect(params['page'], 3);
    expect(params['limit'], 20);
  });
}
```

Create `apps/mobile/test/gyms/gym_search_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/models/gym_search_page.dart';

void main() {
  test('parses items, total and effectiveRadiusKm', () {
    final page = GymSearchPage.fromEnvelope(<String, dynamic>{
      'data': [
        {'id': 'g-1', 'name': 'Atos', 'address': 'A', 'distanceKm': 3.2, 'rankBoost': 5, 'sponsored': true},
      ],
      'meta': {'page': 1, 'limit': 20, 'total': 7, 'effectiveRadiusKm': 80.0},
    });
    expect(page.items.single.id, 'g-1');
    expect(page.items.single.sponsored, isTrue);
    expect(page.total, 7);
    expect(page.effectiveRadiusKm, 80.0);
  });

  test('falls back to the requested radius when meta omits effectiveRadiusKm', () {
    final page = GymSearchPage.fromEnvelope(<String, dynamic>{
      'data': <dynamic>[],
      'meta': {'page': 1, 'limit': 20, 'total': 0},
    }, requestedRadiusKm: 40);
    expect(page.effectiveRadiusKm, 40);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd apps/mobile && flutter test test/gyms/gym_search_query_test.dart test/gyms/gym_search_page_test.dart`
Expected: FAIL — target URI doesn't exist.

- [ ] **Step 3: Implement the query object**

Create `apps/mobile/lib/features/gyms/data/gym_search_query.dart`:

```dart
/// An immutable gym-search request. Coordinates and ZIP are mutually exclusive
/// on the wire: when GPS coordinates are available they win, and the ZIP is
/// dropped rather than sent alongside — the API would ignore it anyway, and
/// sending both invites confusion about which origin produced the results.
class GymSearchQuery {
  final String? q;
  final double? lat;
  final double? lng;
  final String? zip;
  final double radiusKm;
  final int page;
  final int limit;

  const GymSearchQuery({
    this.q,
    this.lat,
    this.lng,
    this.zip,
    required this.radiusKm,
    this.page = 1,
    this.limit = 20,
  });

  bool get hasCoords => lat != null && lng != null;
  bool get hasOrigin => hasCoords || (zip != null && zip!.trim().length == 5);

  Map<String, dynamic> toQueryParameters() {
    final text = q?.trim() ?? '';
    return <String, dynamic>{
      if (hasCoords) 'lat': lat,
      if (hasCoords) 'lng': lng,
      if (!hasCoords && zip != null && zip!.trim().isNotEmpty) 'zip': zip!.trim(),
      if (text.isNotEmpty) 'q': text,
      'radiusKm': radiusKm,
      'page': page,
      'limit': limit,
    };
  }

  GymSearchQuery copyWith({
    String? q,
    double? lat,
    double? lng,
    String? zip,
    double? radiusKm,
    int? page,
    int? limit,
    bool clearGeo = false,
  }) =>
      GymSearchQuery(
        q: q ?? this.q,
        lat: clearGeo ? null : (lat ?? this.lat),
        lng: clearGeo ? null : (lng ?? this.lng),
        zip: clearGeo ? null : (zip ?? this.zip),
        radiusKm: radiusKm ?? this.radiusKm,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GymSearchQuery &&
          q == other.q &&
          lat == other.lat &&
          lng == other.lng &&
          zip == other.zip &&
          radiusKm == other.radiusKm &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(q, lat, lng, zip, radiusKm, page, limit);
}
```

- [ ] **Step 4: Implement the page model**

Create `apps/mobile/lib/features/gyms/models/gym_search_page.dart`:

```dart
import 'gym.dart';

/// One page of gym search results.
///
/// [effectiveRadiusKm] is the radius that actually produced these results. The
/// API widens the search when the first page would be empty, so this can exceed
/// what the user asked for — the UI must surface that rather than let the
/// radius control misreport.
class GymSearchPage {
  final List<Gym> items;
  final int total;
  final double effectiveRadiusKm;

  const GymSearchPage({
    required this.items,
    required this.total,
    required this.effectiveRadiusKm,
  });

  static const GymSearchPage empty =
      GymSearchPage(items: <Gym>[], total: 0, effectiveRadiusKm: 0);

  factory GymSearchPage.fromEnvelope(
    Map<String, dynamic> body, {
    double requestedRadiusKm = 0,
  }) {
    final raw = body['data'];
    final list = raw is List ? raw : const <dynamic>[];
    final items = list
        .cast<Map<String, dynamic>>()
        .map(Gym.fromJson)
        .toList(growable: false);

    final meta = body['meta'];
    final metaMap = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};

    return GymSearchPage(
      items: items,
      total: (metaMap['total'] as num?)?.toInt() ?? items.length,
      effectiveRadiusKm:
          (metaMap['effectiveRadiusKm'] as num?)?.toDouble() ?? requestedRadiusKm,
    );
  }
}
```

- [ ] **Step 5: Parse the ranking fields on `Gym`**

In `apps/mobile/lib/features/gyms/models/gym.dart`, add two fields to the class, the constructor, and `fromJson`:

Fields (after `distanceKm`):

```dart
  final int rankBoost;
  final bool sponsored;
```

Constructor params (after `this.distanceKm`):

```dart
    this.rankBoost = 0,
    this.sponsored = false,
```

In `fromJson`, before `createdAt`:

```dart
      rankBoost: (json['rankBoost'] as num?)?.toInt() ?? 0,
      sponsored: json['sponsored'] as bool? ?? false,
```

- [ ] **Step 6: Implement the repository**

Create `apps/mobile/lib/features/gyms/data/gym_search_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym_search_page.dart';
import 'gym_search_query.dart';

abstract class GymSearchRepository {
  Future<GymSearchPage> search(GymSearchQuery query);
}

class ApiGymSearchRepository implements GymSearchRepository {
  final Dio _dio;
  ApiGymSearchRepository(this._dio);

  @override
  Future<GymSearchPage> search(GymSearchQuery query) async {
    try {
      final res = await _dio.get(
        Endpoints.gymsNearby,
        queryParameters: query.toQueryParameters(),
      );
      return GymSearchPage.fromEnvelope(
        res.data as Map<String, dynamic>,
        requestedRadiusKm: query.radiusKm,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymSearchRepositoryProvider = Provider<GymSearchRepository>((ref) {
  return ApiGymSearchRepository(ref.read(apiClientProvider).dio);
});
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd apps/mobile && flutter test test/gyms/gym_search_query_test.dart test/gyms/gym_search_page_test.dart`
Expected: 7 pass.

Run: `cd apps/mobile && flutter analyze lib/features/gyms`
Expected: no new issues. **Do not run `dart format`.**

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/gyms/data/gym_search_query.dart apps/mobile/lib/features/gyms/models/gym_search_page.dart apps/mobile/lib/features/gyms/data/gym_search_repository.dart apps/mobile/lib/features/gyms/models/gym.dart apps/mobile/test/gyms/gym_search_query_test.dart apps/mobile/test/gyms/gym_search_page_test.dart
git commit -m "feat(mobile): add gym search query, page model and repository"
```

---

## Task 7: Mobile — paging controller

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/gym_search_controller.dart`
- Test: `apps/mobile/test/gyms/gym_search_controller_test.dart`

**Interfaces:**
- Consumes: `GymSearchQuery`, `GymSearchPage`, `gymSearchRepositoryProvider` (Task 6).
- Produces:
  ```dart
  class GymSearchState { final List<Gym> items; final int total; final double effectiveRadiusKm;
    final bool loading; final Object? error; bool get hasMore; }
  class GymSearchController extends StateNotifier<GymSearchState> {
    Future<void> submit(GymSearchQuery query);   // resets to page 1
    Future<void> loadMore();                     // appends the next page
  }
  final gymSearchControllerProvider =
      StateNotifierProvider<GymSearchController, GymSearchState>(...);
  ```

**Why a stateful controller:** a `FutureProvider` replaces its value on each fetch and cannot accumulate pages. Every other list in this app is single-shot, which is why this is the first controller of its kind here.

> **CORRECTION (applied during execution).** This task's code below was written
> against `StateNotifier`. That symbol is exported only from
> `package:flutter_riverpod/legacy.dart` in the pinned flutter_riverpod 3.3.1,
> and this app uses the modern `Notifier` API in four places
> (`main.dart:32`, `core/location/location_controller.dart:18`,
> `core/auth/auth_service.dart:29`,
> `features/admin/screens/owner_dashboard_screen.dart:14`) and `StateNotifier`
> in none. **Use `Notifier` / `NotifierProvider`:** state initializes in
> `build()`, the repository comes from `ref.read(gymSearchRepositoryProvider)`
> rather than constructor injection, and the provider is
> `NotifierProvider<GymSearchController, GymSearchState>(GymSearchController.new)`.
> The `submit`/`loadMore` bodies are otherwise unchanged — `state = ...` behaves
> identically. The controller also carries a request-generation counter so a
> stale in-flight response cannot write over a newer query's results.

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/gyms/gym_search_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/gyms/models/gym_search_page.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_query.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_controller.dart';

/// Returns one gym per page, reporting a total of 3, so paging is observable.
class _FakeRepo implements GymSearchRepository {
  final List<GymSearchQuery> calls = <GymSearchQuery>[];
  final double effectiveRadiusKm;
  _FakeRepo({this.effectiveRadiusKm = 40});

  @override
  Future<GymSearchPage> search(GymSearchQuery query) async {
    calls.add(query);
    return GymSearchPage(
      items: [Gym(id: 'g-${query.page}', name: 'Gym ${query.page}', address: 'A')],
      total: 3,
      effectiveRadiusKm: effectiveRadiusKm,
    );
  }
}

ProviderContainer _containerWith(_FakeRepo repo) => ProviderContainer(
      overrides: [gymSearchRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  test('submit loads page 1 and reports hasMore', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);

    await c.read(gymSearchControllerProvider.notifier)
        .submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));

    final s = c.read(gymSearchControllerProvider);
    expect(s.items.map((g) => g.id), ['g-1']);
    expect(s.total, 3);
    expect(s.hasMore, isTrue);
    expect(s.loading, isFalse);
  });

  test('loadMore appends rather than replacing', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();

    expect(c.read(gymSearchControllerProvider).items.map((g) => g.id), ['g-1', 'g-2']);
    expect(repo.calls.map((q) => q.page), [1, 2]);
  });

  test('loadMore pages at the effective radius, not the requested one', () async {
    final repo = _FakeRepo(effectiveRadiusKm: 80);
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();

    expect(repo.calls[1].radiusKm, 80);
  });

  test('submit resets accumulated items', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();
    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, q: 'atos', radiusKm: 40));

    expect(c.read(gymSearchControllerProvider).items.map((g) => g.id), ['g-1']);
  });

  test('loadMore is a no-op once every item is loaded', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();
    await notifier.loadMore();   // now 3 of 3
    await notifier.loadMore();   // must not fire a 4th request

    expect(repo.calls.map((q) => q.page), [1, 2, 3]);
  });

  test('submit with no origin does not call the API', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);

    await c.read(gymSearchControllerProvider.notifier)
        .submit(const GymSearchQuery(radiusKm: 40));

    expect(repo.calls, isEmpty);
    expect(c.read(gymSearchControllerProvider).items, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd apps/mobile && flutter test test/gyms/gym_search_controller_test.dart`
Expected: FAIL — target URI doesn't exist.

- [ ] **Step 3: Implement the controller**

Create `apps/mobile/lib/features/gyms/data/gym_search_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gym.dart';
import 'gym_search_query.dart';
import 'gym_search_repository.dart';

class GymSearchState {
  final List<Gym> items;
  final int total;

  /// The radius that produced [items]. May exceed the requested radius when the
  /// API auto-widened a search that would otherwise have been empty.
  final double effectiveRadiusKm;

  /// The radius the user actually asked for. When this differs from
  /// [effectiveRadiusKm] the UI shows a widened-search notice.
  final double requestedRadiusKm;

  final bool loading;
  final Object? error;

  /// True once a search has been submitted — distinguishes "no results" from
  /// "nothing searched yet", which need different empty states.
  final bool searched;

  const GymSearchState({
    this.items = const <Gym>[],
    this.total = 0,
    this.effectiveRadiusKm = 0,
    this.requestedRadiusKm = 0,
    this.loading = false,
    this.error,
    this.searched = false,
  });

  bool get hasMore => items.length < total;
  bool get widened => searched && effectiveRadiusKm > requestedRadiusKm;

  GymSearchState copyWith({
    List<Gym>? items,
    int? total,
    double? effectiveRadiusKm,
    double? requestedRadiusKm,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? searched,
  }) =>
      GymSearchState(
        items: items ?? this.items,
        total: total ?? this.total,
        effectiveRadiusKm: effectiveRadiusKm ?? this.effectiveRadiusKm,
        requestedRadiusKm: requestedRadiusKm ?? this.requestedRadiusKm,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        searched: searched ?? this.searched,
      );
}

/// Accumulates pages of gym search results.
///
/// A StateNotifier rather than a FutureProvider because paging needs to append
/// to a list that survives across fetches; a FutureProvider replaces its value
/// on every request.
class GymSearchController extends StateNotifier<GymSearchState> {
  final GymSearchRepository _repo;
  GymSearchQuery? _query;

  GymSearchController(this._repo) : super(const GymSearchState());

  /// Run a new search. Resets to page 1 and discards accumulated results.
  Future<void> submit(GymSearchQuery query) async {
    if (!query.hasOrigin) {
      state = const GymSearchState(searched: true);
      return;
    }

    final first = query.copyWith(page: 1);
    _query = first;
    state = state.copyWith(
      items: const <Gym>[],
      total: 0,
      loading: true,
      clearError: true,
      requestedRadiusKm: first.radiusKm,
      effectiveRadiusKm: first.radiusKm,
      searched: true,
    );

    try {
      final page = await _repo.search(first);
      // Page subsequent requests at the radius that produced page 1, so the
      // user scrolls through one stable result set rather than a shifting one.
      _query = first.copyWith(radiusKm: page.effectiveRadiusKm);
      state = state.copyWith(
        items: page.items,
        total: page.total,
        effectiveRadiusKm: page.effectiveRadiusKm,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Append the next page. No-op while loading, when everything is already
  /// loaded, or before the first search.
  Future<void> loadMore() async {
    final current = _query;
    if (current == null || state.loading || !state.hasMore) return;

    final next = current.copyWith(page: current.page + 1);
    state = state.copyWith(loading: true, clearError: true);

    try {
      final page = await _repo.search(next);
      _query = next;
      state = state.copyWith(
        items: <Gym>[...state.items, ...page.items],
        total: page.total,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final gymSearchControllerProvider =
    StateNotifierProvider<GymSearchController, GymSearchState>((ref) {
  return GymSearchController(ref.read(gymSearchRepositoryProvider));
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd apps/mobile && flutter test test/gyms/gym_search_controller_test.dart`
Expected: 6 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/gyms/data/gym_search_controller.dart apps/mobile/test/gyms/gym_search_controller_test.dart
git commit -m "feat(mobile): add paging gym search controller"
```

---

## Task 8: Mobile — search screen mode toggle

**Files:**
- Modify: `apps/mobile/lib/features/search/screens/search_screen.dart`

**Interfaces:**
- Consumes: `gymSearchControllerProvider`, `GymSearchQuery` (Tasks 6–7), existing `NearbyGymCard`, `EmptyState`, `locationControllerProvider`.
- Produces: no new public API — a UI change only.

**Existing state to reuse (do not duplicate):** `_distanceMi`, `_searchCtrl`, `_zipCtrl`, `_gpsLat`, `_gpsLng`, `_debounce`. The gi/free/when chips (`_filters`, `_when`, `_whenLabel`) are open-mat-only and must hide in Gyms mode.

- [ ] **Step 1: Add the mode field and query builder**

In `_SearchScreenState`, add near `_query` (line 44):

```dart
  /// Which entity the screen is searching. The geo inputs (radius, ZIP, GPS)
  /// are shared across modes; only the result list and the filter chips differ.
  bool _gymMode = false;

  /// Build the gym query from the same geo inputs the open-mat query uses.
  /// Coordinates are suppressed when a ZIP is present, matching _rebuildQuery.
  GymSearchQuery _buildGymQuery() {
    final zipText = _zipCtrl.text.trim();
    final useZip = zipText.isNotEmpty;
    return GymSearchQuery(
      q: _searchCtrl.text,
      lat: useZip ? null : _gpsLat,
      lng: useZip ? null : _gpsLng,
      zip: useZip ? zipText : null,
      radiusKm: _distanceMi * 1.60934,
    );
  }

  void _submitGymSearch() {
    ref.read(gymSearchControllerProvider.notifier).submit(_buildGymQuery());
  }
```

Add the imports at the top of the file:

```dart
import '../../../shared/widgets/nearby_gym_card.dart';
import '../../gyms/data/gym_search_controller.dart';
import '../../gyms/data/gym_search_query.dart';
```

- [ ] **Step 2: Route every existing input change to the active mode**

Find `_rebuildQuery()` and, at its start, short-circuit into the gym path so the shared debounce, radius slider, ZIP field, and text field all drive whichever mode is active:

```dart
  void _rebuildQuery() {
    if (_gymMode) {
      _submitGymSearch();
      return;
    }
    // ... existing open-mat body unchanged ...
```

- [ ] **Step 3: Add the segmented toggle**

In `_buildGlass`, immediately above the search text field, insert:

```dart
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<bool>(
                key: const Key('search-mode-toggle'),
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Open Mats')),
                  ButtonSegment<bool>(value: true, label: Text('Gyms')),
                ],
                selected: <bool>{_gymMode},
                showSelectedIcon: false,
                onSelectionChanged: (sel) {
                  setState(() => _gymMode = sel.first);
                  _rebuildQuery();
                },
              ),
            ),
```

- [ ] **Step 4: Hide open-mat-only chips in Gyms mode**

Wrap the filter-chip `SizedBox`/`ListView` (the block using `itemCount: filters.length`, around line 455) in:

```dart
            if (!_gymMode) ...[
              // existing filter chip block
            ],
```

Change the search field's hint to follow the mode:

```dart
              hintText: _gymMode ? 'Search gyms by name or city' : 'Search open mats',
```

- [ ] **Step 5: Branch the results area**

Where the open-mat results are built, wrap the existing widget and add the gym branch:

```dart
            if (_gymMode) _buildGymResults(t) else ...[
              // existing open-mat results, unchanged
            ],
```

Add the builder method to `_SearchScreenState`:

```dart
  Widget _buildGymResults(AppTokens t) {
    final state = ref.watch(gymSearchControllerProvider);

    if (state.loading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return const EmptyState(
        title: "Couldn't load gyms",
        subtitle: 'Check your connection and try again.',
      );
    }

    if (state.searched && state.items.isEmpty) {
      return const EmptyState(
        title: 'No gyms found',
        subtitle: 'Try a different area, widen the radius, or clear the search text.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The API widened the search because nothing was in range. Say so —
        // otherwise the radius control silently misreports what is shown.
        if (state.widened)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No gyms within ${_miles(state.requestedRadiusKm)} mi — '
              'showing results within ${_miles(state.effectiveRadiusKm)} mi.',
              key: const Key('gym-search-widened-notice'),
              style: t.miniStyle.copyWith(color: t.muted),
            ),
          ),
        ...state.items.map(
          (gym) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NearbyGymCard(gym: gym),
          ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: state.loading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      key: const Key('gym-search-load-more'),
                      onPressed: () => ref.read(gymSearchControllerProvider.notifier).loadMore(),
                      child: const Text('Load more'),
                    ),
            ),
          ),
      ],
    );
  }

  static String _miles(double km) => (km / 1.60934).round().toString();
```

**Note on "infinite scroll":** the spec calls for appending on scroll. This uses an explicit *Load more* control instead — the screen's results already sit inside an outer scroll view, and nesting a scroll listener inside it is a well-known source of double-scroll bugs. A visible control is honest about the boundary and testable. If you'd rather have true scroll-triggered paging, attach a `ScrollController` to the screen's existing outer scrollable and call `loadMore()` past a 0.8 extent threshold — but do not add a second scrollable to do it.

- [ ] **Step 6: Analyze and run the mobile unit suite**

Run: `cd apps/mobile && flutter analyze lib/features/search lib/features/gyms`
Expected: no new issues.

Run: `cd apps/mobile && flutter test`
Expected: no new failures vs. the pre-task baseline. **Do not run `dart format`.**

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/search/screens/search_screen.dart
git commit -m "feat(mobile): add Open Mats/Gyms toggle to search screen"
```

---

## Task 9: Mobile — gym detail contact block and amenities

**Files:**
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart`

**Interfaces:**
- Consumes: `Gym` fields `address`, `phone`, `website`, `amenities`; existing `directions.dart` and `website_links.dart` helpers.
- Produces: no new public API.

**Context:** the screen renders `About` around line 344 and has a `_Pill` helper at line 380. `phone`, `website`, and `amenities` currently arrive from the API and are never rendered.

- [ ] **Step 1: Add a detail-row helper**

Add to the file, next to `_Pill`:

```dart
/// A tappable icon + label row used by the contact block. Rendered only when
/// its underlying field is present, so the block collapses on sparse gyms
/// rather than showing empty scaffolding.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final AppTokens t;

  const _DetailRow({required this.icon, required this.label, required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: t.bodyStyle.copyWith(color: onTap == null ? t.text : t.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Render the contact block**

Immediately above the `About` heading (line 344), insert:

```dart
              _DetailRow(
                key: const Key('gym-detail-address'),
                icon: LucideIcons.mapPin,
                label: gym.address,
                t: t,
                onTap: () => openDirections(ref, context, gymId: gym.id, address: gym.address),
              ),
              if ((gym.phone ?? '').trim().isNotEmpty)
                _DetailRow(
                  key: const Key('gym-detail-phone'),
                  icon: LucideIcons.phone,
                  label: gym.phone!.trim(),
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('tel:${gym.phone!.trim()}'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              if ((gym.website ?? '').trim().isNotEmpty)
                _DetailRow(
                  key: const Key('gym-detail-website'),
                  icon: LucideIcons.globe,
                  // Display the compact host, not the raw URL — a long path
                  // would overflow the row.
                  label: websiteDisplayHost(gym.website!.trim()),
                  t: t,
                  onTap: () => openWebsite(context, gym.website!.trim()),
                ),
              const SizedBox(height: 8),
```

Signatures verified against the helpers:

- `openDirections(WidgetRef ref, BuildContext context, {String? gymId, String? address})` — `directions.dart:22`. Passing both `gymId` and `address` gets the API lookup with an address fallback.
- `openWebsite(BuildContext context, String rawUrl)` and `websiteDisplayHost(String raw)` — `website_links.dart:22` and `:8`. `openWebsite` normalizes a missing scheme itself.

Add `import 'package:url_launcher/url_launcher.dart';` for the `tel:` launch if the file does not already import it — there is no existing phone helper.

- [ ] **Step 3: Render amenities**

Below the About description block (after line 354), insert:

```dart
              if (gym.amenities.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Amenities', style: t.h2Style),
                const SizedBox(height: 10),
                Wrap(
                  key: const Key('gym-detail-amenities'),
                  spacing: 8,
                  runSpacing: 8,
                  children: gym.amenities
                      .map((a) => _Pill(label: a, color: t.primary, t: t))
                      .toList(),
                ),
              ],
```

- [ ] **Step 4: Verify against a real gym**

Run: `cd apps/mobile && flutter analyze lib/features/gyms`
Expected: no new issues.

Launch the app against a local API and open a gym that has a phone, website, and amenities. Confirm each row renders, each tap works, and a gym with none of them shows no empty scaffolding.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart
git commit -m "feat(mobile): show address, phone, website and amenities on gym detail"
```

---

## Task 10: Flutter integration test (local only)

**Files:**
- Create: `apps/mobile/integration_test/gym_search_test.dart`
- Create: `scripts/e2e-gym-search.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: the search screen from Task 8 and its widget keys (`search-mode-toggle`, `search-zip`, `gym-search-widened-notice`).
- Produces: `bun run mobile:e2e:gyms`.

**Not wired into CI** — the existing mobile e2e scripts need an Android emulator via `adb`, which is slow and flaky on hosted runners. Run before a release, like the other `mobile:e2e:*` scripts.

- [ ] **Step 1: Read the existing pattern**

Open `apps/mobile/integration_test/search_filter_test.dart`. Copy its bootstrap and helpers verbatim — `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, `pumpUntilFound(tester, finder, {timeout})`, `tapText(tester, text)`, `fieldByHint(hint)`, and how it pumps `app.main()`. Do not invent a new harness.

**Scope note — do not assert widening here.** `search_filter_test.dart` creates a gym named `North Texas BJJ` *at* ZIP 75495, so in any environment where that test has run there IS a gym within 25 miles and the search will not widen. Widening is already proven deterministically by the Task 5 API E2E against seeded data. This test's job is the UI wiring: the toggle switches modes, a ZIP drives a gym query, and gym cards render.

- [ ] **Step 2: Write the integration test**

Create `apps/mobile/integration_test/gym_search_test.dart` using that bootstrap, with this body:

```dart
  testWidgets('gyms mode searches by ZIP and renders gym cards', (tester) async {
    // <bootstrap: app.main() + pumpUntilFound, copied from search_filter_test.dart>

    // Navigate to the Find tab, then switch to Gyms mode.
    await tapText(tester, 'Find');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-mode-toggle')).last);
    await tester.pumpAndSettle();

    // Open-mat-only chips must disappear in Gyms mode.
    expect(find.text('Gi'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    final found = await pumpUntilFound(
      tester,
      find.byType(NearbyGymCard),
      timeout: const Duration(seconds: 20),
    );
    expect(found, isTrue, reason: 'expected at least one gym near ZIP 75495');
  });
```

Add `import 'package:bjj_open_mat/shared/widgets/nearby_gym_card.dart';`.

This runs against whatever `API_BASE_URL` the driver script passes. It requires at least one gym within 50 miles of Van Alstyne in that environment — true for the seeded local environment the other `mobile:e2e:*` scripts assume. If you point it at an empty database it will fail, and that failure is correct rather than flaky.

- [ ] **Step 3: Write the driver script**

Create `scripts/e2e-gym-search.mjs` by copying `scripts/e2e-search.mjs` verbatim and changing only the target:

```js
  '--target=integration_test/gym_search_test.dart',
```

The GPS fix in that script is already Van Alstyne (`-96.5486 33.4292`), which is the right origin for this test — leave it.

- [ ] **Step 4: Wire the npm script**

In the root `package.json`, after `mobile:e2e:discover`:

```json
    "mobile:e2e:gyms": "cd apps/mobile && node ../../scripts/e2e-gym-search.mjs",
```

- [ ] **Step 5: Run it**

Run: `bun run mobile:e2e:gyms` (requires a booted `emulator-5554` and a reachable API).
Expected: the test passes and a recording lands in `build/e2e/e2e.mp4`.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/integration_test/gym_search_test.dart scripts/e2e-gym-search.mjs package.json
git commit -m "test(mobile): add local gym search integration test"
```

---

## Final verification

- [ ] `cd apps/api && bunx tsc --noEmit 2>&1 | grep -cE "^src/"` prints `0`
- [ ] `cd apps/api && bun test` — only the 5 known `device.routes.test.mts` timeouts fail
- [ ] `cd apps/api && bunx eslint src/repositories/gym.repository.mts src/facades/gym.facade.mts src/routes/gym.routes.mts` is clean (lint only changed files)
- [ ] `cd packages/contract && bunx tsc --noEmit` is clean
- [ ] `cd apps/mobile && flutter analyze lib/features/gyms lib/features/search` shows no new issues
- [ ] `cd apps/mobile && flutter test` shows no new failures
- [ ] `bun run mobile:e2e:gyms` passes on an emulator
- [ ] Open a PR and confirm the `e2e` job runs and is required before deploy
