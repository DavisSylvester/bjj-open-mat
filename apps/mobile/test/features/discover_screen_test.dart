import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:bjj_open_mat/features/search/data/search_query.dart';
import 'package:bjj_open_mat/features/search/data/search_repository.dart';
import 'package:bjj_open_mat/features/discover/screens/discover_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('discover renders live nearby open mats, not stubs', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fake = _FakeSearch();

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const DiscoverScreen()),
      GoRoute(path: '/open-mat/:id', builder: (c, s) => const Scaffold(body: Text('detail'))),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(fake),
        locationServiceProvider.overrideWithValue(_FakeLoc()),
      ],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    // Let the location future resolve, the geo query rebuild, and its search complete.
    await tester.pump(const Duration(milliseconds: 400));

    // Live API data renders.
    expect(find.text('North Texas BJJ'), findsWidgets);
    // Former hardcoded stub gym must be gone.
    expect(find.text('Atos HQ'), findsNothing);
    // GPS location fed the query.
    expect(fake.last, isNotNull);
    expect(fake.last!.lat, 33.4);
    expect(fake.last!.lng, -96.5);
  });
}
