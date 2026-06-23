# Flutter Owner Wiring (Slice 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Flutter gym-owner journey (login → dashboard → gyms → sessions → attendance) to the live API with real Auth0 auth, via a repository layer.

**Architecture:** Flutter screens → Riverpod providers → repository interface (`*Repository`) → single API implementation (`Api*Repository`) over the shared Dio client → the Elysia API. Real Auth0 web auth replaces the `DEV_MODE` fake; the API derives `role` from the Mongo user record. Small API changes accompany the app work.

**Tech Stack:** Flutter (Riverpod, go_router, dio, auth0_flutter, flutter_secure_storage), `http_mock_adapter` (dev, for repo tests). API: Bun + Elysia + TypeBox + MongoDB (existing).

**Spec:** `docs/superpowers/specs/2026-06-17-flutter-owner-wiring-design.md`

---

## Conventions for every task

- **Flutter:** `flutter analyze` must be clean after each task. Tests run with `flutter test` from `apps/mobile`. Match existing style (2-space indent, single quotes, trailing commas, `const` where possible).
- **API:** `.mts`, strict TS, no `any`, explicit return types. From `apps/api`: `bun test` + `bunx tsc --noEmit` + `bunx eslint src test` must pass.
- **Do NOT commit** unless the executor's policy allows it — git is user-governed in this repo. Each task ends by reporting changed files.
- MongoDB must be running for API tests (`docker compose up -d`).
- Run Flutter commands from `apps/mobile`; API commands from `apps/api`.

---

## File Structure Map

### API (`apps/api/src`, `packages/contract/src`)
```
packages/contract/src/schemas/requests/user-requests.mts   MODIFY: add optional role to UpdateUserRequest
apps/api/src/auth/auth.middleware.mts                       MODIFY: resolve role from DB user
apps/api/src/container.mts                                  MODIFY: pass userFacade to authPlugin
apps/api/src/facades/open-mat.facade.mts                    MODIFY: location optional on create
apps/api/test/boot.test.mts                                 MODIFY: role-from-DB + role update assertions
apps/api/.env                                               MODIFY: add AUTH0_DOMAIN/AUTH0_AUDIENCE (user-supplied)
```

### Flutter (`apps/mobile/lib`)
```
core/data/api_envelope.dart        NEW: unwrap {data} / {data,meta}
core/data/api_exception.dart       NEW: typed error from {error:{code,message}}
core/data/list_result.dart         NEW: items + meta holder
features/gyms/models/gym.dart                MODIFY: location {lat,lng}; add rating
features/open_mats/models/open_mat.dart      MODIFY: isGiSession -> giType; checkinCount -> attendeeCount
features/gyms/data/gym_requests.dart         NEW: CreateGymRequest/UpdateGymRequest DTOs
features/open_mats/data/session_requests.dart NEW: CreateSessionRequest/UpdateSessionRequest DTOs
features/gyms/data/gym_repository.dart        NEW: GymRepository + ApiGymRepository + provider
features/open_mats/data/session_repository.dart NEW: SessionRepository + ApiSessionRepository + provider
features/checkins/data/attendance_repository.dart NEW: AttendanceRepository + Api + provider
core/auth/auth_service.dart        MODIFY: real flow (no DEV_MODE), setRole, refresh
core/api/api_client.dart           MODIFY: real _refreshToken via Auth0
app/router.dart                    MODIFY: enable auth + role redirect guard
features/onboarding/screens/role_select_screen.dart  MODIFY: set role via API then navigate
features/admin/screens/my_gyms_screen.dart           MODIFY: use GymRepository.listMine()
features/admin/screens/session_mgmt_screen.dart      MODIFY: use SessionRepository.listMine()
features/admin/screens/owner_dashboard_screen.dart   MODIFY: counts from repos
features/admin/screens/add_gym_screen.dart           MODIFY: POST via GymRepository.create
features/admin/screens/gym_admin_screen.dart         MODIFY: GET+PUT via GymRepository
features/admin/screens/create_session_screen.dart    MODIFY: POST via SessionRepository.create
features/admin/screens/session_admin_screen.dart     MODIFY: GET+PUT via SessionRepository
features/admin/screens/attendance_screen.dart        MODIFY: use AttendanceRepository
test/... (repository + model tests)                  NEW
```

---

## PHASE A — API changes

### Task A1: Add optional `role` to UpdateUserRequest

**Files:**
- Modify: `packages/contract/src/schemas/requests/user-requests.mts`

- [ ] **Step 1: Edit the schema**

In `UpdateUserRequest`, add `role` (import `UserRole`):

```typescript
import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { UserRole } from "../../enums/user-role.mts";
import { UserSettings } from "../user.mts";

export const UpdateUserRequest = t.Partial(
  t.Object({
    displayName: t.String(),
    role: UserRole,
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    weight: t.String(),
    bio: t.String(),
    avatarUrl: t.String(),
    homeGymId: t.String(),
  }),
  { $id: "UpdateUserRequest" },
);
export type UpdateUserRequest = Static<typeof UpdateUserRequest>;

export const UpdateSettingsRequest = t.Partial(UserSettings, { $id: "UpdateSettingsRequest" });
export type UpdateSettingsRequest = Static<typeof UpdateSettingsRequest>;
```

- [ ] **Step 2: type-check contract**

Run (from `packages/contract`): `bun run type-check` → clean.

- [ ] **Step 3: Report changed files** (no commit).

### Task A2: Derive role from the DB user in the auth middleware

**Files:**
- Modify: `apps/api/src/auth/auth.middleware.mts`
- Modify: `apps/api/src/container.mts`
- Test: `apps/api/test/boot.test.mts`

**Context:** Currently `authPlugin(verifier)` resolves identity purely from the JWT (role from a token claim). Real Auth0 tokens won't carry `https://bjj/role`, so authorization must use the stored DB role. We pass the `UserFacade` into the plugin; after verifying the token it loads the user and overrides `role` with the DB value (falling back to the token/default when the user doesn't exist yet). The bypass path is unchanged.

- [ ] **Step 1: Add a failing boot-test assertion**

Append to `apps/api/test/boot.test.mts` inside the describe block — a test proving a non-owner DB user is rejected by an owner route even with a (bypass) token, after we set their role. Since the bypass token maps to the demo user (`u-me`, role `gym_owner` via env), instead assert the positive + the role-update path:

```typescript
  it("derives role from the DB and supports role update", async () => {
    // demo user starts as gym_owner (env DEMO_USER_ROLE); demote then verify owner route blocked
    const demote = await fetch(`${base}/api/v1/users/me`, {
      method: "PUT",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "practitioner" }),
    });
    expect(demote.status).toBe(200);
    expect((await demote.json()).data.role).toBe("practitioner");

    const blocked = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "X", address: "Y" }),
    });
    expect(blocked.status).toBe(403);

    // promote back to gym_owner
    const promote = await fetch(`${base}/api/v1/users/me`, {
      method: "PUT",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "gym_owner" }),
    });
    expect((await promote.json()).data.role).toBe("gym_owner");
  });
```

- [ ] **Step 2: Run, verify it fails**

Run (from `apps/api`): `bun test test/boot.test.mts`
Expected: FAIL — currently role comes from the bypass identity (always `gym_owner`), so the demoted POST returns 200 not 403.

- [ ] **Step 3: Update the auth plugin to load DB role**

Rewrite `apps/api/src/auth/auth.middleware.mts` so the plugin takes the verifier + a role resolver:

```typescript
import { Elysia } from "elysia";
import { AppError } from "../http/errors.mts";
import type { UserRole } from "@bjj/contract";
import type { AuthIdentity } from "./auth.types.mts";
import type { JwtVerifier } from "./jwt-verifier.mts";

function bearer(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const [scheme, value] = header.split(" ");
  return scheme === "Bearer" ? value : undefined;
}

// roleLookup returns the stored role for a userId, or null if the user doesn't exist yet.
export type RoleLookup = (userId: string) => Promise<UserRole | null>;

export function authPlugin(verifier: JwtVerifier, roleLookup: RoleLookup) {
  return new Elysia({ name: "auth" })
    .resolve(async ({ headers }): Promise<{ identity: AuthIdentity | null }> => {
      const token = bearer(headers["authorization"]);
      const verified = await verifier.verify(token);
      if (!verified) return { identity: null };
      const dbRole = await roleLookup(verified.userId);
      return { identity: { ...verified, role: dbRole ?? verified.role } };
    })
    .macro({
      requireAuth(enabled: boolean) {
        return {
          beforeHandle({ identity }: { identity: AuthIdentity | null }) {
            if (enabled && !identity) throw new AppError("unauthorized", "Authentication required");
          },
        };
      },
      requireOwner(enabled: boolean) {
        return {
          beforeHandle({ identity }: { identity: AuthIdentity | null }) {
            if (!enabled) return;
            if (!identity) throw new AppError("unauthorized", "Authentication required");
            if (identity.role !== "gym_owner") throw new AppError("forbidden", "Gym owner role required");
          },
        };
      },
    })
    .as("scoped");
}
```

- [ ] **Step 4: Pass the role lookup from the container**

In `apps/api/src/container.mts`, expose a `roleLookup` and update wherever `authPlugin` is constructed. Since route modules build the plugin from `container.verifier`, add a `roleLookup` to `Container` and update route modules to pass it. Add to the container:

```typescript
  // in Container interface:
  readonly roleLookup: (userId: string) => Promise<import("@bjj/contract").UserRole | null>;
```
and in `createContainer`, after `userRepo` is created:
```typescript
    roleLookup: async (userId) => {
      const user = await userRepo.findById(userId);
      return user ? user.role : null;
    },
```

- [ ] **Step 5: Update route modules to pass roleLookup**

Every route module that calls `authPlugin(container.verifier)` becomes `authPlugin(container.verifier, container.roleLookup)`. Files: `user.routes.mts`, `gym.routes.mts`, `open-mat.routes.mts`, `check-in.routes.mts`, `favorite.routes.mts`, `notification.routes.mts`. (Search for `authPlugin(` and update each call.)

- [ ] **Step 6: Run, verify pass**

Run (from `apps/api`): `bun test test/boot.test.mts` → PASS. Then full `bun test` → all pass. `bunx tsc --noEmit` → 0 errors. `bunx eslint src test` → clean.

- [ ] **Step 7: Report changed files** (no commit).

### Task A3: Make gym location optional for open-mat creation

**Files:**
- Modify: `apps/api/src/facades/open-mat.facade.mts`
- Test: `apps/api/test/open-mat.facade.test.mts`

**Context:** `OpenMatFacade.create` currently throws `bad_request` when the gym has no `location`. Owners can add gyms without coordinates, so creation must succeed without geo (the open mat just won't appear in `/nearby`).

- [ ] **Step 1: Add a failing test**

In `test/open-mat.facade.test.mts`, add a case: a gym with `location: undefined` still creates an open mat (no throw), with `latitude/longitude` omitted/zeroed and no geo. Adjust the existing fake gym to allow a location-less gym:

```typescript
  it("creates an open mat for a gym without a location", async () => {
    const d = deps();
    // override gymRepo to return a location-less gym
    const facade = new OpenMatFacade(
      d.matRepo,
      { findById: async () => ({ id: "g-1", ownerId: "owner-1", name: "Atos", address: "x", amenities: [], isVerified: true, city: "SD", state: "CA" }) },
      d.rsvpRepo,
      () => "om-2",
    );
    const created = await facade.create("owner-1", { gymId: "g-1", title: "Fri", startTime: "19:00", endTime: "21:00" });
    expect(created.id).toBe("om-2");
    expect(created.latitude).toBeUndefined();
  });
```

> Note: this requires `OpenMatDetail.latitude/longitude` to be optional. They are currently required in the contract. Update `open-mat-detail.mts` to make `latitude`/`longitude` optional (`t.Optional(t.Number())`) and `address`/`city`/`state` already required — keep address required (gym always has one), make city/state fall back to "". The repository's geo denormalization only runs when coordinates exist.

- [ ] **Step 2: Make detail geo optional in the contract**

In `packages/contract/src/schemas/open-mat-detail.mts`, change `latitude`/`longitude` to `t.Optional(t.Number())`.

- [ ] **Step 3: Run, verify fail** → `bun test test/open-mat.facade.test.mts` FAIL (throws bad_request).

- [ ] **Step 4: Update the facade**

In `OpenMatFacade.create`, remove the `if (!gym.location) throw ...` guard; set geo fields conditionally:

```typescript
    const detail: OpenMatDetail = {
      id: this.newId(),
      gymId: req.gymId,
      hostId: req.hostId,
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
    return this.mats.insert(detail);
```

- [ ] **Step 5: Guard the repository geo write**

In `apps/api/src/repositories/open-mat.repository.mts` `insert`, only set `geo` when both coords exist:

```typescript
  public async insert(detail: OpenMatDetail, gymOwnerId: string): Promise<OpenMatDetail> {
    const doc: OpenMatDoc = { ...detail, _id: detail.id, gymOwnerId };
    if (detail.latitude !== undefined && detail.longitude !== undefined) {
      doc.geo = { type: "Point", coordinates: [detail.longitude, detail.latitude] };
    }
    await this.collection<OpenMatDoc>(COLLECTIONS.openMats).insertOne(doc);
    return detail;
  }
```
(Make `geo` optional on `OpenMatDoc` if not already.)

- [ ] **Step 6: Run, verify pass** → `bun test` (full) PASS, `bunx tsc --noEmit` 0 errors, eslint clean.

- [ ] **Step 7: Report changed files** (no commit).

### Task A4: Set Auth0 env on the API

**Files:**
- Modify: `apps/api/.env` (local, gitignored)

- [ ] **Step 1:** Add the user-supplied values:
```
AUTH0_DOMAIN=<tenant>.us.auth0.com
AUTH0_AUDIENCE=<api-audience>
```
- [ ] **Step 2:** Restart the API; confirm `/health` 200 and that a request with the bypass token still works (bypass unaffected). Report.

---

## PHASE B — Flutter foundation (envelope, exception, models)

### Task B1: Envelope + ListResult + ApiException helpers

**Files:**
- Create: `apps/mobile/lib/core/data/api_envelope.dart`, `list_result.dart`, `api_exception.dart`
- Test: `apps/mobile/test/core/api_envelope_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/data/api_envelope.dart';
import 'package:bjj_open_mat/core/data/list_result.dart';

void main() {
  test('unwrapData returns the data object', () {
    expect(unwrapData({'data': {'id': 'x'}}), {'id': 'x'});
  });

  test('unwrapList returns items + meta', () {
    final r = unwrapList({'data': [{'id': 'x'}], 'meta': {'page': 1, 'limit': 20, 'total': 1}});
    expect(r.items.length, 1);
    expect(r.total, 1);
  });

  test('unwrapList tolerates a bare list under data', () {
    final r = unwrapList({'data': [{'id': 'x'}]});
    expect(r.items.length, 1);
    expect(r.total, 1);
  });
}
```

> Replace `bjj_open_mat` with the actual package name from `apps/mobile/pubspec.yaml` (`name:`). Use it consistently in all Dart test imports.

- [ ] **Step 2: Run, verify fail**

Run (from `apps/mobile`): `flutter test test/core/api_envelope_test.dart`
Expected: FAIL (files don't exist).

- [ ] **Step 3: Implement `list_result.dart`**

```dart
class ListResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;
  const ListResult({required this.items, required this.page, required this.limit, required this.total});
}
```

- [ ] **Step 4: Implement `api_envelope.dart`**

```dart
import 'list_result.dart';

/// Unwraps a single-item envelope: { "data": {...} }.
Map<String, dynamic> unwrapData(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is Map<String, dynamic>) return data;
  throw const FormatException('Expected an object under "data"');
}

/// Unwraps a list envelope: { "data": [...], "meta": {page,limit,total} }.
/// Tolerates a bare array under "data" (no meta).
ListResult<Map<String, dynamic>> unwrapList(Map<String, dynamic> body) {
  final raw = body['data'];
  final List list = raw is List ? raw : const [];
  final items = list.cast<Map<String, dynamic>>();
  final meta = body['meta'];
  if (meta is Map<String, dynamic>) {
    return ListResult(
      items: items,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? items.length,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }
  return ListResult(items: items, page: 1, limit: items.length, total: items.length);
}
```

- [ ] **Step 5: Implement `api_exception.dart`**

```dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  const ApiException({required this.code, required this.message, this.status});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: err['code']?.toString() ?? 'error',
        message: err['message']?.toString() ?? 'Request failed',
        status: e.response?.statusCode,
      );
    }
    return ApiException(code: 'network_error', message: e.message ?? 'Network error', status: e.response?.statusCode);
  }

  @override
  String toString() => message;
}
```

- [ ] **Step 6: Run, verify pass** → `flutter test test/core/api_envelope_test.dart` PASS. `flutter analyze` clean.

- [ ] **Step 7: Report changed files** (no commit).

### Task B2: Fix the OpenMat model (giType, attendeeCount)

**Files:**
- Modify: `apps/mobile/lib/features/open_mats/models/open_mat.dart`
- Test: `apps/mobile/test/models/open_mat_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

void main() {
  test('parses giType and attendeeCount', () {
    final om = OpenMat.fromJson({
      'id': 'om-1', 'gymId': 'g-1', 'title': 'Fri', 'startTime': '19:00', 'endTime': '21:00',
      'skillLevel': 'all', 'giType': 'nogi', 'attendeeCount': 3,
    });
    expect(om.giType, 'nogi');
    expect(om.attendeeCount, 3);
    expect(om.giBadge, 'No-Gi');
  });
}
```

- [ ] **Step 2: Run, verify fail** → FAIL (no `giType`).

- [ ] **Step 3: Edit the model**

Replace `isGiSession` with `giType`, `checkinCount` with `attendeeCount`, and update `giBadge`:

```dart
  final String giType; // gi | nogi | both
  // ...
  final int? attendeeCount;
```
Constructor: `this.giType = 'both',` and `this.attendeeCount,` (remove `isGiSession`, `checkinCount`).
`fromJson`:
```dart
      giType: json['giType'] as String? ?? 'both',
      attendeeCount: json['attendeeCount'] as int?,
```
`giBadge`:
```dart
  String get giBadge {
    switch (giType) {
      case 'gi': return 'Gi';
      case 'nogi': return 'No-Gi';
      default: return 'Gi & No-Gi';
    }
  }
```

- [ ] **Step 4: Fix references**

Run (from `apps/mobile`): `flutter analyze`. Fix any references to `isGiSession`/`checkinCount` it reports (e.g. in open-mat detail or session screens). Update each to `giType`/`attendeeCount`.

- [ ] **Step 5: Run, verify pass** → `flutter test test/models/open_mat_test.dart` PASS; `flutter analyze` clean.

- [ ] **Step 6: Report changed files** (no commit).

### Task B3: Fix the Gym model (location {lat,lng} + rating)

**Files:**
- Modify: `apps/mobile/lib/features/gyms/models/gym.dart`
- Test: `apps/mobile/test/models/gym_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';

void main() {
  test('parses location as {lat,lng} and rating', () {
    final g = Gym.fromJson({
      'id': 'g-1', 'name': 'Atos', 'address': 'x',
      'location': {'lat': 32.9, 'lng': -117.2}, 'rating': 4.8,
    });
    expect(g.location?.lat, 32.9);
    expect(g.location?.lng, -117.2);
    expect(g.rating, 4.8);
  });
}
```

- [ ] **Step 2: Run, verify fail** → FAIL (current parser expects `coordinates`; `rating` absent).

- [ ] **Step 3: Edit the model**

Add `final double? rating;` (constructor param `this.rating,`). Replace the location parsing in `fromJson`:

```dart
    GeoLocation? loc;
    final rawLoc = json['location'];
    if (rawLoc is Map && rawLoc['lat'] != null && rawLoc['lng'] != null) {
      loc = GeoLocation(lat: (rawLoc['lat'] as num).toDouble(), lng: (rawLoc['lng'] as num).toDouble());
    }
```
and add `rating: (json['rating'] as num?)?.toDouble(),`.

- [ ] **Step 4: Run, verify pass** → `flutter test test/models/gym_test.dart` PASS; `flutter analyze` clean.

- [ ] **Step 5: Report changed files** (no commit).

---

## PHASE C — Repository layer

> Add the test-only dev dependency first.

### Task C1: Add `http_mock_adapter` dev dependency

**Files:**
- Modify: `apps/mobile/pubspec.yaml`

- [ ] **Step 1:** Under `dev_dependencies:` add `http_mock_adapter: ^0.6.1`.
- [ ] **Step 2:** Run (from `apps/mobile`): `flutter pub get` → resolves. Report.

### Task C2: Gym request DTOs

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/gym_requests.dart`

- [ ] **Step 1: Implement**

```dart
import '../models/gym.dart';

class CreateGymRequest {
  final String name;
  final String address;
  final String? description;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final GeoLocation? location;
  final String? phone;
  final String? website;
  final List<String> amenities;

  const CreateGymRequest({
    required this.name,
    required this.address,
    this.description,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.location,
    this.phone,
    this.website,
    this.amenities = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (country != null && country!.isNotEmpty) 'country': country,
        if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
        if (location != null) 'location': {'lat': location!.lat, 'lng': location!.lng},
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (website != null && website!.isNotEmpty) 'website': website,
        if (amenities.isNotEmpty) 'amenities': amenities,
      };
}

class UpdateGymRequest {
  final Map<String, dynamic> _fields;
  const UpdateGymRequest(this._fields);
  Map<String, dynamic> toJson() => _fields;
}
```

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task C3: Gym repository + provider

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/gym_repository.dart`
- Test: `apps/mobile/test/data/gym_repository_test.dart`

- [ ] **Step 1: Write the failing test** (uses `http_mock_adapter`)

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_requests.dart';
import 'package:bjj_open_mat/core/data/api_exception.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiGymRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    adapter = DioAdapter(dio: dio);
    repo = ApiGymRepository(dio);
  });

  test('listMine sends mine=true and parses the list envelope', () async {
    adapter.onGet('/api/v1/gyms', (s) => s.reply(200, {
      'data': [{'id': 'g-1', 'name': 'Atos', 'address': 'x'}],
      'meta': {'page': 1, 'limit': 20, 'total': 1},
    }), queryParameters: {'mine': true});
    final gyms = await repo.listMine();
    expect(gyms.single.id, 'g-1');
  });

  test('create posts the body and returns the gym', () async {
    adapter.onPost('/api/v1/gyms', (s) => s.reply(200, {'data': {'id': 'g-2', 'name': 'New', 'address': 'y'}}),
        data: {'name': 'New', 'address': 'y'});
    final gym = await repo.create(const CreateGymRequest(name: 'New', address: 'y'));
    expect(gym.id, 'g-2');
  });

  test('maps API error to ApiException', () async {
    adapter.onGet('/api/v1/gyms/missing', (s) => s.reply(404, {'error': {'code': 'not_found', 'message': 'nope'}}));
    expect(() => repo.getById('missing'), throwsA(isA<ApiException>()));
  });
}
```

- [ ] **Step 2: Run, verify fail** → `flutter test test/data/gym_repository_test.dart` FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym.dart';
import 'gym_requests.dart';

abstract class GymRepository {
  Future<List<Gym>> listMine();
  Future<Gym> getById(String id);
  Future<Gym> create(CreateGymRequest req);
  Future<Gym> update(String id, UpdateGymRequest req);
}

class ApiGymRepository implements GymRepository {
  final Dio _dio;
  ApiGymRepository(this._dio);

  @override
  Future<List<Gym>> listMine() async {
    try {
      final res = await _dio.get('/api/v1/gyms', queryParameters: {'mine': true});
      final result = unwrapList(res.data as Map<String, dynamic>);
      return result.items.map(Gym.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> getById(String id) async {
    try {
      final res = await _dio.get('/api/v1/gyms/$id');
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> create(CreateGymRequest req) async {
    try {
      final res = await _dio.post('/api/v1/gyms', data: req.toJson());
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> update(String id, UpdateGymRequest req) async {
    try {
      final res = await _dio.put('/api/v1/gyms/$id', data: req.toJson());
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return ApiGymRepository(ref.read(apiClientProvider).dio);
});
```

- [ ] **Step 4: Run, verify pass** → `flutter test test/data/gym_repository_test.dart` PASS; `flutter analyze` clean. Report.

### Task C4: Session request DTOs + repository + provider

**Files:**
- Create: `apps/mobile/lib/features/open_mats/data/session_requests.dart`, `session_repository.dart`
- Test: `apps/mobile/test/data/session_repository_test.dart`

- [ ] **Step 1: DTOs (`session_requests.dart`)**

```dart
class CreateSessionRequest {
  final String gymId;
  final String title;
  final String startTime; // HH:mm 24h
  final String endTime;   // HH:mm 24h
  final int? dayOfWeek;   // 0=Sun..6=Sat (recurring)
  final String? specificDate; // YYYY-MM-DD (one-off)
  final bool isRecurring;
  final String giType;    // gi|nogi|both
  final String skillLevel; // all|beginner|intermediate|advanced
  final int? feeCents;
  final int? maxParticipants;
  final String? description;

  const CreateSessionRequest({
    required this.gymId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.dayOfWeek,
    this.specificDate,
    this.isRecurring = true,
    this.giType = 'both',
    this.skillLevel = 'all',
    this.feeCents,
    this.maxParticipants,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'gymId': gymId,
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (specificDate != null) 'specificDate': specificDate,
        'isRecurring': isRecurring,
        'giType': giType,
        'skillLevel': skillLevel,
        if (feeCents != null) 'feeCents': feeCents,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

class UpdateSessionRequest {
  final Map<String, dynamic> _fields;
  const UpdateSessionRequest(this._fields);
  Map<String, dynamic> toJson() => _fields;
}
```

- [ ] **Step 2: Write the failing repo test**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/open_mats/data/session_repository.dart';
import 'package:bjj_open_mat/features/open_mats/data/session_requests.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSessionRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    adapter = DioAdapter(dio: dio);
    repo = ApiSessionRepository(dio);
  });

  test('listMine parses sessions', () async {
    adapter.onGet('/api/v1/open-mats', (s) => s.reply(200, {
      'data': [{'id': 'om-1', 'gymId': 'g-1', 'title': 'Fri', 'startTime': '19:00', 'endTime': '21:00', 'skillLevel': 'all', 'giType': 'gi'}],
      'meta': {'page': 1, 'limit': 20, 'total': 1},
    }), queryParameters: {'mine': true});
    final list = await repo.listMine();
    expect(list.single.giType, 'gi');
  });

  test('create posts the session body', () async {
    adapter.onPost('/api/v1/open-mats', (s) => s.reply(200, {'data': {'id': 'om-9', 'gymId': 'g-1', 'title': 'X', 'startTime': '19:00', 'endTime': '20:00', 'skillLevel': 'all', 'giType': 'both'}}),
        data: Matchers.any);
    final om = await repo.create(const CreateSessionRequest(gymId: 'g-1', title: 'X', startTime: '19:00', endTime: '20:00'));
    expect(om.id, 'om-9');
  });
}
```

- [ ] **Step 3: Run, verify fail** → FAIL.

- [ ] **Step 4: Implement `session_repository.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/open_mat.dart';
import 'session_requests.dart';

abstract class SessionRepository {
  Future<List<OpenMat>> listMine();
  Future<OpenMat> getById(String id);
  Future<OpenMat> create(CreateSessionRequest req);
  Future<OpenMat> update(String id, UpdateSessionRequest req);
}

class ApiSessionRepository implements SessionRepository {
  final Dio _dio;
  ApiSessionRepository(this._dio);

  @override
  Future<List<OpenMat>> listMine() async {
    try {
      final res = await _dio.get('/api/v1/open-mats', queryParameters: {'mine': true});
      return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> getById(String id) async {
    try {
      final res = await _dio.get('/api/v1/open-mats/$id');
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> create(CreateSessionRequest req) async {
    try {
      final res = await _dio.post('/api/v1/open-mats', data: req.toJson());
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> update(String id, UpdateSessionRequest req) async {
    try {
      final res = await _dio.put('/api/v1/open-mats/$id', data: req.toJson());
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return ApiSessionRepository(ref.read(apiClientProvider).dio);
});
```

- [ ] **Step 5: Run, verify pass** → PASS; `flutter analyze` clean. Report.

### Task C5: Attendance repository + provider

**Files:**
- Create: `apps/mobile/lib/features/checkins/data/attendance_repository.dart`
- Test: `apps/mobile/test/data/attendance_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';

void main() {
  test('forSession parses check-ins with date query', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    final adapter = DioAdapter(dio: dio);
    final repo = ApiAttendanceRepository(dio);
    adapter.onGet('/api/v1/open-mats/om-1/checkins', (s) => s.reply(200, {
      'data': [{'id': 'c-1', 'openMatId': 'om-1', 'userId': 'u-1', 'sessionDate': '2026-06-20', 'checkedInAt': '2026-06-20T19:00:00.000Z', 'userName': 'Sam', 'beltRank': 'blue'}],
      'meta': {'page': 1, 'limit': 1, 'total': 1},
    }), queryParameters: {'date': '2026-06-20'});
    final checkins = await repo.forSession('om-1', date: '2026-06-20');
    expect(checkins.single.userName, 'Sam');
  });
}
```

- [ ] **Step 2: Run, verify fail** → FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/checkin.dart';

abstract class AttendanceRepository {
  Future<List<CheckIn>> forSession(String openMatId, {String? date});
}

class ApiAttendanceRepository implements AttendanceRepository {
  final Dio _dio;
  ApiAttendanceRepository(this._dio);

  @override
  Future<List<CheckIn>> forSession(String openMatId, {String? date}) async {
    try {
      final res = await _dio.get('/api/v1/open-mats/$openMatId/checkins',
          queryParameters: {if (date != null) 'date': date});
      return unwrapList(res.data as Map<String, dynamic>).items.map(CheckIn.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return ApiAttendanceRepository(ref.read(apiClientProvider).dio);
});
```

- [ ] **Step 4: Run, verify pass** → PASS; `flutter analyze` clean. Report.

---

## PHASE D — Auth0 (real)

### Task D1: Real auth state + role update (remove DEV_MODE)

**Files:**
- Modify: `apps/mobile/lib/core/auth/auth_service.dart`

**Context:** `AuthStateNotifier.build()` currently hard-returns an authenticated dev user, and `checkAuth` has a `DEV_MODE` default-true bypass. `_socialLogin` + `AuthService.login` already do real Auth0 web auth. We make the app start unauthenticated, run a real session check, and add `setRole`.

- [ ] **Step 1: Edit `AuthStateNotifier`**

- Change `build()` to start unauthenticated and trigger a check:
```dart
  @override
  AuthState build() {
    _bootstrap();
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _bootstrap() async => checkAuth();
```
- Remove the `_devUser` constant and the entire `DEV_MODE` block in `checkAuth`, leaving only the real token path:
```dart
  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await _authService.getStoredToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      await _authService.applyStoredToken();
      final user = await _authService.getOrCreateProfile();
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
```
- Add `setRole`:
```dart
  Future<void> setRole(String role) async {
    final updated = await _authService.updateProfile({'role': role});
    if (updated != null) state = state.copyWith(user: updated);
  }
```

- [ ] **Step 2: Add `applyStoredToken` to `AuthService`**

```dart
  Future<void> applyStoredToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) await apiClient.setToken(token);
  }
```

- [ ] **Step 3:** `flutter analyze` clean (the app will now require login). Report.

### Task D2: Real token refresh in ApiClient

**Files:**
- Modify: `apps/mobile/lib/core/api/api_client.dart`

- [ ] **Step 1: Implement `_refreshToken` via Auth0 credentials manager**

Replace the stub:
```dart
  Future<bool> _refreshToken() async {
    try {
      final auth0 = Auth0(
        const String.fromEnvironment('AUTH0_DOMAIN'),
        const String.fromEnvironment('AUTH0_CLIENT_ID'),
      );
      final creds = await auth0.credentialsManager.credentials();
      await _storage.write(key: 'access_token', value: creds.accessToken);
      await setToken(creds.accessToken);
      return true;
    } catch (_) {
      return false;
    }
  }
```
Add the import `import 'package:auth0_flutter/auth0_flutter.dart';`.

> `credentialsManager.credentials()` auto-renews using the stored refresh token when the access token is expired. `login()` in `auth_service.dart` already stores credentials in secure storage; ensure the Auth0 credentials manager is also populated — `webAuthentication().login()` stores into the credentials manager automatically in `auth0_flutter`, so this works without extra wiring.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task D3: Wire role-select to set the role

**Files:**
- Modify: `apps/mobile/lib/features/onboarding/screens/role_select_screen.dart`

- [ ] **Step 1: Make it a ConsumerWidget action that sets role then navigates**

Change each `_RoleCard.onTap` to call `setRole` then route. Practitioner card:
```dart
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(authStateProvider.notifier).setRole('practitioner');
                  if (context.mounted) context.go('/profile-setup');
                },
```
Gym Owner card:
```dart
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(authStateProvider.notifier).setRole('gym_owner');
                  if (context.mounted) context.go('/owner/dashboard');
                },
```
(The widget already has `ref` via `ConsumerWidget`.)

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task D4: Enable the router auth + role guard

**Files:**
- Modify: `apps/mobile/lib/app/router.dart`

- [ ] **Step 1: Replace the redirect**

```dart
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      const authRoutes = {'/login', '/role-select', '/profile-setup', '/splash'};
      final loggingIn = authRoutes.contains(loc);

      if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }
      // authenticated
      final user = auth.user;
      if (user != null && (user.role.isEmpty)) {
        return loc == '/role-select' ? null : '/role-select';
      }
      final isOwner = user?.isGymOwner ?? false;
      if (!isOwner && loc.startsWith('/owner')) return '/';
      if (loggingIn) return isOwner ? '/owner/dashboard' : '/';
      return null;
    },
```

- [ ] **Step 2:** Ensure `/splash` exists (it does). `flutter analyze` clean. Report.

---

## PHASE E — Owner screens wiring

### Task E1: my_gyms → GymRepository.listMine()

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/my_gyms_screen.dart`

- [ ] **Step 1: Replace the inline provider** with one backed by the repository:

```dart
final myGymsProvider = FutureProvider<List<Gym>>((ref) async {
  return ref.read(gymRepositoryProvider).listMine();
});
```
Remove the old `apiClientProvider`/`endpoints` imports; add `import '../../gyms/data/gym_repository.dart';`. The rest of the widget (`.when`, ShimmerList, ErrorState, EmptyState) stays.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task E2: session_mgmt → SessionRepository.listMine()

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/session_mgmt_screen.dart`

- [ ] **Step 1: Read the current screen.** It currently fetches sessions inline (like my_gyms). Replace its inline provider with:
```dart
final mySessionsProvider = FutureProvider<List<OpenMat>>((ref) async {
  return ref.read(sessionRepositoryProvider).listMine();
});
```
Add `import '../../open_mats/data/session_repository.dart';` and `import '../../open_mats/models/open_mat.dart';`; remove direct api/endpoints imports. Keep the existing list/loading/error/empty UI; ensure any `isGiSession` references become `giType` and `checkinCount`→`attendeeCount`.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task E3: owner_dashboard → counts from repositories

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/owner_dashboard_screen.dart`

- [ ] **Step 1: Read the current screen.** Wherever it shows gym/session counts or stats from stub data, source them from the repositories:
```dart
final ownerStatsProvider = FutureProvider<({int gyms, int sessions})>((ref) async {
  final gyms = await ref.read(gymRepositoryProvider).listMine();
  final sessions = await ref.read(sessionRepositoryProvider).listMine();
  return (gyms: gyms.length, sessions: sessions.length);
});
```
Add the repository imports. Render via `.when` with the existing layout; keep any non-data UI as-is. Replace hardcoded counts with the provider values.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task E4: add_gym → POST via GymRepository.create

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/add_gym_screen.dart`

**Context:** The form currently just sets `_submitted = true`. Wire `_buildSubmitButton`'s tap to call the repository, show the success overlay on success, and surface errors. The form has no coordinates — send the gym without `location` (the API now allows it).

- [ ] **Step 1: Add a submit handler** to `_AddGymScreenState`:

```dart
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_valid || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(gymRepositoryProvider).create(CreateGymRequest(
        name: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        website: _siteCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        amenities: _amenities.toList(),
      ));
      ref.invalidate(myGymsProvider);
      if (mounted) setState(() { _saving = false; _submitted = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    }
  }
```
Add imports: `import '../../gyms/data/gym_repository.dart';`, `import '../../gyms/data/gym_requests.dart';`, `import '../../../core/data/api_exception.dart';`, and `import 'my_gyms_screen.dart';` (for `myGymsProvider`).

- [ ] **Step 2: Wire the button + error display**

In `_buildSubmitButton`, change `onTap: enabled ? () => setState(() => _submitted = true) : null` to `onTap: (enabled && !_saving) ? _submit : null`, and show a spinner label when `_saving`. Below the submit button (or under the form) render `if (_error != null) Text(_error!, style: ...)` using the theme's error/red token.

- [ ] **Step 3: Verify** `flutter analyze` clean; manually confirm against the running API that submitting creates a gym (appears in my_gyms). Report.

### Task E5: gym_admin → GET + PUT via GymRepository

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/gym_admin_screen.dart`

- [ ] **Step 1: Read the current screen.** Add a detail provider and an edit/save path:
```dart
final gymDetailProvider = FutureProvider.family<Gym, String>((ref, id) async {
  return ref.read(gymRepositoryProvider).getById(id);
});
```
Load with `ref.watch(gymDetailProvider(gymId))` via `.when`. For edits, on save call `ref.read(gymRepositoryProvider).update(gymId, UpdateGymRequest({...changedFields}))`, then `ref.invalidate(gymDetailProvider(gymId))` + `ref.invalidate(myGymsProvider)`. Map only the fields the screen edits. Surface `ApiException` errors. Keep existing layout.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task E6: create_session → POST via SessionRepository.create

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/create_session_screen.dart`

**Context:** Pure stub today. It collects `_giType` (gi/nogi/both — matches API), `_expLevel` (`all/beg/int/adv` — must map to API `all/beginner/intermediate/advanced`), `_selectedDate`, `_startTime`/`_endTime` (TimeOfDay — must format `HH:mm` 24h), `_isRecurring`, `_isFree`/`_feeCtrl`, `_capCtrl`, `_notesCtrl`. The "POSTING AS" gym is hardcoded — replace with a real gym picker sourced from the owner's gyms.

- [ ] **Step 1: Add helpers + gym selection state**

```dart
  String? _gymId;

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _expToSkill = {'all': 'all', 'beg': 'beginner', 'int': 'intermediate', 'adv': 'advanced'};

  String _title() {
    final gi = _giType == 'gi' ? 'Gi' : _giType == 'nogi' ? 'No-Gi' : 'Gi & No-Gi';
    return '$gi Open Mat';
  }
```

- [ ] **Step 2: Source gyms for the picker**

Watch `ref.watch(myGymsProvider)` (import `my_gyms_screen.dart`); populate the "POSTING AS" card from the result, defaulting `_gymId` to the first gym. If the owner has no gyms, disable submit and show "Add a gym first".

- [ ] **Step 3: Add the submit handler**

```dart
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_gymId == null || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final fee = _isFree ? 0 : ((int.tryParse(_feeCtrl.text.trim()) ?? 0) * 100);
      await ref.read(sessionRepositoryProvider).create(CreateSessionRequest(
        gymId: _gymId!,
        title: _title(),
        startTime: _hhmm(_startTime),
        endTime: _hhmm(_endTime),
        isRecurring: _isRecurring,
        dayOfWeek: _isRecurring ? _selectedDate.weekday % 7 : null,
        specificDate: _isRecurring ? null : _selectedDate.toIso8601String().split('T').first,
        giType: _giType,
        skillLevel: _expToSkill[_expLevel] ?? 'all',
        feeCents: fee,
        maxParticipants: int.tryParse(_capCtrl.text.trim()),
        description: _notesCtrl.text.trim(),
      ));
      ref.invalidate(mySessionsProvider);
      if (mounted) setState(() { _saving = false; _submitted = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    }
  }
```
Imports: `session_repository.dart`, `session_requests.dart`, `core/data/api_exception.dart`, `session_mgmt_screen.dart` (for `mySessionsProvider`), `my_gyms_screen.dart`.

> `DateTime.weekday` is 1=Mon..7=Sun; the API uses 0=Sun..6=Sat. `_selectedDate.weekday % 7` maps Sun(7)→0, Mon(1)→1, … Sat(6)→6. Correct.

- [ ] **Step 4: Wire the button** — change `_buildSubmitButton`'s `onTap` to `(_gymId != null && !_saving) ? _submit : null`; show spinner when `_saving`; render `_error` if set.

- [ ] **Step 5: Verify** `flutter analyze` clean; manually create a session against the API and confirm it appears in session_mgmt. Report.

### Task E7: session_admin → GET + PUT via SessionRepository

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/session_admin_screen.dart`

- [ ] **Step 1: Read the current screen.** Add:
```dart
final sessionDetailProvider = FutureProvider.family<OpenMat, String>((ref, id) async {
  return ref.read(sessionRepositoryProvider).getById(id);
});
```
Load via `.when`; for edits (e.g. cancel/toggle, time changes) call `update(id, UpdateSessionRequest({...}))`, then invalidate `sessionDetailProvider(id)` + `mySessionsProvider`. A common owner action is cancel: `UpdateSessionRequest({'isCancelled': true})`. Map only edited fields; surface `ApiException`. Keep layout.

- [ ] **Step 2:** `flutter analyze` clean. Report.

### Task E8: attendance → AttendanceRepository

**Files:**
- Modify: `apps/mobile/lib/features/admin/screens/attendance_screen.dart`

- [ ] **Step 1: Replace the inline provider**

```dart
final attendanceProvider = FutureProvider.family<List<CheckIn>, AttendanceQuery>((ref, query) async {
  return ref.read(attendanceRepositoryProvider).forSession(query.sessionId, date: query.date);
});
```
Add `import '../../checkins/data/attendance_repository.dart';`; remove direct api/endpoints imports. Keep `AttendanceQuery`, the date picker, and the existing list/summary UI.

- [ ] **Step 2:** `flutter analyze` clean. Report.

---

## PHASE F — Verification

### Task F1: API suite green

- [ ] Run (from `apps/api`, Mongo up): `bun test` → all pass; `bunx tsc --noEmit` → 0 errors; `bunx eslint src test` → clean. Report results.

### Task F2: Flutter checks green

- [ ] Run (from `apps/mobile`): `flutter analyze` → no issues; `flutter test` → all pass. Report results.

### Task F3: Manual owner E2E (with user-supplied Auth0 config + running API)

- [ ] Launch the app with the Auth0 + API dart-defines:
```
flutter run --dart-define=AUTH0_DOMAIN=<d> --dart-define=AUTH0_CLIENT_ID=<c> --dart-define=API_BASE_URL=http://localhost:3100
```
- [ ] Verify: login via Auth0 → (first time) role-select → pick Gym Owner → owner dashboard → create a gym (appears in My Gyms) → create a session for it (appears in Sessions) → open attendance for a date. Confirm 401s trigger a silent refresh rather than a logout loop. Report outcome (this step needs the user's Auth0 tenant; if unavailable, report as a blocker with everything else green).

---

## Self-Review (completed during authoring)

- **Spec coverage:** Auth0 real + refresh (D1–D2, E-none), route guard (D4), role source = DB (A2), `role` in UpdateUserRequest (A1), role-select sets role (D3), repository pattern api-only (C2–C5), model alignment Gym/OpenMat/CheckIn (B2–B3; CheckIn already matches — no task needed), all owner screens (E1–E8), API env (A4), location-optional gap (A3, discovered during screen reads). Testing (B/C tests, F). All spec sections map to tasks.
- **Placeholder scan:** No TBDs. Screen tasks I had full source for (my_gyms, attendance, add_gym, create_session) carry exact code; tasks for screens not fully read (session_mgmt, owner_dashboard, gym_admin, session_admin) instruct "read the current screen" and give the exact provider/repository code + integration points — concrete, not vague.
- **Type/name consistency:** providers (`myGymsProvider`, `mySessionsProvider`, `attendanceProvider`, `gymDetailProvider`, `sessionDetailProvider`, `ownerStatsProvider`), repository providers (`gymRepositoryProvider`, `sessionRepositoryProvider`, `attendanceRepositoryProvider`), DTOs (`CreateGymRequest`/`UpdateGymRequest`/`CreateSessionRequest`/`UpdateSessionRequest`), and method names (`listMine`/`getById`/`create`/`update`/`forSession`) are consistent across tasks. `setRole` defined in D1, used in D3.

## Notes for implementers

- Replace `bjj_open_mat` in Dart test imports with the real package name from `apps/mobile/pubspec.yaml`.
- The screens not fully reproduced here (session_mgmt, owner_dashboard, gym_admin, session_admin) are styled stubs/partials — read each, then apply the specified provider/repository wiring without altering layout.
- API tasks (Phase A) should land before Flutter Phase E manual testing, since they enable role-based access and location-less session creation.
