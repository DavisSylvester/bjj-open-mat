# Search GPS-First + Reverse Geocode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On load, the Search screen uses the device GPS for the initial results; a tappable chip shows the resolved "City, ST" (via a new server reverse-geocode endpoint); the "within" slider max goes 50 → 100 mi; the Home screen shows the same resolved location label.

**Architecture:** Add a `reverse(lat,lng)` method to the existing `ZipcodesGeocoder` (uses the package's `lookupByCoords`), expose the geocoder on the DI container, and serve it at `GET /api/v1/geo/reverse`. The Flutter side gets a thin `GeoRepository` + `ReverseGeocode` model; the Search screen auto-captures GPS in `initState` and renders the label chip; the Home greeting reuses the same lookup.

**Tech Stack:** Elysia/Bun, `zipcodes` npm, Bun test, Flutter/Dart, Riverpod, `dio`, `geolocator`.

---

### Task 1: Add `reverse()` to the geocoder

**Files:**
- Modify: `apps/api/src/types/zipcodes.d.ts`
- Modify: `apps/api/src/services/geocoder.mts`
- Test: `apps/api/test/geocoder-reverse.test.mts`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/geocoder-reverse.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { ZipcodesGeocoder } from "../src/services/geocoder.mts";

describe("ZipcodesGeocoder.reverse", () => {
  const geo = new ZipcodesGeocoder();

  it("resolves Austin, TX coordinates to state TX", () => {
    const r = geo.reverse(30.2672, -97.7431);
    expect(r).not.toBeNull();
    expect(r!.state).toBe("TX");
    expect(r!.city.length).toBeGreaterThan(0);
  });

  it("returns a value for valid coordinates", () => {
    const r = geo.reverse(34.0522, -118.2437); // Los Angeles
    expect(r!.state).toBe("CA");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/geocoder-reverse.test.mts`
Expected: FAIL — `geo.reverse` is not a function.

- [ ] **Step 3: Add the type declaration**

In `apps/api/src/types/zipcodes.d.ts`, add inside the `declare module 'zipcodes'` block (after the `random` declaration):

```typescript
  export function lookupByCoords(lat: number, lon: number): ZipRecord | null;
```

- [ ] **Step 4: Implement `reverse`**

In `apps/api/src/services/geocoder.mts`:

Change the import line to:

```typescript
import { lookup, lookupByCoords } from 'zipcodes';
```

Add to the `Geocoder` interface:

```typescript
  reverse(lat: number, lng: number): { city: string; state: string } | null;
```

Add the method to `ZipcodesGeocoder` (after `lookupZip`):

```typescript
  public reverse(lat: number, lng: number): { city: string; state: string } | null {
    const rec = lookupByCoords(lat, lng);
    if (!rec || !rec.city || !rec.state) return null;
    return { city: rec.city, state: rec.state };
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/geocoder-reverse.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/services/geocoder.mts apps/api/src/types/zipcodes.d.ts apps/api/test/geocoder-reverse.test.mts
git commit -m "feat(api): add reverse geocode to ZipcodesGeocoder"
```

---

### Task 2: Expose the geocoder on the container

**Files:**
- Modify: `apps/api/src/container.mts:11-30,43-59`

- [ ] **Step 1: Import the interface type**

At the top of `container.mts`, change the geocoder import to also import the type:

```typescript
import { ZipcodesGeocoder, type Geocoder } from "./services/geocoder.mts";
```

- [ ] **Step 2: Add to the `Container` interface**

Add to the `Container` interface (after `readonly notificationFacade: NotificationFacade;`):

```typescript
  readonly geocoder: Geocoder;
```

- [ ] **Step 3: Add to the returned object**

In the returned object literal, add after `notificationFacade: new NotificationFacade(notificationRepo, id),`:

```typescript
    geocoder,
```

- [ ] **Step 4: Type-check**

Run: `cd apps/api && bun run type-check`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/container.mts
git commit -m "chore(api): expose geocoder on the container"
```

---

### Task 3: Add the reverse-geocode route

**Files:**
- Create: `apps/api/src/routes/geo.routes.mts`
- Modify: `apps/api/src/app.mts:12-13,29-37`
- Test: `apps/api/test/geo-route.test.mts`

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/geo-route.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { geoRoutes } from "../src/routes/geo.routes.mts";
import { ZipcodesGeocoder } from "../src/services/geocoder.mts";

describe("GET /api/v1/geo/reverse", () => {
  const app = new Elysia().use(
    geoRoutes({ geocoder: new ZipcodesGeocoder() } as never),
  );

  it("returns a city/state label for coordinates", async () => {
    const res = await app.handle(
      new Request("http://localhost/api/v1/geo/reverse?lat=30.2672&lng=-97.7431"),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: { state: string; label: string } };
    expect(body.data.state).toBe("TX");
    expect(body.data.label).toContain("TX");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/geo-route.test.mts`
Expected: FAIL — module `geo.routes.mts` not found.

- [ ] **Step 3: Create the route**

Create `apps/api/src/routes/geo.routes.mts`:

```typescript
import { Elysia, t } from "elysia";
import type { Container } from "../container.mts";
import { data } from "../http/envelope.mts";

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function geoRoutes(container: Container) {
  const { geocoder } = container;

  return new Elysia({ prefix: "/api/v1/geo" }).get(
    "/reverse",
    ({ query }) => {
      const r = geocoder.reverse(query.lat, query.lng);
      if (!r) return data({ city: "", state: "", label: "" });
      return data({ city: r.city, state: r.state, label: `${r.city}, ${r.state}` });
    },
    { query: t.Object({ lat: t.Number(), lng: t.Number() }) },
  );
}
```

- [ ] **Step 4: Register in `app.mts`**

Add the import (after the `favoriteRoutes` import):

```typescript
import { geoRoutes } from "./routes/geo.routes.mts";
```

Add to the `.use(...)` chain (after `.use(favoriteRoutes(container))`):

```typescript
    .use(geoRoutes(container))
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/geo-route.test.mts`
Expected: PASS (1 test).

- [ ] **Step 6: Boot-check the app still assembles**

Run: `cd apps/api && bun test test/boot.test.mts`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/api/src/routes/geo.routes.mts apps/api/src/app.mts apps/api/test/geo-route.test.mts
git commit -m "feat(api): add GET /api/v1/geo/reverse endpoint"
```

---

### Task 4: Add the reverse-geocode endpoint + model + repository (mobile)

**Files:**
- Modify: `apps/mobile/lib/core/api/endpoints.dart:34-35`
- Create: `apps/mobile/lib/core/location/geo_repository.dart`
- Test: `apps/mobile/test/reverse_geocode_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/reverse_geocode_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/location/geo_repository.dart';

void main() {
  test('ReverseGeocode.fromJson parses city/state/label', () {
    final r = ReverseGeocode.fromJson({'city': 'Austin', 'state': 'TX', 'label': 'Austin, TX'});
    expect(r.city, 'Austin');
    expect(r.state, 'TX');
    expect(r.label, 'Austin, TX');
  });

  test('empty label falls back to blank', () {
    final r = ReverseGeocode.fromJson({'city': '', 'state': '', 'label': ''});
    expect(r.label, '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/reverse_geocode_model_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Add the endpoint constant**

In `apps/mobile/lib/core/api/endpoints.dart`, add before the `// Health` comment:

```dart
  // Geo
  static const String geoReverse = '/api/v1/geo/reverse';
```

- [ ] **Step 4: Create the repository + model**

Create `apps/mobile/lib/core/location/geo_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

class ReverseGeocode {
  final String city;
  final String state;
  final String label;
  const ReverseGeocode({required this.city, required this.state, required this.label});

  factory ReverseGeocode.fromJson(Map<String, dynamic> json) => ReverseGeocode(
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class GeoRepository {
  final ApiClient _api;
  GeoRepository(this._api);

  /// Returns a "City, ST" label for the given coordinates, or null on failure.
  Future<ReverseGeocode?> reverse(double lat, double lng) async {
    try {
      final res = await _api.get(Endpoints.geoReverse, queryParameters: {'lat': lat, 'lng': lng});
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final rg = ReverseGeocode.fromJson(data);
      return rg.label.isEmpty ? null : rg;
    } catch (_) {
      return null;
    }
  }
}

final geoRepositoryProvider = Provider<GeoRepository>((ref) => GeoRepository(ref.read(apiClientProvider)));
```

> Confirm `ApiClient.get` accepts `queryParameters` (it wraps `dio.get`); the pattern matches `nearbyGymsProvider` in `discover_provider.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/reverse_geocode_model_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/core/api/endpoints.dart apps/mobile/lib/core/location/geo_repository.dart apps/mobile/test/reverse_geocode_model_test.dart
git commit -m "feat(mobile): reverse-geocode endpoint, model, repository"
```

---

### Task 5: Search screen — GPS on load, city chip, 100 mi max

**Files:**
- Modify: `apps/mobile/lib/features/search/screens/search_screen.dart`

- [ ] **Step 1: Add the import + state**

At the top add:

```dart
import '../../../core/location/geo_repository.dart';
```

In `_SearchScreenState`, add after `double? _gpsLng;`:

```dart
  String? _locationLabel;
```

- [ ] **Step 2: Auto-capture GPS on load**

Add an `initState` override to `_SearchScreenState` (before `dispose`):

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
  }
```

- [ ] **Step 3: Extend `_useGps` to reverse-geocode**

Replace the existing `_useGps` method body with:

```dart
  Future<void> _useGps() async {
    _debounce?.cancel();
    final loc = await ref.read(locationServiceProvider).current();
    if (loc == null) return;
    _gpsLat = loc.latitude;
    _gpsLng = loc.longitude;
    _zipCtrl.clear();
    _rebuildQuery();
    final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
    if (mounted && rg != null) setState(() => _locationLabel = rg.label);
  }
```

- [ ] **Step 4: Show the label on the GPS chip (Glass build)**

In `_buildGlass`, in the GPS `GestureDetector`'s inner `Row`, replace the `Text('GPS', ...)` with:

```dart
                        Text(_locationLabel ?? 'GPS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 10)),
```

- [ ] **Step 5: Show the label on the GPS chip (Sport build)**

In `_buildSport`, in the GPS `GestureDetector`'s inner `Row`, replace the `Text('GPS', ...)` with:

```dart
                        Text(_locationLabel ?? 'GPS', style: t.miniStyle.copyWith(color: t.red, fontSize: 10)),
```

- [ ] **Step 6: Raise both sliders to 100 mi**

In `_buildSport` and `_buildGlass`, change each `Slider(... max: 50 ...)` to `max: 100`. There are two occurrences (one per build method).

Run: `grep -n "max: 50" apps/mobile/lib/features/search/screens/search_screen.dart`
Expected after edit: no matches. Then `grep -n "max: 100" ...` → 2 matches.

- [ ] **Step 7: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/search/screens/search_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/search/screens/search_screen.dart
git commit -m "feat(mobile): search GPS-first with city chip and 100mi max"
```

---

### Task 6: Home screen — show resolved city label

**Files:**
- Modify: `apps/mobile/lib/features/discover/screens/discover_screen.dart`

- [ ] **Step 1: Add the import + state**

At the top add:

```dart
import '../../../core/location/geo_repository.dart';
```

In `_DiscoverScreenState`, add after `NearbyQuery _query = const NearbyQuery();`:

```dart
  String? _locationLabel;
```

- [ ] **Step 2: Reverse-geocode after capturing location**

Replace `_captureLocation` with:

```dart
  Future<void> _captureLocation() async {
    final loc = await ref.read(locationServiceProvider).current();
    if (!mounted || loc == null) return;
    setState(() {
      _query = NearbyQuery(lat: loc.latitude, lng: loc.longitude);
    });
    final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
    if (mounted && rg != null) setState(() => _locationLabel = rg.label);
  }
```

- [ ] **Step 3: Show it in the Glass greeting**

In `_buildGlass`, replace the greeting `Text('Good evening', ...)` line with:

```dart
                        Text(_locationLabel ?? 'Near you', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
```

- [ ] **Step 4: Show it in the Sport header**

In `_buildSport`, the header `Row` shows `Text('Open Mat', ...)`. Immediately after that `Text`, add:

```dart
              const SizedBox(width: 8),
              if (_locationLabel != null)
                Text(_locationLabel!, style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
```

- [ ] **Step 5: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/discover/screens/discover_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/discover/screens/discover_screen.dart
git commit -m "feat(mobile): show resolved city label on home screen"
```

---

## Self-Review notes
- Spec sections B + C covered: geocoder reverse (T1), container (T2), route (T3), mobile model/repo (T4), search GPS-first + chip + 100mi (T5), home label (T6).
- Consistent API: `geocoder.reverse(lat,lng)` → `{city,state}`; route returns `{city,state,label}`; Dart `ReverseGeocode{city,state,label}`; `GeoRepository.reverse` → `ReverseGeocode?`.
- ZIP/text precedence in `_rebuildQuery` is unchanged, so typing a ZIP/city still overrides GPS.
- Reverse geocode is best-effort: failures leave the chip showing "GPS" / "Near you" and search still works.
