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
