import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:bjj_open_mat/features/search/data/search_query.dart';
import 'package:bjj_open_mat/features/search/data/search_repository.dart';
import 'package:bjj_open_mat/features/discover/providers/discover_provider.dart';
import 'package:bjj_open_mat/features/discover/screens/discover_screen.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

class _FakeLoc implements LocationService {
  @override
  Future<CapturedLocation?> current() async => null;
}

class _FakeSearch implements SearchRepository {
  @override
  Future<List<OpenMat>> search(SearchQuery query) async => const [];
}

class _AuthWithName extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(id: 'u1', email: 'a@b.io', displayName: 'Jordan Smith'),
      );
}

class _AuthBlankName extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(id: 'u1', email: 'a@b.io', displayName: ''),
      );
}

Future<void> _pumpDiscover(WidgetTester tester, AuthStateNotifier Function() notifier) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => const DiscoverScreen()),
    GoRoute(path: '/search', builder: (c, s) => const Scaffold(body: Text('search'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(notifier),
      searchRepositoryProvider.overrideWithValue(_FakeSearch()),
      locationServiceProvider.overrideWithValue(_FakeLoc()),
      nearbyGymsProvider.overrideWith((ref, q) async => const []),
    ],
    child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('name completion prompt is NOT shown when displayName is set', (tester) async {
    await _pumpDiscover(tester, _AuthWithName.new);
    expect(find.text('Complete your profile'), findsNothing);
  });

  testWidgets('name completion prompt IS shown when displayName is blank', (tester) async {
    await _pumpDiscover(tester, _AuthBlankName.new);
    expect(find.text('Complete your profile'), findsOneWidget);
  });
}
