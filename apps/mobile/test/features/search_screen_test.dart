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
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byKey(const Key('search-zip')), '75495');
    await tester.tap(find.byKey(const Key('when-weekend')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(fake.last, isNotNull);
    expect(fake.last!.zip, '75495');
    expect(fake.last!.when, isNotNull);
    expect(find.text('NT BJJ'), findsWidgets);
  });
}
