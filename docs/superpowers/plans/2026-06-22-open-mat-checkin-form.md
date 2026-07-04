# Open-Mat Check-In Form Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the no-op "Check In" button into a real check-in form that records a training-session log plus captured GPS, timestamp, and a gym/session snapshot, with a soft location-trust flag that never blocks check-in.

**Architecture:** Extend the existing check-in stack (CheckIn schema, `POST /open-mats/:id/checkin`, `CheckInFacade`). The facade gains `openMatRepo`+`userRepo` deps to build the snapshot and compute a haversine distance → `locationStatus`. Mobile adds an injectable `LocationService`, a richer request DTO/model, a `checkIn` repo method, and a `CheckInFormScreen` wired to the detail button.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (API); Flutter + Riverpod + go_router + Dio + geolocator (mobile). Spec: `docs/superpowers/specs/2026-06-22-open-mat-checkin-form-design.md`.

**Git note:** Per project policy, commits are authored by the user. Treat each "Commit" step as a checkpoint; run it only if the executing context is authorized to commit, otherwise leave changes staged.

---

## File Structure

**Contract (`packages/contract/src`)**
- `enums/check-in-location-status.mts` (new) — `CheckInLocationStatus` union.
- `schemas/check-in.mts` — add GPS/flag/snapshot/log fields to `CheckIn`.
- `schemas/requests/check-in-requests.mts` — new `CreateCheckInRequest`.
- `schemas/requests/open-mat-requests.mts` — remove now-unused `CheckinRequest`.

**API (`apps/api/src`)**
- `facades/check-in.facade.mts` — `haversineMeters`, `checkIn(openMatId,userId,req)`, new deps.
- `container.mts` — inject `openMatRepo`+`userRepo` into `CheckInFacade`.
- `routes/open-mat.routes.mts` — `POST /:id/checkin` body → `CreateCheckInRequest`.

**Mobile (`apps/mobile/lib`)**
- `core/location/location_service.dart` (new) — geolocator wrapper + provider.
- `features/checkins/models/checkin.dart` — new fields.
- `features/checkins/data/check_in_request.dart` (new) — `CreateCheckInRequest` DTO.
- `features/checkins/data/attendance_repository.dart` — `checkIn(...)` + `sessionByIdProvider`.
- `features/checkins/screens/check_in_form_screen.dart` (new) — the form.
- `features/checkins/screens/checkin_success_screen.dart` — show location status.
- `app/router.dart` — `checkin` sub-route.
- `features/open_mats/screens/open_mat_detail_screen.dart` — wire both Check In buttons.

---

## Phase A — Contract

### Task 1: CheckIn fields, location-status enum, CreateCheckInRequest

**Files:**
- Create: `packages/contract/src/enums/check-in-location-status.mts`
- Modify: `packages/contract/src/enums/index.mts`, `packages/contract/src/schemas/check-in.mts`, `packages/contract/src/schemas/requests/check-in-requests.mts`, `packages/contract/src/schemas/requests/open-mat-requests.mts`
- Test: `apps/api/test/contract-checkin.test.mts` (new)

- [ ] **Step 1: Write the failing test** at `apps/api/test/contract-checkin.test.mts`

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { CheckIn, CheckInLocationStatus, CreateCheckInRequest } from "@bjj/contract";

describe("contract: check-in form", () => {
  it("CheckInLocationStatus accepts the three states", () => {
    for (const s of ["verified", "far", "no_location"]) {
      expect(Value.Check(CheckInLocationStatus, s)).toBe(true);
    }
    expect(Value.Check(CheckInLocationStatus, "nope")).toBe(false);
  });

  it("CheckIn carries gps + flag + log fields", () => {
    const c = Value.Create(CheckIn);
    for (const k of ["latitude", "longitude", "gpsAccuracyM", "locationStatus", "distanceM", "gymId", "gymCity", "gymState", "note", "rounds", "intensity", "partners"]) {
      expect(k in c).toBe(true);
    }
  });

  it("CreateCheckInRequest requires sessionDate and accepts the log fields", () => {
    expect(Value.Check(CreateCheckInRequest, { sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2, gpsAccuracyM: 8, note: "good rounds", rounds: 5, intensity: 4, partners: 3 })).toBe(true);
    expect(Value.Check(CreateCheckInRequest, {})).toBe(false); // sessionDate required
    expect(Value.Check(CreateCheckInRequest, { sessionDate: "x", intensity: 9 })).toBe(false); // 1..5
  });
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/contract-checkin.test.mts` — expect FAIL (symbols/fields missing).

- [ ] **Step 3: Create `enums/check-in-location-status.mts`**

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const CheckInLocationStatus = t.Union(
  [t.Literal("verified"), t.Literal("far"), t.Literal("no_location")],
  { $id: "CheckInLocationStatus" },
);
export type CheckInLocationStatus = Static<typeof CheckInLocationStatus>;
```
Add `export * from "./check-in-location-status.mts";` to `enums/index.mts` (match existing export style/placement).

- [ ] **Step 4: Edit `schemas/check-in.mts`** — import the enum and add fields to the `CheckIn` object (after `categoryRatings`, alongside the existing optional fields):

```typescript
import { CheckInLocationStatus } from "../enums/check-in-location-status.mts";
// ... inside t.Object({ ... }) of CheckIn, add:
    latitude: t.Optional(t.Number()),
    longitude: t.Optional(t.Number()),
    gpsAccuracyM: t.Optional(t.Number()),
    locationStatus: t.Optional(CheckInLocationStatus),
    distanceM: t.Optional(t.Number()),
    gymId: t.Optional(t.String()),
    gymCity: t.Optional(t.String()),
    gymState: t.Optional(t.String()),
    note: t.Optional(t.String()),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
```
(`gymName`, `openMatTitle`, `userName`, `beltRank` already exist — leave them.) `locationStatus` is optional so existing one-tap check-in docs without it still type-check on read.

- [ ] **Step 5: Edit `schemas/requests/check-in-requests.mts`** — add `CreateCheckInRequest` (import `BeltRank` from `../../enums/belt-rank.mts`):

```typescript
import { BeltRank } from "../../enums/belt-rank.mts";

export const CreateCheckInRequest = t.Object(
  {
    sessionDate: t.String(),
    latitude: t.Optional(t.Number()),
    longitude: t.Optional(t.Number()),
    gpsAccuracyM: t.Optional(t.Number()),
    note: t.Optional(t.String()),
    beltRank: t.Optional(BeltRank),
    rounds: t.Optional(t.Integer({ minimum: 0 })),
    intensity: t.Optional(t.Integer({ minimum: 1, maximum: 5 })),
    partners: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateCheckInRequest" },
);
export type CreateCheckInRequest = Static<typeof CreateCheckInRequest>;
```
(`Static`/`t` are already imported in this file.) The barrel chain re-exports it automatically.

- [ ] **Step 6: Remove the now-unused `CheckinRequest`.** Grep first: `grep -rn "CheckinRequest" apps packages` — its only consumer is `apps/api/src/routes/open-mat.routes.mts` (handled in Task 3). Remove the `CheckinRequest` export from `schemas/requests/open-mat-requests.mts`. (If grep shows other consumers, leave it and note in the report.)

- [ ] **Step 7: Run + type-check** — `cd apps/api && bun test test/contract-checkin.test.mts` (PASS), then `cd packages/contract && bunx tsc --noEmit` (clean). Note: `open-mat.routes.mts` will have a type error from the removed `CheckinRequest` until Task 3 — that is expected and fixed there.

- [ ] **Step 8: Commit**

```bash
git add packages/contract apps/api/test/contract-checkin.test.mts
git commit -m "feat(contract): check-in GPS/location-status/log fields + CreateCheckInRequest"
```

---

## Phase B — API

### Task 2: Facade — haversine, snapshot, location flag

**Files:**
- Modify: `apps/api/src/facades/check-in.facade.mts`
- Test: `apps/api/test/check-in.facade.test.mts`

- [ ] **Step 1: Update the test file** (`apps/api/test/check-in.facade.test.mts`). The `CheckInFacade` constructor gains `openMats` + `users` deps before `newId`. Add fakes and update the existing three `new CheckInFacade(r, () => "c-x", () => now)` calls to `new CheckInFacade(r, openMats(), users(), () => "c-x", () => now)`. Add fakes + new tests:

```typescript
import type { OpenMatRepository } from "../src/repositories/open-mat.repository.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { OpenMatDetail, User } from "@bjj/contract";

const MAT: OpenMatDetail = {
  id: "om-1", gymId: "g-1", title: "Fri Night", startTime: "19:00", endTime: "21:00",
  isRecurring: true, skillLevel: "all", giType: "both", isCancelled: false,
  gymName: "Atos HQ", address: "9587 Distribution Ave", city: "San Diego", state: "CA",
  latitude: 32.901, longitude: -117.213,
} as OpenMatDetail;

function openMats(mat: OpenMatDetail | null = MAT): Pick<OpenMatRepository, "findById"> {
  return { findById: async (): Promise<OpenMatDetail | null> => mat };
}
function users(user: User | null = { id: "u-1", email: "a@b.dev", displayName: "Marcus", beltRank: "purple", settings: { theme: "glass", notifyRsvp: true, notifySessionUpdates: true } } as User): Pick<UserRepository, "findById"> {
  return { findById: async (): Promise<User | null> => user };
}

describe("CheckInFacade.checkIn", () => {
  it("verifies when GPS is within 500m of the gym", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), () => "c-1", () => new Date("2026-06-22T19:05:00Z"));
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 32.9012, longitude: -117.2131, note: "5 rounds", rounds: 5, intensity: 4, partners: 3 });
    expect(c.locationStatus).toBe("verified");
    expect(c.distanceM).toBeLessThan(500);
    expect(c.gymName).toBe("Atos HQ");
    expect(c.gymId).toBe("g-1");
    expect(c.gymCity).toBe("San Diego");
    expect(c.openMatTitle).toBe("Fri Night");
    expect(c.userName).toBe("Marcus");
    expect(c.beltRank).toBe("purple");
    expect(c.rounds).toBe(5);
    expect(c.intensity).toBe(4);
    expect(c.partners).toBe(3);
    expect(c.latitude).toBe(32.9012);
  });

  it("flags far when GPS is beyond 500m", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), () => "c-2");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 34.05, longitude: -118.24 });
    expect(c.locationStatus).toBe("far");
    expect(c.distanceM).toBeGreaterThan(500);
  });

  it("no_location when GPS is omitted", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), () => "c-3");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22" });
    expect(c.locationStatus).toBe("no_location");
    expect(c.distanceM).toBeUndefined();
  });

  it("no_location when the gym has no coordinates", async () => {
    const r = repo([]);
    const matNoGeo = { ...MAT, latitude: undefined, longitude: undefined } as OpenMatDetail;
    const f = new CheckInFacade(r, openMats(matNoGeo), users(), () => "c-4");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2 });
    expect(c.locationStatus).toBe("no_location");
  });

  it("falls back to the user's belt when the request omits it", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(), users(), () => "c-5");
    const c = await f.checkIn("om-1", "u-1", { sessionDate: "2026-06-22" });
    expect(c.beltRank).toBe("purple");
  });

  it("throws not_found for a missing open mat", async () => {
    const r = repo([]);
    const f = new CheckInFacade(r, openMats(null), users(), () => "c-6");
    await expect(f.checkIn("missing", "u-1", { sessionDate: "2026-06-22" })).rejects.toMatchObject({ code: "not_found" });
  });
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/check-in.facade.test.mts` — expect FAIL (ctor arity / `checkIn` signature).

- [ ] **Step 3: Rewrite `check-in.facade.mts`**

```typescript
import type { CheckIn, CheckInLocationStatus, CreateCheckInRequest, ReviewRequest } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { CheckInRepository } from "../repositories/check-in.repository.mts";
import type { OpenMatRepository } from "../repositories/open-mat.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

type IdFactory = () => string;
type Clock = () => Date;

const REVIEW_WINDOW_MS = 48 * 60 * 60 * 1000;
const VERIFY_RADIUS_M = 500;

export function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (d: number): number => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export class CheckInFacade {

  public constructor(
    private readonly checkins: Pick<CheckInRepository, "insert" | "findById" | "setReview" | "listByUser" | "listBySession">,
    private readonly openMats: Pick<OpenMatRepository, "findById">,
    private readonly users: Pick<UserRepository, "findById">,
    private readonly newId: IdFactory,
    private readonly now: Clock = () => new Date(),
  ) {}

  public async checkIn(openMatId: string, userId: string, req: CreateCheckInRequest): Promise<CheckIn> {
    const mat = await this.openMats.findById(openMatId);
    if (!mat) throw new AppError("not_found", `Open mat ${openMatId} not found`);
    const user = await this.users.findById(userId);

    let locationStatus: CheckInLocationStatus = "no_location";
    let distanceM: number | undefined;
    if (req.latitude !== undefined && req.longitude !== undefined && mat.latitude !== undefined && mat.longitude !== undefined) {
      distanceM = haversineMeters(req.latitude, req.longitude, mat.latitude, mat.longitude);
      locationStatus = distanceM <= VERIFY_RADIUS_M ? "verified" : "far";
    }

    const ts = this.now().toISOString();
    return this.checkins.insert({
      id: this.newId(),
      openMatId,
      userId,
      sessionDate: req.sessionDate,
      checkedInAt: ts,
      latitude: req.latitude,
      longitude: req.longitude,
      gpsAccuracyM: req.gpsAccuracyM,
      locationStatus,
      distanceM,
      gymId: mat.gymId,
      gymName: mat.gymName,
      gymCity: mat.city,
      gymState: mat.state,
      openMatTitle: mat.title,
      userName: user?.displayName,
      beltRank: req.beltRank ?? user?.beltRank,
      note: req.note,
      rounds: req.rounds,
      intensity: req.intensity,
      partners: req.partners,
      createdAt: ts,
    });
  }

  public async review(checkInId: string, userId: string, req: ReviewRequest): Promise<CheckIn> {
    const checkIn = await this.checkins.findById(checkInId);
    if (!checkIn) throw new AppError("not_found", `Check-in ${checkInId} not found`);
    if (checkIn.userId !== userId) throw new AppError("forbidden", "Cannot review another user's check-in");
    const elapsed = this.now().getTime() - new Date(checkIn.checkedInAt).getTime();
    if (elapsed > REVIEW_WINDOW_MS) throw new AppError("conflict", "Review window (48h) has expired");
    const updated = await this.checkins.setReview(checkInId, { rating: req.rating, review: req.review, categoryRatings: req.categoryRatings });
    return updated as CheckIn;
  }

  public async listForUser(userId: string, skip: number, limit: number): Promise<{ items: CheckIn[]; total: number }> {
    return this.checkins.listByUser(userId, skip, limit);
  }

  public async listForSession(openMatId: string, sessionDate: string | undefined): Promise<CheckIn[]> {
    return this.checkins.listBySession(openMatId, sessionDate);
  }
}
```
(`mat.city`/`mat.state` are required strings on `OpenMatDetail`, so they assign cleanly.)

- [ ] **Step 4: Run it** — `cd apps/api && bun test test/check-in.facade.test.mts` — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/check-in.facade.mts apps/api/test/check-in.facade.test.mts
git commit -m "feat(api): check-in facade builds gym/user snapshot + GPS location flag"
```

### Task 3: Container wiring + route

**Files:**
- Modify: `apps/api/src/container.mts`, `apps/api/src/routes/open-mat.routes.mts`
- Test: `apps/api/test/open-mat.routes.test.mts` (extend)

- [ ] **Step 1: Add a failing route test** (append to the existing describe; reuse its harness — bypass auth header = the demo user `u-me`). Use `newGym` to create a gym with known coordinates so the distance is deterministic.

```typescript
it("check-in stores GPS, flag, and gym snapshot", async () => {
  // create a gym+session at a known location via the open-mats create path
  const created = await (await fetch(`${base}/api/v1/open-mats`, { method: "POST", headers: auth, body: JSON.stringify({ newGym: { name: "CheckinGym", address: "1 A St" }, title: "OM", startTime: "19:00", endTime: "21:00" }) })).json();
  const id = created.data.id;
  // no gym coords -> no_location regardless of device GPS
  const res = await fetch(`${base}/api/v1/open-mats/${id}/checkin`, { method: "POST", headers: auth, body: JSON.stringify({ sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2, note: "rolled", rounds: 4, intensity: 3 }) });
  const json = await res.json();
  expect(res.status).toBe(200);
  expect(json.data.gymName).toBe("CheckinGym");
  expect(json.data.openMatTitle).toBe("OM");
  expect(json.data.note).toBe("rolled");
  expect(json.data.rounds).toBe(4);
  expect(json.data.locationStatus).toBe("no_location"); // newGym has no coordinates
  expect(json.data.latitude).toBe(32.9);
});
```

- [ ] **Step 2: Run it** — `cd apps/api && bun test test/open-mat.routes.test.mts` — expect FAIL (route still uses `CheckinRequest` body `{sessionDate}`; extra fields stripped / facade arity).

- [ ] **Step 3: Wire the container** — in `container.mts`, change the `CheckInFacade` construction to inject the repos. The repos `openMatRepo` and `userRepo` already exist as locals (`gymRepo`, `openMatRepo`, `userRepo` are constructed earlier — confirm names; the open-mat repo local is `openMatRepo`, the user repo local is `userRepo`):

```typescript
checkInFacade: new CheckInFacade(checkInRepo, openMatRepo, userRepo, id),
```

- [ ] **Step 4: Update the route** — in `open-mat.routes.mts`: replace the `CheckinRequest` import with `CreateCheckInRequest`, and change the checkin route:

```typescript
.post(
  "/:id/checkin",
  async ({ identity, params, body }) => data(await checkInFacade.checkIn(params.id, requireId(identity).userId, body)),
  { requireAuth: true, body: CreateCheckInRequest },
)
```

- [ ] **Step 5: Run + full gate** — `cd apps/api && bun test test/open-mat.routes.test.mts` (PASS), then `cd apps/api && bun run verify` (type-check + lint + all tests). Fix any fallout (e.g. the removed `CheckinRequest`).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/container.mts apps/api/src/routes/open-mat.routes.mts apps/api/test/open-mat.routes.test.mts
git commit -m "feat(api): POST /open-mats/:id/checkin accepts the full check-in form"
```

---

## Phase C — Mobile

### Task 4: Location service

**Files:**
- Create: `apps/mobile/lib/core/location/location_service.dart`

- [ ] **Step 1: Implement** a thin, never-throwing geolocator wrapper + provider:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double? accuracyM;
  const CapturedLocation({required this.latitude, required this.longitude, this.accuracyM});
}

abstract class LocationService {
  /// Returns the current location, or null if permission is denied / location is
  /// off / it times out. Never throws.
  Future<CapturedLocation?> current();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<CapturedLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());
```

- [ ] **Step 2: Verify** — `cd apps/mobile && flutter analyze lib/core/location/location_service.dart` — expect clean. (If the installed `geolocator` API differs — e.g. `desiredAccuracy:` instead of `locationSettings:` — adapt to the version in `pubspec.lock`; the contract `CapturedLocation` + provider stay the same.)

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/core/location/location_service.dart
git commit -m "feat(mobile): injectable LocationService over geolocator"
```

### Task 5: Mobile model, request DTO, repository method

**Files:**
- Modify: `apps/mobile/lib/features/checkins/models/checkin.dart`, `apps/mobile/lib/features/checkins/data/attendance_repository.dart`
- Create: `apps/mobile/lib/features/checkins/data/check_in_request.dart`
- Test: `apps/mobile/test/models/checkin_test.dart` (new)

- [ ] **Step 1: Write the failing model test** at `apps/mobile/test/models/checkin_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

void main() {
  test('parses gps + flag + log fields', () {
    final c = CheckIn.fromJson({
      'id': 'c1', 'openMatId': 'om1', 'userId': 'u1', 'sessionDate': '2026-06-22', 'checkedInAt': 't',
      'latitude': 32.9, 'longitude': -117.2, 'locationStatus': 'verified', 'distanceM': 120.5,
      'gymCity': 'San Diego', 'note': 'good', 'rounds': 5, 'intensity': 4, 'partners': 2,
    });
    expect(c.latitude, 32.9);
    expect(c.locationStatus, 'verified');
    expect(c.rounds, 5);
    expect(c.gymCity, 'San Diego');
    final d = CheckIn.fromJson({'id': 'c2', 'openMatId': 'o', 'userId': 'u', 'sessionDate': 'd', 'checkedInAt': 't'});
    expect(d.locationStatus, 'no_location'); // default
    expect(d.rounds, isNull);
  });
}
```

- [ ] **Step 2: Run it** — `cd apps/mobile && flutter test test/models/checkin_test.dart` — expect FAIL.

- [ ] **Step 3: Add fields to `CheckIn`** in `models/checkin.dart` — add finals + constructor params + `fromJson` mappings:
```dart
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final String locationStatus;
  final double? distanceM;
  final String? gymId;
  final String? gymCity;
  final String? gymState;
  final String? note;
  final int? rounds;
  final int? intensity;
  final int? partners;
```
Constructor: add `this.latitude, this.longitude, this.gpsAccuracyM, this.locationStatus = 'no_location', this.distanceM, this.gymId, this.gymCity, this.gymState, this.note, this.rounds, this.intensity, this.partners,`. In `fromJson`:
```dart
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsAccuracyM: (json['gpsAccuracyM'] as num?)?.toDouble(),
      locationStatus: json['locationStatus'] as String? ?? 'no_location',
      distanceM: (json['distanceM'] as num?)?.toDouble(),
      gymId: json['gymId'] as String?,
      gymCity: json['gymCity'] as String?,
      gymState: json['gymState'] as String?,
      note: json['note'] as String?,
      rounds: json['rounds'] as int?,
      intensity: json['intensity'] as int?,
      partners: json['partners'] as int?,
```

- [ ] **Step 4: Create the request DTO** `apps/mobile/lib/features/checkins/data/check_in_request.dart`
```dart
class CreateCheckInRequest {
  final String sessionDate;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final String? note;
  final String? beltRank;
  final int? rounds;
  final int? intensity;
  final int? partners;

  const CreateCheckInRequest({
    required this.sessionDate,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.note,
    this.beltRank,
    this.rounds,
    this.intensity,
    this.partners,
  });

  Map<String, dynamic> toJson() => {
        'sessionDate': sessionDate,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (gpsAccuracyM != null) 'gpsAccuracyM': gpsAccuracyM,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (beltRank != null) 'beltRank': beltRank,
        if (rounds != null) 'rounds': rounds,
        if (intensity != null) 'intensity': intensity,
        if (partners != null) 'partners': partners,
      };
}
```

- [ ] **Step 5: Add `checkIn` + `sessionByIdProvider`** to `attendance_repository.dart`. Add to the abstract class and impl:
```dart
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req);
```
```dart
  @override
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req) async {
    try {
      final res = await _dio.post('/api/v1/open-mats/$openMatId/checkin', data: req.toJson());
      return CheckIn.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
```
Add the import `import 'check_in_request.dart';` and `import '../../../core/data/api_envelope.dart';` already present (it provides `unwrapData`). Then add a provider the form uses for its read-only header (reuses the open-mat session repo):
```dart
// at top: import '../../open_mats/data/session_repository.dart';
final sessionByIdProvider = FutureProvider.family<OpenMat, String>((ref, id) {
  return ref.read(sessionRepositoryProvider).getById(id);
});
```
(import `OpenMat` from `../../open_mats/models/open_mat.dart`. `SessionRepository.getById` already exists.)

- [ ] **Step 6: Run + analyze** — `cd apps/mobile && flutter test test/models/checkin_test.dart` (PASS) and `flutter analyze lib/features/checkins/models/checkin.dart lib/features/checkins/data/check_in_request.dart lib/features/checkins/data/attendance_repository.dart` (clean).

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/lib/features/checkins apps/mobile/test/models/checkin_test.dart
git commit -m "feat(mobile): check-in model fields, request DTO, repo checkIn"
```

### Task 6: Check-in form screen, route, detail wiring, success status

**Files:**
- Create: `apps/mobile/lib/features/checkins/screens/check_in_form_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart`, `apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart`, `apps/mobile/lib/features/checkins/screens/checkin_success_screen.dart`
- Test: `apps/mobile/test/features/check_in_form_test.dart` (new)

- [ ] **Step 1: Write the failing widget test** `apps/mobile/test/features/check_in_form_test.dart` — override the location service, the session-by-id provider, and capture the repo request via a fake.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';
import 'package:bjj_open_mat/features/checkins/data/check_in_request.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';
import 'package:bjj_open_mat/features/checkins/screens/check_in_form_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

class _FakeLoc implements LocationService {
  @override
  Future<CapturedLocation?> current() async => const CapturedLocation(latitude: 32.9, longitude: -117.2, accuracyM: 7);
}

class _FakeAttendance implements AttendanceRepository {
  CreateCheckInRequest? captured;
  @override
  Future<List<CheckIn>> forSession(String openMatId, {String? date}) async => [];
  @override
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req) async {
    captured = req;
    return CheckIn(id: 'c1', openMatId: openMatId, userId: 'u', sessionDate: req.sessionDate, checkedInAt: 't', locationStatus: 'verified');
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('captures location, builds request, submits', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fakeRepo = _FakeAttendance();
    final mat = const OpenMat(id: 'om1', gymId: 'g1', title: 'Fri Night', startTime: '19:00', endTime: '21:00', gymName: 'Atos HQ');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLoc()),
        attendanceRepositoryProvider.overrideWithValue(fakeRepo),
        sessionByIdProvider('om1').overrideWith((ref) async => mat),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const CheckInFormScreen(openMatId: 'om1')),
    ));
    await tester.pump(const Duration(milliseconds: 400)); // location + session load

    expect(find.text('Atos HQ'), findsWidgets); // header rendered
    await tester.enterText(find.widgetWithText(TextField, 'How did it go?'), 'great rounds');
    await tester.tap(find.text('Check In'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeRepo.captured, isNotNull);
    expect(fakeRepo.captured!.latitude, 32.9);
    expect(fakeRepo.captured!.note, 'great rounds');
  });
}
```
(Adjust the `OpenMat(...)` literal to the real constructor; `CheckInFormScreen({required this.openMatId})`.)

- [ ] **Step 2: Run it** — `cd apps/mobile && flutter test test/features/check_in_form_test.dart` — expect FAIL (screen does not exist).

- [ ] **Step 3: Create `check_in_form_screen.dart`** — a `ConsumerStatefulWidget` that captures location in `initState`, reads the session via `sessionByIdProvider`, renders the form, and submits. Follow the create-session screen's styling conventions (`AppTokens`, pill/section helpers). Minimum viable structure:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../data/attendance_repository.dart';
import '../data/check_in_request.dart';

class CheckInFormScreen extends ConsumerStatefulWidget {
  final String openMatId;
  const CheckInFormScreen({super.key, required this.openMatId});

  @override
  ConsumerState<CheckInFormScreen> createState() => _CheckInFormScreenState();
}

class _CheckInFormScreenState extends ConsumerState<CheckInFormScreen> {
  CapturedLocation? _loc;
  bool _locResolved = false;
  bool _saving = false;
  String? _error;
  int _intensity = 3;
  final _noteCtrl = TextEditingController();
  final _roundsCtrl = TextEditingController();
  final _partnersCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final loc = await ref.read(locationServiceProvider).current();
      if (mounted) setState(() { _loc = loc; _locResolved = true; });
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _roundsCtrl.dispose();
    _partnersCtrl.dispose();
    super.dispose();
  }

  String _todayIso() => DateTime.now().toIso8601String().split('T').first;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ref.read(attendanceRepositoryProvider).checkIn(
            widget.openMatId,
            CreateCheckInRequest(
              sessionDate: _todayIso(),
              latitude: _loc?.latitude,
              longitude: _loc?.longitude,
              gpsAccuracyM: _loc?.accuracyM,
              note: _noteCtrl.text.trim(),
              rounds: int.tryParse(_roundsCtrl.text.trim()),
              intensity: _intensity,
              partners: int.tryParse(_partnersCtrl.text.trim()),
            ),
          );
      if (mounted) context.go('/open-mat/${widget.openMatId}/checkin-success?loc=${res.locationStatus}');
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final matAsync = ref.watch(sessionByIdProvider(widget.openMatId));
    final gymName = matAsync.asData?.value.gymName ?? matAsync.asData?.value.title ?? 'Open Mat';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Check In'), backgroundColor: t.bg, foregroundColor: t.text),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Text(gymName, style: t.h1Style.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(_loc != null ? Icons.location_on : Icons.location_off, size: 16, color: _loc != null ? t.green : t.muted),
            const SizedBox(width: 6),
            Text(
              !_locResolved ? 'Getting your location…' : _loc != null ? 'Location captured' : 'Location off — checking in without it',
              style: t.miniStyle,
            ),
          ]),
          const SizedBox(height: 18),
          _label(t, 'NOTES'),
          TextField(controller: _noteCtrl, maxLines: 3, decoration: _dec(t, 'How did it go?')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(t, 'ROUNDS'), TextField(controller: _roundsCtrl, keyboardType: TextInputType.number, decoration: _dec(t, 'e.g. 5'))])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(t, 'PARTNERS'), TextField(controller: _partnersCtrl, keyboardType: TextInputType.number, decoration: _dec(t, 'e.g. 3'))])),
          ]),
          const SizedBox(height: 14),
          _label(t, 'INTENSITY'),
          Row(children: List.generate(5, (i) {
            final v = i + 1;
            final on = _intensity == v;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _intensity = v),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: on ? t.primary.withValues(alpha: 0.14) : t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? t.primary : t.border)),
                child: Text('$v', textAlign: TextAlign.center, style: t.bodyStyle.copyWith(color: on ? t.primary : t.body, fontWeight: FontWeight.w700)),
              ),
            ));
          })),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: t.miniStyle.copyWith(color: t.red))],
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _saving ? null : _submit,
            child: Container(
              height: 54, alignment: Alignment.center,
              decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(14)),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('Check In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(AppTokens t, String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: t.labelStyle));
  InputDecoration _dec(AppTokens t, String hint) => InputDecoration(hintText: hint, filled: true, fillColor: t.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)));
}
```
(If `AppTokens` lacks any token used here, substitute the nearest existing one — read `tokens.dart`. The submit `Check In` text must match the widget test's `find.text('Check In')`, and the note hint must match `'How did it go?'`.)

- [ ] **Step 4: Add the route** in `router.dart` — under the `open-mat/:id` `routes:` list (sibling of `checkin-success` and `review`), import `CheckInFormScreen` and add:
```dart
GoRoute(
  path: 'checkin',
  builder: (context, state) => CheckInFormScreen(openMatId: state.pathParameters['id']!),
),
```

- [ ] **Step 5: Wire the detail buttons** in `open_mat_detail_screen.dart` — both currently `() {}`. The widget has `final String? sessionId;`. Replace:
  - Sport (line ~115): `onTap: () => context.go('/open-mat/$sessionId/checkin'),`
  - Glass (line ~236): `onPressed: () => context.go('/open-mat/$sessionId/checkin'),`
  Ensure `go_router` is imported (it is — the screen already uses `Navigator`; add `import 'package:go_router/go_router.dart';` if missing).

- [ ] **Step 6: Show the location status on success** — `checkin_success_screen.dart` route reads a `loc` query param. In `router.dart` the `checkin-success` GoRoute builder, pass it:
```dart
GoRoute(
  path: 'checkin-success',
  builder: (context, state) => CheckinSuccessScreen(openMatId: state.pathParameters['id']!, locationStatus: state.uri.queryParameters['loc']),
),
```
In `checkin_success_screen.dart`, add `final String? locationStatus;` to the widget + constructor, and render a line under the subtitle:
```dart
if (widget.locationStatus != null) ...[
  const SizedBox(height: StitchTokens.sm),
  Text(
    widget.locationStatus == 'verified' ? '📍 Location verified' : widget.locationStatus == 'far' ? '📍 Far from the gym' : '📍 Location off',
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
  ),
],
```

- [ ] **Step 7: Run + analyze** — `cd apps/mobile && flutter test test/features/check_in_form_test.dart` (PASS) and `flutter analyze lib/features/checkins lib/app/router.dart lib/features/open_mats/screens/open_mat_detail_screen.dart` (clean).

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/checkins apps/mobile/lib/app/router.dart apps/mobile/lib/features/open_mats/screens/open_mat_detail_screen.dart apps/mobile/test/features/check_in_form_test.dart
git commit -m "feat(mobile): open-mat check-in form with GPS capture, wired to detail button"
```

### Task 7: Emulator E2E (optional verification)

**Files:**
- Create: `apps/mobile/integration_test/check_in_test.dart`
- Modify: root `package.json` (add `mobile:e2e:checkin`)

- [ ] **Step 1: Write the E2E** mirroring `community_submission_test.dart`'s `pumpUntilFound` helper. Flow: login → open the first open-mat detail (tap a card on home) → tap **Check In** → on the form tap **Check In** → expect the success screen ("You're checked in!"). Geolocator on the emulator may return no fix; that's fine (the form proceeds without GPS). Keep assertions to reaching the success screen.

```dart
// after login 'Find your roll':
await tester.tap(find.text('Atos HQ').first); // open a detail
expect(await pumpUntilFound(tester, find.textContaining('Check In')), isTrue);
await tester.tap(find.textContaining('Check In').first);
expect(await pumpUntilFound(tester, find.text('Check In')), isTrue); // form submit button
await tester.tap(find.text('Check In'));
expect(await pumpUntilFound(tester, find.text("You're checked in!")), isTrue);
```
(Refine finders to disambiguate the detail "Check In" button from the form's, e.g. using `find.widgetWithText` on the specific button types if needed.)

- [ ] **Step 2: Add script** to root `package.json`:
```json
"mobile:e2e:checkin": "cd apps/mobile && flutter test integration_test/check_in_test.dart -d emulator-5554 --dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=dev-bypass-local-secret --dart-define=API_BASE_URL=http://10.0.2.2:3100",
```

- [ ] **Step 3: Run** (API + Mongo + emulator up): `bun run mobile:e2e:checkin` — expect `All tests passed!`. (If the detail "Check In" vs form "Check In" finders collide, disambiguate per Step 1's note before considering done.)

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/integration_test/check_in_test.dart package.json
git commit -m "test(mobile): e2e check-in flow from detail to success"
```

---

## Self-review notes

- Spec coverage: location-status enum + CheckIn fields + CreateCheckInRequest (Task 1); haversine + snapshot + flag + facade DI (Task 2); container wiring + route (Task 3); LocationService (Task 4); mobile model/DTO/repo (Task 5); form screen + route + detail wiring + success status (Task 6); E2E (Task 7). All spec sections mapped.
- The existing `check-in.facade.test.mts` review tests call `new CheckInFacade(r, () => "c-x", () => now)` (3 args); Task 2 Step 1 updates them to the 5-arg form with `openMats()`/`users()` fakes — do this or the suite won't compile.
- `CheckInFacade` ctor order is `(checkins, openMats, users, newId, now?)` — consistent across Task 2 (facade + tests) and Task 3 (container `new CheckInFacade(checkInRepo, openMatRepo, userRepo, id)`).
- The form submit button label `Check In` and note hint `How did it go?` are asserted verbatim by the Task 6 widget test — keep them in sync if changed.
- `locationStatus` is optional in the contract (old one-tap check-in docs lack it) but always set by the facade; mobile defaults it to `'no_location'` on parse.
- Geolocator API specifics may vary by version — Task 4 Step 2 notes adapting to `pubspec.lock` while keeping the `LocationService`/`CapturedLocation` contract stable.
