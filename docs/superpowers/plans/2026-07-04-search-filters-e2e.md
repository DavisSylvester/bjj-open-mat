# Search & Filters (When / Within / GPS / Zip) + E2E — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Worktree note:** Implementer subagents MUST work directly in the main checkout. Do NOT run `git worktree`, create a branch, or commit from a subagent unless told — a prior session had a subagent silently create a worktree off the last commit and lose all uncommitted work.

**Goal:** Wire open-mat search end-to-end so a newly-created gym is discoverable and filterable by text, gi-type, fee, date ("When"), and distance ("Within") from GPS or a zip code — replacing the SearchScreen/Discover stub data — with an e2e test that drives the real UI and captures screenshots + video.

**Architecture:** Extend `OpenMatListQuery` and the `GET /open-mats` list path (facade + repository) with text/free/date-range/geo filters; add an injectable `zipcodes`-backed geocoder used both to give new gyms coordinates and to resolve a zip to a point. On mobile, add a search repository + provider and rewire SearchScreen and Discover to call it. The e2e uses the Flutter integration driver for screenshots and `adb screenrecord` for video.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (`$geoNear`) + `zipcodes` npm pkg (API); Flutter + Riverpod + go_router + Dio + geolocator (mobile); `integration_test` + `flutter drive` + adb (e2e). Spec: `docs/superpowers/specs/2026-07-04-search-filters-e2e-design.md`.

**Git note:** Per project policy, commits are authored by the user. Treat each "Commit" step as a checkpoint; run it only if the executing context is authorized, otherwise leave changes staged.

---

## File Structure

**Contract (`packages/contract/src`)**
- `schemas/requests/open-mat-requests.mts` — add fields to `OpenMatListQuery`; add coords to `NewGymInput`.
- `schemas/requests/gym-requests.mts` — `CreateGymRequest` already has `location`/`postalCode` (no change needed).

**API (`apps/api/src`)**
- `services/geocoder.mts` (new) — `Geocoder` interface + `ZipcodesGeocoder`.
- `services/i-geocoder.mts` — folded into geocoder.mts (single small file; project has no strict one-interface rule for services here — follow existing `facades/` style which co-locates).
- `container.mts` — construct geocoder, inject into `GymFacade` + `OpenMatFacade`.
- `facades/gym.facade.mts` — geocode `postalCode` on create when no `location`.
- `facades/open-mat.facade.mts` — geocode `newGym.postalCode` on create; resolve `zip`→point in `list`.
- `repositories/open-mat.repository.mts` — extend `OpenMatFilter`; text/free/date/geo query building.
- `routes/open-mat.routes.mts` — map new query params into the filter.
- `openapi.mts` — no new schema refs required (fields live inside existing `OpenMatListQuery`).
- `package.json` — add `zipcodes` dependency.

**Mobile (`apps/mobile/lib`)**
- `features/search/data/search_query.dart` (new) — `SearchQuery` value object.
- `features/search/data/search_repository.dart` (new) — `search(SearchQuery)` + provider.
- `features/search/data/when_range.dart` (new) — date-range presets (`this week/weekend/month`, pick-a-date).
- `features/search/screens/search_screen.dart` — rewrite to call the API.
- `features/discover/providers/discover_provider.dart` — pass query, stop ignoring it.
- `features/discover/screens/discover_screen.dart` — render live data.
- `features/open_mats/data/session_requests.dart` — add `postalCode`/`country` to `NewGymInput`.

**Mobile tests**
- `apps/mobile/test/features/when_range_test.dart` (new)
- `apps/mobile/test/data/search_repository_test.dart` (new)
- `apps/mobile/test/features/search_screen_test.dart` (new)
- `apps/mobile/test_driver/integration_test.dart` (new)
- `apps/mobile/integration_test/search_filter_test.dart` (new)

**Root**
- `package.json` — `mobile:e2e:search` script.

---

## Phase A — Contract

### Task 1: Extend OpenMatListQuery + NewGymInput

**Files:**
- Modify: `packages/contract/src/schemas/requests/open-mat-requests.mts`
- Test: `apps/api/test/contract-search-query.test.mts` (new)

- [ ] **Step 1: Write the failing test** at `apps/api/test/contract-search-query.test.mts`

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { OpenMatListQuery, NewGymInput } from "@bjj/contract";

describe("contract: search query", () => {
  it("OpenMatListQuery accepts the new search/filter fields", () => {
    const ok = Value.Check(OpenMatListQuery, {
      q: "atos", free: true, startDate: "2026-07-04", endDate: "2026-07-05",
      lat: 33.1, lng: -96.6, radiusKm: 25, zip: "75495",
    });
    expect(ok).toBe(true);
  });

  it("radiusKm is bounded 1..500", () => {
    expect(Value.Check(OpenMatListQuery, { radiusKm: 0 })).toBe(false);
    expect(Value.Check(OpenMatListQuery, { radiusKm: 600 })).toBe(false);
  });

  it("NewGymInput accepts optional coordinates", () => {
    expect(Value.Check(NewGymInput, { name: "G", address: "1 A St", latitude: 33.1, longitude: -96.6, postalCode: "75495" })).toBe(true);
  });
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/contract-search-query.test.mts` — expect FAIL (fields missing).

- [ ] **Step 3: Edit `open-mat-requests.mts`.** Add coords to `NewGymInput` (after `country`):

```typescript
export const NewGymInput = t.Object(
  {
    name: t.String({ minLength: 1 }),
    address: t.String({ minLength: 1 }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    country: t.Optional(t.String()),
    latitude: t.Optional(t.Number()),
    longitude: t.Optional(t.Number()),
  },
  { $id: "NewGymInput" },
);
```

Add filter fields to `OpenMatListQuery` (after `submittedByMe`):

```typescript
    submittedByMe: t.Optional(t.Boolean({ description: "sessions the caller submitted (hostId)" })),
    q: t.Optional(t.String({ description: "free-text: title + gymName" })),
    free: t.Optional(t.Boolean({ description: "feeCents 0 or absent" })),
    startDate: t.Optional(t.String({ description: "ISO date; When range start" })),
    endDate: t.Optional(t.String({ description: "ISO date; When range end" })),
    lat: t.Optional(t.Number()),
    lng: t.Optional(t.Number()),
    radiusKm: t.Optional(t.Number({ minimum: 1, maximum: 500 })),
    zip: t.Optional(t.String({ description: "geocoded to a point server-side" })),
```

- [ ] **Step 4: Run + type-check** — `cd apps/api && bun test test/contract-search-query.test.mts` (PASS), then `cd packages/contract && bunx tsc --noEmit` (clean).

- [ ] **Step 5: Commit**

```bash
git add packages/contract apps/api/test/contract-search-query.test.mts
git commit -m "feat(contract): OpenMatListQuery search/filter fields + NewGymInput coords"
```

---

## Phase B — API geocoder + gym coordinates

### Task 2: Zipcodes geocoder service

**Files:**
- Create: `apps/api/src/services/geocoder.mts`
- Modify: `apps/api/package.json` (add `zipcodes`)
- Test: `apps/api/test/geocoder.test.mts` (new)

- [ ] **Step 1: Add the dependency** — `cd apps/api && bun add zipcodes`. (Confirm `zipcodes` appears in `apps/api/package.json` dependencies.)

- [ ] **Step 2: Write the failing test** at `apps/api/test/geocoder.test.mts`

```typescript
import { describe, expect, it } from "bun:test";
import { ZipcodesGeocoder } from "../src/services/geocoder.mts";

describe("ZipcodesGeocoder", () => {
  const geo = new ZipcodesGeocoder();

  it("resolves a known US zip to coordinates", () => {
    const p = geo.lookupZip("75495");
    expect(p).not.toBeNull();
    expect(p!.lat).toBeGreaterThan(32);
    expect(p!.lat).toBeLessThan(34);
    expect(p!.lng).toBeLessThan(-95);
    expect(p!.lng).toBeGreaterThan(-98);
  });

  it("returns null for an unknown zip", () => {
    expect(geo.lookupZip("00000")).toBeNull();
    expect(geo.lookupZip("nonsense")).toBeNull();
  });
});
```

- [ ] **Step 3: Run it** — `cd apps/api && bun test test/geocoder.test.mts` — expect FAIL (module missing).

- [ ] **Step 4: Create `apps/api/src/services/geocoder.mts`**

```typescript
import zipcodes from "zipcodes";

export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface Geocoder {
  lookupZip(zip: string): GeoPoint | null;
}

export class ZipcodesGeocoder implements Geocoder {

  public lookupZip(zip: string): GeoPoint | null {
    const trimmed = zip.trim();
    if (!/^\d{5}$/.test(trimmed)) return null;
    const rec = zipcodes.lookup(trimmed);
    if (!rec || typeof rec.latitude !== "number" || typeof rec.longitude !== "number") return null;
    return { lat: rec.latitude, lng: rec.longitude };
  }
}
```

(If `zipcodes` has no bundled types, add `// @ts-expect-error no types` above the import, or declare `declare module "zipcodes";` in a `apps/api/src/types/zipcodes.d.ts`. Prefer the ambient `.d.ts` so no `any` leaks — `const rec = zipcodes.lookup(trimmed) as { latitude?: number; longitude?: number } | undefined;`.)

- [ ] **Step 5: Run it** — `cd apps/api && bun test test/geocoder.test.mts` — expect PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/services/geocoder.mts apps/api/test/geocoder.test.mts apps/api/package.json apps/api/src/types 2>/dev/null
git commit -m "feat(api): zipcodes-backed geocoder service"
```

### Task 3: Geocode gym coordinates on creation

**Files:**
- Modify: `apps/api/src/container.mts`, `apps/api/src/facades/gym.facade.mts`, `apps/api/src/facades/open-mat.facade.mts`
- Test: `apps/api/test/gym.facade.test.mts` (extend or create), `apps/api/test/open-mat.facade.test.mts` (extend)

- [ ] **Step 1: Write failing facade tests.** Use a fake geocoder. In a gym-facade test:

```typescript
import { GymFacade } from "../src/facades/gym.facade.mts";
import type { Geocoder } from "../src/services/geocoder.mts";

const geo: Geocoder = { lookupZip: (z) => (z === "75495" ? { lat: 33.42, lng: -96.58 } : null) };

it("geocodes postalCode when no location is supplied", async () => {
  const inserted: unknown[] = [];
  const gyms = { insert: async (g: unknown) => { inserted.push(g); return g; }, findById: async () => null, update: async () => null, list: async () => ({ items: [], total: 0 }), listByOwner: async () => ({ items: [], total: 0 }), findNearby: async () => [] };
  const favorites = { add: async () => {}, remove: async () => {}, listGymIds: async () => [] };
  const f = new GymFacade(gyms as never, favorites as never, () => "g-1", geo);
  const g = await f.create("owner-1", { name: "North Texas BJJ", address: "1 Main St", postalCode: "75495" } as never);
  expect(g.location).toEqual({ lat: 33.42, lng: -96.58 });
});
```

(Match the exact `GymRepository`/`FavoriteRepository` method shapes the constructor `Pick`s. Read `gym.facade.mts` for current signature. The new 4th ctor arg is `geocoder`.)

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/gym.facade.test.mts` — expect FAIL (ctor arity).

- [ ] **Step 3: Edit `gym.facade.mts`.** Add the geocoder dep and use it in `create`:

```typescript
import type { Geocoder } from "../services/geocoder.mts";
// ...
  public constructor(
    private readonly gyms: Pick<GymRepository, "insert" | "findById" | "update" | "list" | "listByOwner" | "findNearby">,
    private readonly favorites: Pick<FavoriteRepository, "add" | "remove" | "listGymIds">,
    private readonly newId: IdFactory,
    private readonly geocoder: Pick<Geocoder, "lookupZip">,
  ) {}

  public async create(ownerId: string, req: CreateGymRequest): Promise<Gym> {
    const location = req.location ?? (req.postalCode ? (this.geocoder.lookupZip(req.postalCode) ?? undefined) : undefined);
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
      location,
      googlePlaceId: req.googlePlaceId,
      phone: req.phone,
      website: req.website,
      amenities: req.amenities ?? [],
      isVerified: false,
      createdAt: new Date().toISOString(),
    };
    return this.gyms.insert(gym);
  }
```

- [ ] **Step 4: Edit `open-mat.facade.mts`** — geocode the inline `newGym` on create. Add a geocoder dep to the constructor (5th arg) and change the `newGym` insert block:

```typescript
import type { Geocoder } from "../services/geocoder.mts";
// ctor: add `private readonly geocoder: Pick<Geocoder, "lookupZip">,` as the last param.
// in create(), the req.newGym branch:
    } else if (req.newGym) {
      const loc =
        req.newGym.latitude !== undefined && req.newGym.longitude !== undefined
          ? { lat: req.newGym.latitude, lng: req.newGym.longitude }
          : req.newGym.postalCode
            ? (this.geocoder.lookupZip(req.newGym.postalCode) ?? undefined)
            : undefined;
      gym = await this.gyms.insert({
        id: this.newId(),
        name: req.newGym.name,
        address: req.newGym.address,
        city: req.newGym.city,
        state: req.newGym.state,
        postalCode: req.newGym.postalCode,
        country: req.newGym.country,
        location: loc,
        amenities: [],
        isVerified: false,
        createdAt: new Date().toISOString(),
      });
    } else {
```

(The `detail.latitude/longitude` already derive from `gym.location?.lat/lng` further down — no change needed there. Confirm `GymRepository.insert` accepts a `location` field on the gym object; it does — `Gym.location` is the model field.)

- [ ] **Step 5: Wire the container.** In `container.mts`:

```typescript
import { ZipcodesGeocoder } from "./services/geocoder.mts";
// after `const id = ...`:
  const geocoder = new ZipcodesGeocoder();
// update constructions:
    gymFacade: new GymFacade(gymRepo, favoriteRepo, id, geocoder),
    openMatFacade: new OpenMatFacade(openMatRepo, gymRepo, rsvpRepo, id, geocoder),
```

- [ ] **Step 6: Fix existing facade tests' constructor calls.** Grep: `grep -rn "new GymFacade\|new OpenMatFacade" apps/api/test`. Add a fake geocoder (`{ lookupZip: () => null }`) as the trailing arg to every construction.

- [ ] **Step 7: Run** — `cd apps/api && bun test test/gym.facade.test.mts test/open-mat.facade.test.mts` — expect PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/api/src/container.mts apps/api/src/facades apps/api/test
git commit -m "feat(api): geocode gym coordinates from postalCode on create"
```

---

## Phase C — API list filters

### Task 4: Text, free, and date-range ("When") filtering

**Files:**
- Modify: `apps/api/src/repositories/open-mat.repository.mts`
- Test: `apps/api/test/open-mat.repository.test.mts` (extend/create — needs a live Mongo; follow the existing repo/integration test style if present, otherwise assert on the query builder — see Step 1)

- [ ] **Step 1: Write failing tests.** Prefer a small pure helper for the weekday math so it's unit-testable without Mongo. Add to `open-mat.repository.mts` and test in `apps/api/test/weekdays-in-range.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { weekdaysInRange } from "../src/repositories/open-mat.repository.mts";

describe("weekdaysInRange", () => {
  it("a single Saturday yields [6]", () => {
    expect(weekdaysInRange("2026-07-04", "2026-07-04")).toEqual([6]); // 2026-07-04 is a Saturday
  });
  it("a weekend yields Sat+Sun", () => {
    expect(new Set(weekdaysInRange("2026-07-04", "2026-07-05"))).toEqual(new Set([6, 0]));
  });
  it("a full week yields all 7 and caps", () => {
    expect(weekdaysInRange("2026-07-01", "2026-07-31").length).toBe(7);
  });
  it("a single Wednesday excludes Saturday", () => {
    expect(weekdaysInRange("2026-07-08", "2026-07-08")).toEqual([3]); // Wed
  });
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/weekdays-in-range.test.mts` — expect FAIL (export missing).

- [ ] **Step 3: Implement + wire the filter.** In `open-mat.repository.mts`:

Add the exported helper (top-level):

```typescript
export function weekdaysInRange(startDate: string, endDate: string): number[] {
  const start = new Date(`${startDate}T00:00:00Z`);
  const end = new Date(`${endDate}T00:00:00Z`);
  const days = new Set<number>();
  const cur = new Date(start);
  while (cur.getTime() <= end.getTime() && days.size < 7) {
    days.add(cur.getUTCDay());
    cur.setUTCDate(cur.getUTCDate() + 1);
  }
  return [...days];
}
```

Extend `OpenMatFilter`:

```typescript
export interface OpenMatFilter {
  dayOfWeek?: number;
  giType?: GiType;
  skillLevel?: SkillLevel;
  gymOwnerId?: string;
  gymId?: string;
  hostId?: string;
  verified?: boolean;
  status?: "live" | "hidden";
  q?: string;
  free?: boolean;
  startDate?: string;
  endDate?: string;
  lat?: number;
  lng?: number;
  radiusKm?: number;
}
```

Refactor `list` to build a shared `match` filter (scalar keys + an `$and` of or-groups), then branch on geo:

```typescript
  private buildMatch(filter: OpenMatFilter): Filter<OpenMatDoc> {
    const q: Filter<OpenMatDoc> = {};
    if (filter.dayOfWeek !== undefined) q.dayOfWeek = filter.dayOfWeek;
    if (filter.skillLevel) q.skillLevel = filter.skillLevel;
    if (filter.giType === "gi") q.giType = { $in: ["gi", "both"] };
    else if (filter.giType === "nogi") q.giType = { $in: ["nogi", "both"] };
    if (filter.gymOwnerId) q.gymOwnerId = filter.gymOwnerId;
    if (filter.gymId) q.gymId = filter.gymId;
    if (filter.hostId) q.hostId = filter.hostId;
    if (filter.verified !== undefined) q.verified = filter.verified;
    if (filter.status) q.status = filter.status;
    else q.status = { $ne: "hidden" } as Filter<OpenMatDoc>["status"];

    const and: Filter<OpenMatDoc>[] = [];
    if (filter.q && filter.q.trim()) {
      const rx = { $regex: filter.q.trim(), $options: "i" };
      and.push({ $or: [{ title: rx }, { gymName: rx }] } as Filter<OpenMatDoc>);
    }
    if (filter.free) {
      and.push({ $or: [{ feeCents: 0 }, { feeCents: { $exists: false } }, { feeCents: null }] } as Filter<OpenMatDoc>);
    }
    if (filter.startDate && filter.endDate) {
      const weekdays = weekdaysInRange(filter.startDate, filter.endDate);
      and.push({
        $or: [
          { isRecurring: true, dayOfWeek: { $in: weekdays } },
          { specificDate: { $gte: filter.startDate, $lte: filter.endDate } },
        ],
      } as Filter<OpenMatDoc>);
    }
    if (and.length) q.$and = and;
    return q;
  }

  public async list(filter: OpenMatFilter, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    const match = this.buildMatch(filter);
    const col = this.collection<OpenMatDoc>(COLLECTIONS.openMats);

    if (filter.lat !== undefined && filter.lng !== undefined) {
      const radiusKm = filter.radiusKm ?? 25;
      const res = await col
        .aggregate<{ items: (OpenMatDoc & { distanceMeters: number })[]; total: { n: number }[] }>([
          {
            $geoNear: {
              near: { type: "Point", coordinates: [filter.lng, filter.lat] },
              distanceField: "distanceMeters",
              maxDistance: radiusKm * 1000,
              spherical: true,
              query: match,
            },
          },
          {
            $facet: {
              items: [{ $sort: { startTime: 1 } }, { $skip: skip }, { $limit: limit }],
              total: [{ $count: "n" }],
            },
          },
        ])
        .toArray();
      const first = res[0] ?? { items: [], total: [] };
      return {
        items: first.items.map((d) => ({ ...toListItem(d), distanceKm: d.distanceMeters / 1000 })),
        total: first.total[0]?.n ?? 0,
      };
    }

    const total = await col.countDocuments(match);
    const docs = await col.find(match).sort({ startTime: 1 }).skip(skip).limit(limit).toArray();
    return { items: docs.map(toListItem), total };
  }
```

- [ ] **Step 4: Run** — `cd apps/api && bun test test/weekdays-in-range.test.mts` (PASS) and `cd apps/api && bun run type-check` (clean).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/open-mat.repository.mts apps/api/test/weekdays-in-range.test.mts
git commit -m "feat(api): open-mat list text/free/date-range/geo filtering"
```

### Task 5: Facade resolves zip + route maps the new params

**Files:**
- Modify: `apps/api/src/facades/open-mat.facade.mts`, `apps/api/src/routes/open-mat.routes.mts`
- Test: `apps/api/test/open-mat.routes.test.mts` (extend)

- [ ] **Step 1: Write a failing route test.** Append to the existing describe in `open-mat.routes.test.mts` (reuse its `base`/`auth` harness). Create a gym with `postalCode 75495` (which the facade geocodes) + a Saturday session, then filter:

```typescript
it("search filters by zip (geocoded) and free", async () => {
  const created = await (await fetch(`${base}/api/v1/open-mats`, {
    method: "POST", headers: auth,
    body: JSON.stringify({ newGym: { name: "NT BJJ", address: "1 Main St", postalCode: "75495" }, title: "Sat Rolls", startTime: "11:00", endTime: "13:00", dayOfWeek: 6, giType: "nogi", feeCents: 0 }),
  })).json();
  expect(created.data.id).toBeTruthy();
  const res = await fetch(`${base}/api/v1/open-mats?zip=75495&radiusKm=25&free=true`, { headers: auth });
  const json = await res.json();
  expect(res.status).toBe(200);
  const ids = (json.data as { id: string }[]).map((o) => o.id);
  expect(ids).toContain(created.data.id);
});

it("search excludes far results by radius", async () => {
  // Same gym is near 75495; searching from far away with a tiny radius returns nothing near it.
  const res = await fetch(`${base}/api/v1/open-mats?lat=40.7&lng=-74.0&radiusKm=5`, { headers: auth });
  const json = await res.json();
  expect((json.data as { gymName?: string }[]).some((o) => o.gymName === "NT BJJ")).toBe(false);
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/open-mat.routes.test.mts` — expect FAIL (route ignores zip/lat/lng/free).

- [ ] **Step 3: Edit `open-mat.facade.mts` `list`** to accept + resolve `zip`. Change the signature to take the raw query pieces (or extend `OpenMatFilter` with `zip`). Add `zip?: string` to the `list` param and resolve it:

```typescript
  public async list(filter: OpenMatFilter & { zip?: string }, skip: number, limit: number): Promise<{ items: OpenMat[]; total: number }> {
    let { lat, lng } = filter;
    if ((lat === undefined || lng === undefined) && filter.zip) {
      const p = this.geocoder.lookupZip(filter.zip);
      if (p) { lat = p.lat; lng = p.lng; }
    }
    return this.mats.list({ ...filter, lat, lng }, skip, limit);
  }
```

- [ ] **Step 4: Edit the list route** in `open-mat.routes.mts`. Read the current GET `/` handler and map the new query fields into the facade `list` call (`q`, `free`, `startDate`, `endDate`, `lat`, `lng`, `radiusKm`, `zip`) alongside the existing ones. The route already validates against `OpenMatListQuery` (now extended in Task 1), so `query` carries the fields — pass them through:

```typescript
      const { page = 1, limit = 20, ...rest } = query;
      const skip = (page - 1) * limit;
      const result = await openMatFacade.list(
        {
          dayOfWeek: rest.dayOfWeek,
          giType: rest.giType,
          skillLevel: rest.skillLevel,
          verified: rest.verified,
          status: rest.status,
          q: rest.q,
          free: rest.free,
          startDate: rest.startDate,
          endDate: rest.endDate,
          lat: rest.lat,
          lng: rest.lng,
          radiusKm: rest.radiusKm,
          zip: rest.zip,
          // preserve existing mine/submittedByMe → gymOwnerId/hostId mapping already in the handler
        },
        skip,
        limit,
      );
```

(IMPORTANT: read the existing handler first — it already derives `gymOwnerId` from `mine` and `hostId` from `submittedByMe` using the identity. Keep that logic; only ADD the new fields. Do not drop the `mine`/`submittedByMe` behavior.)

- [ ] **Step 5: Run + full gate** — `cd apps/api && bun test test/open-mat.routes.test.mts` (PASS), then `cd apps/api && bun run verify` (type-check + lint + all tests green).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/facades/open-mat.facade.mts apps/api/src/routes/open-mat.routes.mts apps/api/test/open-mat.routes.test.mts
git commit -m "feat(api): GET /open-mats resolves zip + applies search filters"
```

---

## Phase D — Mobile data layer

### Task 6: NewGymInput coords, WhenRange presets, SearchQuery

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/data/session_requests.dart`
- Create: `apps/mobile/lib/features/search/data/when_range.dart`, `apps/mobile/lib/features/search/data/search_query.dart`
- Test: `apps/mobile/test/features/when_range_test.dart` (new)

- [ ] **Step 1: Write the failing test** at `apps/mobile/test/features/when_range_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/search/data/when_range.dart';

void main() {
  test('thisWeekend spans the upcoming Sat..Sun', () {
    final r = WhenRange.thisWeekend(DateTime(2026, 7, 1)); // Wed
    expect(r.start.weekday, DateTime.saturday);
    expect(r.end.weekday, DateTime.sunday);
    expect(r.startIso, '2026-07-04');
    expect(r.endIso, '2026-07-05');
  });

  test('singleDay start==end', () {
    final r = WhenRange.singleDay(DateTime(2026, 7, 8)); // Wed
    expect(r.startIso, '2026-07-08');
    expect(r.endIso, '2026-07-08');
  });

  test('thisWeek is a 7-day window from the given day', () {
    final r = WhenRange.thisWeek(DateTime(2026, 7, 1));
    expect(r.startIso, '2026-07-01');
    expect(r.endIso, '2026-07-07');
  });
}
```

- [ ] **Step 2: Run it** — `cd apps/mobile && flutter test test/features/when_range_test.dart` — expect FAIL.

- [ ] **Step 3: Create `when_range.dart`**

```dart
class WhenRange {
  final DateTime start;
  final DateTime end;
  const WhenRange(this.start, this.end);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get startIso => _iso(start);
  String get endIso => _iso(end);

  static WhenRange singleDay(DateTime d) => WhenRange(DateTime(d.year, d.month, d.day), DateTime(d.year, d.month, d.day));

  static WhenRange thisWeek(DateTime from) {
    final s = DateTime(from.year, from.month, from.day);
    return WhenRange(s, s.add(const Duration(days: 6)));
  }

  /// Upcoming Saturday..Sunday (inclusive). If already the weekend, uses the current one.
  static WhenRange thisWeekend(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    final daysUntilSat = (DateTime.saturday - base.weekday) % 7;
    final sat = base.add(Duration(days: daysUntilSat));
    return WhenRange(sat, sat.add(const Duration(days: 1)));
  }

  static WhenRange thisMonth(DateTime from) {
    final s = DateTime(from.year, from.month, 1);
    final e = DateTime(from.year, from.month + 1, 0);
    return WhenRange(s, e);
  }
}
```

- [ ] **Step 4: Create `search_query.dart`**

```dart
import 'when_range.dart';

class SearchQuery {
  final String? text;
  final String? giType; // gi|nogi|both
  final bool free;
  final WhenRange? when;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final String? zip;

  const SearchQuery({this.text, this.giType, this.free = false, this.when, this.lat, this.lng, this.radiusKm, this.zip});

  Map<String, dynamic> toQueryParameters() => {
        if (text != null && text!.trim().isNotEmpty) 'q': text!.trim(),
        if (giType != null) 'giType': giType,
        if (free) 'free': true,
        if (when != null) 'startDate': when!.startIso,
        if (when != null) 'endDate': when!.endIso,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radiusKm': radiusKm,
        if (zip != null && zip!.trim().isNotEmpty) 'zip': zip!.trim(),
        'limit': 50,
      };

  SearchQuery copyWith({String? text, String? giType, bool? free, WhenRange? when, double? lat, double? lng, double? radiusKm, String? zip, bool clearGi = false, bool clearWhen = false, bool clearGeo = false}) =>
      SearchQuery(
        text: text ?? this.text,
        giType: clearGi ? null : (giType ?? this.giType),
        free: free ?? this.free,
        when: clearWhen ? null : (when ?? this.when),
        lat: clearGeo ? null : (lat ?? this.lat),
        lng: clearGeo ? null : (lng ?? this.lng),
        radiusKm: radiusKm ?? this.radiusKm,
        zip: clearGeo ? null : (zip ?? this.zip),
      );
}
```

- [ ] **Step 5: Add coords to `NewGymInput`** in `session_requests.dart`:

```dart
class NewGymInput {
  final String name;
  final String address;
  final String? city;
  final String? state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  const NewGymInput({required this.name, required this.address, this.city, this.state, this.postalCode, this.latitude, this.longitude});
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}
```

- [ ] **Step 6: Run + analyze** — `cd apps/mobile && flutter test test/features/when_range_test.dart` (PASS) and `flutter analyze lib/features/search lib/features/open_mats/data/session_requests.dart` (clean).

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/search apps/mobile/lib/features/open_mats/data/session_requests.dart apps/mobile/test/features/when_range_test.dart
git commit -m "feat(mobile): WhenRange presets, SearchQuery, NewGymInput coords"
```

### Task 7: Search repository

**Files:**
- Create: `apps/mobile/lib/features/search/data/search_repository.dart`
- Test: `apps/mobile/test/data/search_repository_test.dart` (new)

- [ ] **Step 1: Write the failing test** at `apps/mobile/test/data/search_repository_test.dart`. Mirror `apps/mobile/test/data/session_repository_test.dart` (Dio + a captured request adapter — read that file for the exact mock setup).

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/search/data/search_repository.dart';
import 'package:bjj_open_mat/features/search/data/search_query.dart';

void main() {
  test('search sends the query params and parses the list envelope', () async {
    late Map<String, dynamic> sentParams;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((options) {
      sentParams = options.queryParameters;
      return ResponseBody.fromString(
        '{"data":[{"id":"om1","gymId":"g1","title":"Sat","startTime":"11:00","endTime":"13:00","giType":"nogi","gymName":"NT BJJ"}],"meta":{"page":1,"limit":50,"total":1}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });
    final repo = ApiSearchRepository(dio);
    final res = await repo.search(const SearchQuery(text: 'sat', giType: 'nogi', free: true, zip: '75495'));
    expect(res.single.gymName, 'NT BJJ');
    expect(sentParams['q'], 'sat');
    expect(sentParams['giType'], 'nogi');
    expect(sentParams['free'], true);
    expect(sentParams['zip'], '75495');
  });
}

// _FakeAdapter: copy the adapter pattern from session_repository_test.dart.
```

- [ ] **Step 2: Run it** — `cd apps/mobile && flutter test test/data/search_repository_test.dart` — expect FAIL.

- [ ] **Step 3: Create `search_repository.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../../open_mats/models/open_mat.dart';
import 'search_query.dart';

abstract class SearchRepository {
  Future<List<OpenMat>> search(SearchQuery query);
}

class ApiSearchRepository implements SearchRepository {
  final Dio _dio;
  ApiSearchRepository(this._dio);

  @override
  Future<List<OpenMat>> search(SearchQuery query) async {
    try {
      final res = await _dio.get('/api/v1/open-mats', queryParameters: query.toQueryParameters());
      return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return ApiSearchRepository(ref.read(apiClientProvider).dio);
});

final searchResultsProvider = FutureProvider.family<List<OpenMat>, SearchQuery>((ref, query) {
  return ref.read(searchRepositoryProvider).search(query);
});
```

(Confirm `unwrapList(...).items` and `apiClientProvider.dio` match `session_repository.dart` — they do.)

- [ ] **Step 4: Run + analyze** — `cd apps/mobile && flutter test test/data/search_repository_test.dart` (PASS), `flutter analyze lib/features/search/data` (clean).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/search/data/search_repository.dart apps/mobile/test/data/search_repository_test.dart
git commit -m "feat(mobile): search repository + results provider"
```

---

## Phase E — Mobile SearchScreen

### Task 8: Rewire SearchScreen to the API (state + query + results)

**Files:**
- Modify: `apps/mobile/lib/features/search/screens/search_screen.dart`
- Test: `apps/mobile/test/features/search_screen_test.dart` (new)

**Design:** Keep the existing visual structure (both `_buildSport` and `_buildGlass`). Replace the local `_sessions`/`_filtered` stub logic with a `SearchQuery` in state that drives `searchResultsProvider`. Add: `WhenRange? _when` + tappable When options (This week / This weekend / This month / Pick a date), a zip `TextField`, and a GPS toggle that reads `locationServiceProvider`. The `_searchCtrl` feeds `q`; the distance slider feeds `radiusKm` (miles → km: `radiusKm = miles * 1.60934`); chips feed `giType`/`free`. Results render from the provider's `AsyncValue` (loading spinner / empty text / error text / `SessionRow` list built from `OpenMat`). Tapping a result → `context.go('/open-mat/<id>')`.

- [ ] **Step 1: Write the failing widget test** at `apps/mobile/test/features/search_screen_test.dart`. Override `searchRepositoryProvider` with a fake that records the last `SearchQuery`, and the location service. Assert: selecting a "When" option and entering a zip produce a query with `startDate/endDate` and `zip`, and results render.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:bjj_open_mat/features/search/data/search_query.dart';
import 'package:bjj_open_mat/features/search/data/search_repository.dart';
import 'package:bjj_open_mat/features/search/screens/search_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

class _FakeLoc implements LocationService {
  @override
  Future<CapturedLocation?> current() async => const CapturedLocation(latitude: 33.4, longitude: -96.5, accuracyM: 5);
}

class _FakeSearch implements SearchRepository {
  SearchQuery? last;
  @override
  Future<List<OpenMat>> search(SearchQuery query) async {
    last = query;
    return const [OpenMat(id: 'om1', gymId: 'g1', title: 'Sat Rolls', startTime: '11:00', endTime: '13:00', gymName: 'NT BJJ')];
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('zip + When feed the query and results render', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fake = _FakeSearch();

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const SearchScreen()),
      GoRoute(path: '/open-mat/:id', builder: (c, s) => const Scaffold(body: Text('detail'))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(fake),
        locationServiceProvider.overrideWithValue(_FakeLoc()),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    await tester.tap(find.byKey(const Key('when-weekend')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.last, isNotNull);
    expect(fake.last!.zip, '75495');
    expect(fake.last!.when, isNotNull);
    expect(find.text('NT BJJ'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it** — `cd apps/mobile && flutter test test/features/search_screen_test.dart` — expect FAIL (keys/widgets missing).

- [ ] **Step 3: Rewrite `search_screen.dart`.** Read the current file first (it has both Sport and Glass builders). Make these changes while preserving styling:
  - Remove the `_sessions` stub list and `_filtered` getter.
  - Add state: `SearchQuery _query = const SearchQuery(radiusKm: 16);` (≈10mi), `WhenRange? _when`, `double _distanceMi = 10`, and a `_zipCtrl` TextEditingController.
  - Add a private `_run()` that rebuilds `_query` from the controls and `setState`s; call it (debounced ~300ms for text) on every control change.
  - Add a **When** row with four tappable pills, each with a `Key`: `Key('when-week')`, `Key('when-weekend')`, `Key('when-month')`, `Key('when-date')` (the last opens `showDatePicker` → `WhenRange.singleDay`). Selecting sets `_when` and calls `_run()`. Replace the hardcoded "This Weekend" text with the selected label.
  - Add a **zip** `TextField(key: Key('search-zip'))` near the GPS control; on submit set `_query = _query.copyWith(zip: ..., clearGeo: true)` then re-set zip; `_run()`.
  - Add a **GPS** toggle (the existing "GPS" pill): on tap read `await ref.read(locationServiceProvider).current()`; if non-null set `lat/lng`, clear `zip`, `_run()`.
  - Distance slider `onChanged` sets `_distanceMi` and `_query.radiusKm = _distanceMi * 1.60934`; `_run()`.
  - Gi/No-Gi/Both chips set `giType` (or clear); Free chip sets `free`. `_run()`.
  - Results: `final results = ref.watch(searchResultsProvider(_query));` then `results.when(loading: spinner, error: (e,_) => Text('Couldn\'t load results'), data: (list) => ListView(... SessionRow.fromOpenMat ...))`. Build a `SessionRowData` from each `OpenMat` (gymName, giType, skillLevel, `mat.startLabel`, `mat.dayName`, distance from `mat.distanceKm` if present, `mat.feeCents`). Wrap each row in `GestureDetector(onTap: () => context.go('/open-mat/${mat.id}'))`.

  Keep both Sport and Glass variants functional; the widget test runs under Glass. Add `import '../../../core/location/location_service.dart';`, `import '../data/search_query.dart';`, `import '../data/search_repository.dart';`, `import '../data/when_range.dart';`, `import 'package:go_router/go_router.dart';`, and the `OpenMat` model import.

- [ ] **Step 4: Run + analyze** — `cd apps/mobile && flutter test test/features/search_screen_test.dart` (PASS), then `flutter analyze lib/features/search` (clean), then `flutter test` (whole suite green — the old `search_filter_test.dart` unit test asserts stub behavior that no longer exists; DELETE `apps/mobile/test/features/search_filter_test.dart` since its subject, the in-memory stub filter, is gone, and this task's test replaces it).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/search apps/mobile/test/features/search_screen_test.dart
git rm apps/mobile/test/features/search_filter_test.dart
git commit -m "feat(mobile): SearchScreen wired to API with When/Within/GPS/zip filters"
```

---

## Phase F — Discover/home live data

### Task 9: Discover uses real nearby data

**Files:**
- Modify: `apps/mobile/lib/features/discover/providers/discover_provider.dart`, `apps/mobile/lib/features/discover/screens/discover_screen.dart`
- Test: extend `apps/mobile/test/features/` with a discover widget test (new: `discover_screen_test.dart`)

- [ ] **Step 1: Write the failing widget test** `apps/mobile/test/features/discover_screen_test.dart`: override the discover provider (or the search/session repo it delegates to) to return one live `OpenMat`; assert the real gym name renders and the stub names (e.g. 'Marcelo Garcia NY') do NOT.

```dart
// Pattern mirrors search_screen_test.dart: ProviderScope overrides + AppTheme.glass()
// Assert find.text('<live gym>') findsWidgets and find.text('Atos HQ') from stubs is gone
// (choose an assertion tied to whatever provider discover_screen ends up watching).
```

- [ ] **Step 2: Run it** — expect FAIL (screen shows stubs).

- [ ] **Step 3: Fix `discover_provider.dart`** so `nearbyOpenMatsProvider` actually sends the location/query (use `searchResultsProvider` or call the list endpoint with `lat`/`lng`/`radiusKm` from the passed `NearbyQuery` instead of the hardcoded `page/limit`). Prefer delegating to the new `searchRepositoryProvider` with a `SearchQuery(lat, lng, radiusKm)`.

- [ ] **Step 4: Fix `discover_screen.dart`** to watch the provider and render live data (loading/empty/error states); remove `_stubSessions`. Cards navigate to `/open-mat/<id>`. Obtain the user location via `locationServiceProvider`; if null, fall back to a plain (non-geo) list.

- [ ] **Step 5: Run + analyze** — `cd apps/mobile && flutter test test/features/discover_screen_test.dart` (PASS), `flutter analyze lib/features/discover` (clean), `flutter test` (whole suite green).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/discover apps/mobile/test/features/discover_screen_test.dart
git commit -m "feat(mobile): discover screen renders live nearby open mats"
```

---

## Phase G — E2E with screenshots + video

### Task 10: Integration driver (screenshots) + e2e test + run script

**Files:**
- Create: `apps/mobile/test_driver/integration_test.dart`, `apps/mobile/integration_test/search_filter_test.dart`
- Modify: root `package.json` (`mobile:e2e:search`), `apps/mobile/pubspec.yaml` (ensure `integration_test` + `flutter_driver`/`flutter_test` dev deps present — `integration_test` already used)

- [ ] **Step 1: Create the screenshot driver** `apps/mobile/test_driver/integration_test.dart`

```dart
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Directory('build/e2e');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('build/e2e/$name.png');
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
```

- [ ] **Step 2: Create the e2e test** `apps/mobile/integration_test/search_filter_test.dart`. Reuse the `pumpUntilFound` helper and login pattern from `create_open_mat_session_test.dart`. Structure (fill finders by reading the create-session screen + the rewritten SearchScreen — the create-new-gym flow finders come from `create_session_gym_test.dart`/the create screen):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bjj_open_mat/main.dart' as app;

Future<bool> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create gym + Saturday Gi/No-Gi sessions, then search/filter them', (tester) async {
    await binding.convertFlutterSurfaceToImage(); // Android: enable screenshots
    app.main();
    expect(await pumpUntilFound(tester, find.text('Find your roll')), isTrue);
    await binding.takeScreenshot('01-home');

    // 1) Create a NEW gym (not in seed) + a Saturday 11:00 Gi session via the "+" flow.
    //    Read create_open_mat_session_test.dart + the create screen for the exact finders:
    //    open FAB -> 'Post Session' -> choose "add new gym" affordance -> enter
    //    name 'North Texas BJJ', address '100 Main St', postalCode '75495' ->
    //    set day = Saturday, start 11:00 -> giType Gi -> submit -> 'Session posted!'.
    //    Repeat for a No-Gi Saturday 11:00 session (same new gym, now selectable).
    await binding.takeScreenshot('02-sessions-created');

    // 2) SEARCH: go to Search, verify both sessions appear.
    final ctx = tester.element(find.text('Find your roll').first);
    // ignore: use_build_context_synchronously
    ctx.go('/search'); // confirm the search route path in router.dart
    expect(await pumpUntilFound(tester, find.text('North Texas BJJ')), isTrue);
    await binding.takeScreenshot('03-search-results');

    // 3) ZIP search 75495.
    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(await pumpUntilFound(tester, find.text('North Texas BJJ')), isTrue);
    await binding.takeScreenshot('04-zip-75495');

    // 4) WHEN = This weekend (Saturday) -> still present.
    await tester.tap(find.byKey(const Key('when-weekend')));
    expect(await pumpUntilFound(tester, find.text('North Texas BJJ')), isTrue);
    await binding.takeScreenshot('05-when-weekend');

    // 5) WHEN = a single Wednesday -> excluded (negative).
    await tester.tap(find.byKey(const Key('when-date'))); // opens date picker; pick a Wednesday
    // ...pick a non-Saturday date via the date picker, confirm...
    expect(await pumpUntilFound(tester, find.text('North Texas BJJ'), timeout: const Duration(seconds: 6)), isFalse);
    await binding.takeScreenshot('06-when-weekday-excluded');

    // 6) GPS + Within: emulator location set near 75495 by the run script; tap GPS pill.
    //    Verify present with a large radius; then a far point / tiny radius excludes.
    await binding.takeScreenshot('07-gps-within');
  });
}
```

(The create-new-gym finders and the exact `/search` route are the two things to confirm against the code while implementing — do not guess; read `router.dart` and the create-session screen.)

- [ ] **Step 3: Add the run script** to root `package.json`. It sets a mock GPS fix, records video, runs the driver, then pulls the video:

```json
"mobile:e2e:search": "cd apps/mobile && node ../../scripts/e2e-search.mjs"
```

Create `scripts/e2e-search.mjs` (Node, cross-platform-ish; assumes `adb`/`flutter` on PATH):

```javascript
import { spawn, spawnSync } from 'node:child_process';

const ADB = process.env.ADB || 'adb';
const DEVICE = process.env.DEVICE || 'emulator-5554';
const SECRET = process.env.AUTH_BYPASS_TOKEN || 'TopFlightApiSecurity2026+';

// 1) Mock GPS near 75495 (Van Alstyne, TX): lng lat order.
spawnSync(ADB, ['-s', DEVICE, 'emu', 'geo', 'fix', '-96.58', '33.42'], { stdio: 'inherit' });

// 2) Start screen recording (max 180s per file).
const rec = spawn(ADB, ['-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '180', '/sdcard/e2e.mp4'], { stdio: 'inherit' });

// 3) Run the e2e via flutter drive (writes screenshots to build/e2e).
const drive = spawnSync('flutter', [
  'drive',
  '--driver=test_driver/integration_test.dart',
  '--target=integration_test/search_filter_test.dart',
  '-d', DEVICE,
  '--dart-define=DEV_BYPASS=true',
  `--dart-define=AUTH_BYPASS_TOKEN=${SECRET}`,
  '--dart-define=API_BASE_URL=http://10.0.2.2:3100',
], { stdio: 'inherit', shell: process.platform === 'win32' });

// 4) Stop recording + pull the video.
spawnSync(ADB, ['-s', DEVICE, 'shell', 'pkill', '-INT', 'screenrecord'], { stdio: 'inherit' });
try { rec.kill('SIGINT'); } catch {}
await new Promise((r) => setTimeout(r, 2500)); // let screenrecord flush
spawnSync(ADB, ['-s', DEVICE, 'pull', '/sdcard/e2e.mp4', 'build/e2e/e2e.mp4'], { stdio: 'inherit' });

process.exit(drive.status ?? 1);
```

(The bypass token MUST equal the API's `AUTH_BYPASS_SECRET` — currently `TopFlightApiSecurity2026+` in `apps/api/.env`.)

- [ ] **Step 4: Run the e2e** (API + Mongo seeded + emulator up):

```bash
bun run mobile:e2e:search
```

Expected: `All tests passed!`; `apps/mobile/build/e2e/` contains `01-home.png … 07-gps-within.png` and `e2e.mp4`. If the run exceeds 180s, split `screenrecord` into chunks (loop) or trim the test.

- [ ] **Step 5: Verify artifacts** — confirm the PNGs and mp4 exist and are non-empty; open a couple to eyeball the flow.

- [ ] **Step 6: Commit** (build artifacts are git-ignored, so only source is committed)

```bash
git add apps/mobile/test_driver/integration_test.dart apps/mobile/integration_test/search_filter_test.dart scripts/e2e-search.mjs package.json
git commit -m "test(mobile): e2e search/filter flow with screenshots + video capture"
```

---

## Self-review notes

- **Spec coverage:** contract fields (Task 1); geocoder (Task 2); gym coords on create (Task 3); text/free/When/Within repo filtering (Task 4); zip resolution + route wiring (Task 5); mobile WhenRange/SearchQuery/NewGym coords (Task 6); search repo (Task 7); SearchScreen rewrite with When/Within/GPS/zip (Task 8); Discover live data (Task 9); e2e + screenshots + video (Task 10). All spec sections mapped.
- **When negative case** is a single non-Saturday date via the picker (recurring Saturday session has no occurrence in a Wednesday-only range) — matches the spec.
- **Distance units:** UI slider is miles; convert to km (`*1.60934`) before sending `radiusKm`. Keep this consistent between Task 8 and the e2e.
- **`OpenMat.distanceKm`** already exists on the model and is returned by the geo list path — SessionRow can show it.
- **Don't regress `mine`/`submittedByMe`** in the list route (Task 5 Step 4) — only add fields.
- **`convertFlutterSurfaceToImage()`** is required on Android before `takeScreenshot`; screenshots only work under `flutter drive` with the `test_driver`, not plain `flutter test`.
- **GPS on the emulator** is mocked via `adb emu geo fix`; if geolocator ignores it on this image, the zip path (Task 5 test + e2e step 3) covers the same distance logic — note it and rely on zip for the hard assertion.
- **Confirm before coding:** the search route path in `router.dart` (`/search`?), and the create-new-gym finders in the create-session screen (read `create_session_gym_test.dart`).
