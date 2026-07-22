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
