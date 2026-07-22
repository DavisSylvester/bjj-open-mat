# Gyms Near You (within 50 miles) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the Discover screen, always show a "Gyms near you" section listing any gym within 50 miles, with each card showing distance, rating, a tappable address (→ maps) and website (→ browser), and no "Next: <date>" line.

**Architecture:** Add pure website-URL helpers + a launcher; add a `NearbyGymCard` (ConsumerWidget) that takes a full `Gym`; restructure the Discover feed into a single scroll that renders the open-mats list plus a nearby-gyms section sourced from the existing `nearbyGymsProvider` at `radiusKm: 80` (≈50 mi). Search screen and the existing `GymCard`/`GymSummary` are untouched.

**Tech Stack:** Flutter, Riverpod, go_router, `url_launcher`, `lucide_icons`. Spec: `docs/superpowers/specs/2026-07-21-gyms-near-you-50mi-design.md`.

**Working directory for all commands:** `C:/projects/davisSylvester/bjj-open-mat/apps/mobile`

---

## File Structure

- **Create** `apps/mobile/lib/features/gyms/data/website_links.dart` — pure helpers `websiteDisplayHost` / `normalizeWebsiteUrl` + `openWebsite` launcher (mirrors the existing `directions.dart`).
- **Create** `apps/mobile/lib/shared/widgets/nearby_gym_card.dart` — `NearbyGymCard` widget taking a `Gym`.
- **Modify** `apps/mobile/lib/features/discover/screens/discover_screen.dart` — restructure feed; add the nearby-gyms section.
- **Create** `apps/mobile/test/data/website_links_test.dart` — unit tests for the helpers.
- **Create** `apps/mobile/test/features/nearby_gym_card_test.dart` — widget tests for the card.
- **Modify** `apps/mobile/test/features/discover_screen_test.dart` — override `nearbyGymsProvider`; add a section test.

Reference (do not change):
- `apps/mobile/lib/features/gyms/data/directions.dart` — `openDirections(WidgetRef ref, BuildContext context, {String? gymId, String? address})`.
- `apps/mobile/lib/features/gyms/models/gym.dart` — `Gym` has `id`, `name`, `address`, `website`, `location`, `rating`, `distanceKm`.
- `apps/mobile/lib/features/discover/providers/discover_provider.dart` — `nearbyGymsProvider` + `NearbyQuery({lat, lng, radiusKm = 25})`.
- `apps/mobile/lib/core/location/location_controller.dart` — `locationControllerProvider` → `LocationState` with `hasCoords`, `lat`, `lng`.

---

## Task 1: Website URL helpers + launcher

**Files:**
- Create: `apps/mobile/lib/features/gyms/data/website_links.dart`
- Test: `apps/mobile/test/data/website_links_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/data/website_links_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/website_links.dart';

void main() {
  group('websiteDisplayHost', () {
    test('strips scheme and www and path', () {
      expect(websiteDisplayHost('https://www.rmelitebjj.com/schedule'), 'rmelitebjj.com');
    });
    test('leaves a bare host unchanged', () {
      expect(websiteDisplayHost('rmelitebjj.com'), 'rmelitebjj.com');
    });
    test('strips http scheme without www', () {
      expect(websiteDisplayHost('http://atosjj.com'), 'atosjj.com');
    });
  });

  group('normalizeWebsiteUrl', () {
    test('adds https:// when no scheme present', () {
      expect(normalizeWebsiteUrl('rmelitebjj.com'), 'https://rmelitebjj.com');
    });
    test('keeps an existing scheme', () {
      expect(normalizeWebsiteUrl('http://atosjj.com'), 'http://atosjj.com');
    });
    test('trims surrounding whitespace', () {
      expect(normalizeWebsiteUrl('  gym.com '), 'https://gym.com');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/website_links_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'website_links.dart'` / target of URI doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `apps/mobile/lib/features/gyms/data/website_links.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// A compact host for display, e.g. `https://www.rmelitebjj.com/x` -> `rmelitebjj.com`.
String websiteDisplayHost(String raw) {
  var s = raw.trim();
  s = s.replaceFirst(_scheme, '');
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  s = s.replaceFirst(RegExp(r'/.*$'), '');
  return s;
}

/// Ensures a launchable absolute URL — prepends https:// when no scheme is present.
String normalizeWebsiteUrl(String raw) {
  final s = raw.trim();
  return _scheme.hasMatch(s) ? s : 'https://$s';
}

/// Opens the gym's website in the default browser. Shows a snackbar on failure.
Future<void> openWebsite(BuildContext context, String rawUrl) async {
  final ok = await launchUrl(Uri.parse(normalizeWebsiteUrl(rawUrl)), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open website")),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/website_links_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Lint**

Run: `flutter analyze lib/features/gyms/data/website_links.dart test/data/website_links_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/gyms/data/website_links.dart apps/mobile/test/data/website_links_test.dart
git commit -m "feat(mobile): add website URL display/normalize helpers + launcher"
```

---

## Task 2: `NearbyGymCard` widget

**Files:**
- Create: `apps/mobile/lib/shared/widgets/nearby_gym_card.dart`
- Test: `apps/mobile/test/features/nearby_gym_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/features/nearby_gym_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/shared/widgets/nearby_gym_card.dart';

Gym _gym({String? address = '203 Bear Rd, Bldg #11', String? website = 'https://www.rmelitebjj.com', double? distanceKm = 19.3, double? rating = 5.0}) => Gym(
      id: 'g1',
      name: 'RM Elite BJJ',
      address: address ?? '',
      website: website,
      rating: rating,
      distanceKm: distanceKm,
    );

Future<void> _pump(WidgetTester tester, Gym gym) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => Scaffold(body: NearbyGymCard(gym: gym))),
    GoRoute(path: '/gym/:id', builder: (c, s) => const Scaffold(body: Text('gym detail'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders name, distance, address and website host', (tester) async {
    await _pump(tester, _gym());
    expect(find.text('RM Elite BJJ'), findsOneWidget);
    expect(find.text('203 Bear Rd, Bldg #11'), findsOneWidget);
    expect(find.text('rmelitebjj.com'), findsOneWidget);
    expect(find.text('12 mi'), findsOneWidget); // 19.3 km / 1.60934 ~= 12
    expect(find.byKey(const Key('nearby-gym-address')), findsOneWidget);
    expect(find.byKey(const Key('nearby-gym-website')), findsOneWidget);
  });

  testWidgets('omits the website row when website is null', (tester) async {
    await _pump(tester, _gym(website: null));
    expect(find.byKey(const Key('nearby-gym-website')), findsNothing);
    expect(find.byKey(const Key('nearby-gym-address')), findsOneWidget);
  });

  testWidgets('omits the address row when address is empty', (tester) async {
    await _pump(tester, _gym(address: ''));
    expect(find.byKey(const Key('nearby-gym-address')), findsNothing);
  });

  testWidgets('does not show a Next: line', (tester) async {
    await _pump(tester, _gym());
    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('tapping the card body navigates to gym detail', (tester) async {
    await _pump(tester, _gym());
    await tester.tap(find.text('RM Elite BJJ'));
    await tester.pumpAndSettle();
    expect(find.text('gym detail'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nearby_gym_card_test.dart`
Expected: FAIL — target of URI `nearby_gym_card.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `apps/mobile/lib/shared/widgets/nearby_gym_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';
import '../../features/gyms/models/gym.dart';
import '../../features/gyms/data/directions.dart';
import '../../features/gyms/data/website_links.dart';

/// A glass-styled card for a gym within range: name, distance, rating, a
/// tappable address (opens directions) and website (opens the browser). The
/// card body taps through to the gym detail screen.
class NearbyGymCard extends ConsumerWidget {
  final Gym gym;

  const NearbyGymCard({super.key, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final address = gym.address.trim();
    final website = gym.website?.trim() ?? '';

    return GestureDetector(
      onTap: () => context.push('/gym/${gym.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(LucideIcons.mapPin, size: 17, color: t.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(gym.name, style: t.h2Style.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis),
                      ),
                      if (gym.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(gym.distanceKm! / 1.60934).round()} mi',
                            style: t.miniStyle.copyWith(fontSize: 11, color: t.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if (gym.rating != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.star, size: 11, color: t.gold),
                              const SizedBox(width: 3),
                              Text(
                                gym.rating!.toStringAsFixed(1),
                                style: t.miniStyle.copyWith(fontSize: 11, color: t.gold, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      key: const Key('nearby-gym-address'),
                      onTap: () => openDirections(ref, context, gymId: gym.id, address: address),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.mapPin, size: 14, color: t.muted),
                          const SizedBox(width: 6),
                          Expanded(child: Text(address, style: t.miniStyle.copyWith(color: t.body, fontSize: 12))),
                          const SizedBox(width: 6),
                          Icon(LucideIcons.navigation, size: 15, color: t.primary),
                        ],
                      ),
                    ),
                  ],
                  if (website.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      key: const Key('nearby-gym-website'),
                      onTap: () => openWebsite(context, website),
                      child: Row(
                        children: [
                          Icon(LucideIcons.globe, size: 14, color: t.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              websiteDisplayHost(website),
                              style: t.miniStyle.copyWith(color: t.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nearby_gym_card_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Lint**

Run: `flutter analyze lib/shared/widgets/nearby_gym_card.dart test/features/nearby_gym_card_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/shared/widgets/nearby_gym_card.dart apps/mobile/test/features/nearby_gym_card_test.dart
git commit -m "feat(mobile): add NearbyGymCard with address/website/distance"
```

---

## Task 3: Discover screen — always-on "Gyms near you (within 50 mi)" section

**Files:**
- Modify: `apps/mobile/lib/features/discover/screens/discover_screen.dart`
- Modify: `apps/mobile/test/features/discover_screen_test.dart`

- [ ] **Step 1: Update the existing test to override the new provider + add a section test**

Replace the whole body of `apps/mobile/test/features/discover_screen_test.dart` with:

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
import 'package:bjj_open_mat/features/discover/providers/discover_provider.dart';
import 'package:bjj_open_mat/features/discover/screens/discover_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';

class _FakeLoc implements LocationService {
  @override
  Future<CapturedLocation?> current() async =>
      const CapturedLocation(latitude: 33.4, longitude: -96.5, accuracyM: 5);
}

class _FakeSearch implements SearchRepository {
  SearchQuery? last;

  @override
  Future<List<OpenMat>> search(SearchQuery query) async {
    last = query;
    return const [
      OpenMat(
        id: 'om-ntbjj',
        gymId: 'g1',
        title: 'Saturday Rolls',
        startTime: '11:00',
        endTime: '13:00',
        gymName: 'North Texas BJJ',
      ),
    ];
  }
}

Future<void> _pumpDiscover(WidgetTester tester, {required List<Gym> nearbyGyms, required _FakeSearch fake}) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => const DiscoverScreen()),
    GoRoute(path: '/open-mat/:id', builder: (c, s) => const Scaffold(body: Text('detail'))),
    GoRoute(path: '/gym/:id', builder: (c, s) => const Scaffold(body: Text('gym detail'))),
    GoRoute(path: '/search', builder: (c, s) => const Scaffold(body: Text('search'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
      locationServiceProvider.overrideWithValue(_FakeLoc()),
      nearbyGymsProvider.overrideWith((ref, q) async => nearbyGyms),
    ],
    child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('discover renders live nearby open mats, not stubs', (tester) async {
    final fake = _FakeSearch();
    await _pumpDiscover(tester, nearbyGyms: const [], fake: fake);

    expect(find.text('North Texas BJJ'), findsWidgets);
    expect(find.text('Atos HQ'), findsNothing);
    expect(fake.last, isNotNull);
    expect(fake.last!.lat, 33.4);
    expect(fake.last!.lng, -96.5);
  });

  testWidgets('shows the "Within 50 miles" gyms section with an address', (tester) async {
    final fake = _FakeSearch();
    await _pumpDiscover(tester, fake: fake, nearbyGyms: const [
      Gym(id: 'g9', name: 'RM Elite BJJ', address: '203 Bear Rd, Bldg #11', website: 'https://rmelitebjj.com', distanceKm: 3.0),
    ]);

    expect(find.text('Within 50 miles'), findsOneWidget);
    expect(find.text('RM Elite BJJ'), findsWidgets);
    expect(find.text('203 Bear Rd, Bldg #11'), findsOneWidget);
    // The old open-mat-derived "Next:" filler line is gone from this section.
    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('requests nearby gyms at a 50-mile (80 km) radius', (tester) async {
    final fake = _FakeSearch();
    NearbyQuery? captured;
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const DiscoverScreen()),
      GoRoute(path: '/open-mat/:id', builder: (c, s) => const Scaffold(body: Text('detail'))),
      GoRoute(path: '/gym/:id', builder: (c, s) => const Scaffold(body: Text('gym detail'))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(fake),
        locationServiceProvider.overrideWithValue(_FakeLoc()),
        nearbyGymsProvider.overrideWith((ref, q) async { captured = q; return const []; }),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, isNotNull);
    expect(captured!.radiusKm, 80);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/discover_screen_test.dart`
Expected: FAIL — the new tests can't find `Within 50 miles` / `203 Bear Rd, Bldg #11`, and `captured.radiusKm` is not 80 (section not implemented yet).

- [ ] **Step 3: Update the imports in the Discover screen**

In `apps/mobile/lib/features/discover/screens/discover_screen.dart`, replace the gym_card import with the new card + gym model. Change:

```dart
import '../../../shared/widgets/gym_card.dart';
```

to:

```dart
import '../../../shared/widgets/nearby_gym_card.dart';
import '../../gyms/models/gym.dart';
```

(`NearbyQuery` is already available via the existing `import '../providers/discover_provider.dart';`.)

- [ ] **Step 4: Replace the feed body with a single scroll + nearby-gyms section**

In the same file, replace the entire `Expanded( child: results.when( ... ) )` block (the one that currently branches on `list.isEmpty`, `list.length < 3`, and the full `ListView.separated`) with:

```dart
            // Feed: open mats, then an always-on "Gyms near you" section.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    results.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text("Couldn't load open mats", style: t.bodyStyle.copyWith(color: t.muted)),
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            icon: LucideIcons.mapPin,
                            title: locState.label != null ? 'No open mats found in ${locState.label}' : 'No open mats found nearby',
                            subtitle: 'Try widening your search or check back soon.',
                            actionLabel: 'Search',
                            onAction: () => context.go('/search'),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final mat in list) ...[
                              SizedBox(
                                width: double.infinity,
                                child: SessionRow(
                                  session: _toRow(mat),
                                  onTap: () => context.push('/open-mat/${mat.id}'),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        );
                      },
                    ),
                    if (locState.hasCoords) _NearbyGymsSection(lat: locState.lat!, lng: locState.lng!),
                  ],
                ),
              ),
            ),
```

- [ ] **Step 5: Add the `_NearbyGymsSection` widget**

At the end of `apps/mobile/lib/features/discover/screens/discover_screen.dart` (top-level, after the `_DiscoverScreenState` class closes), add:

```dart
/// Always-on "Gyms near you" section: every gym within 50 miles (80 km) of the
/// device, sourced from [nearbyGymsProvider]. Hidden while empty/erroring.
class _NearbyGymsSection extends ConsumerWidget {
  final double lat;
  final double lng;

  const _NearbyGymsSection({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymsAsync = ref.watch(nearbyGymsProvider(NearbyQuery(lat: lat, lng: lng, radiusKm: 80)));

    return gymsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text("Couldn't load nearby gyms", style: t.miniStyle.copyWith(color: t.muted)),
      ),
      data: (gyms) {
        if (gyms.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('GYMS NEAR YOU', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
            const SizedBox(height: 3),
            Text('Within 50 miles', style: t.h2Style),
            const SizedBox(height: 14),
            for (final gym in gyms) ...[
              NearbyGymCard(gym: gym),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 6: Run the Discover test to verify it passes**

Run: `flutter test test/features/discover_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Lint**

Run: `flutter analyze lib/features/discover/screens/discover_screen.dart test/features/discover_screen_test.dart`
Expected: `No issues found!` (If analyze flags an unused import for `gym_card.dart`, it means Step 3 wasn't applied — remove the stale import.)

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib/features/discover/screens/discover_screen.dart apps/mobile/test/features/discover_screen_test.dart
git commit -m "feat(mobile): show all gyms within 50mi on Discover with address/website"
```

---

## Task 4: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full mobile test suite**

Run: `flutter test`
Expected: All tests pass (including the untouched Search `GymCard` tests, proving Search behavior is unchanged).

- [ ] **Step 2: Analyze the whole app**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Manual smoke (optional, needs emulator + API)**

Launch the app on the emulator against the local API (`bun run mobile:run` or the e2e harness). On the Discover screen confirm: the "Within 50 miles" section lists nearby gyms; each card shows distance + address + website and no "Next:" line; tapping the address opens maps; tapping the website opens the browser; tapping the card opens the gym detail.

---

## Self-Review Notes (for the author)

- **Spec coverage:** data source at 80 km (Task 3 Step 5 + radius test); Discover-only restructure (Task 3); `NearbyGymCard` with distance/rating/address(→maps)/website(→browser) and card-body→detail (Task 2); helpers (Task 1); edge handling — empty→hidden, error line, null rows omitted (Tasks 2 & 3); tests (all tasks); Search untouched (Task 4 Step 1). All covered.
- **Type consistency:** `NearbyGymCard({required Gym gym})`, `openDirections(ref, context, gymId:, address:)`, `openWebsite(context, String)`, `websiteDisplayHost(String)`, `normalizeWebsiteUrl(String)`, `NearbyQuery(lat:, lng:, radiusKm:)`, `nearbyGymsProvider` family — consistent across tasks.
- **No placeholders:** every code step has full code; every run step has an exact command + expected result.
