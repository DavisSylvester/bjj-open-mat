import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/settings/screens/settings_screen.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  int deleteAccountCalls = 0;

  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(id: 'auth0|1', email: 'a@x.io', displayName: 'A User'),
      );

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

Widget _app(GoRouter router, _FakeAuthNotifier notifier) => ProviderScope(
      overrides: [authStateProvider.overrideWith(() => notifier)],
      child: MaterialApp.router(theme: AppTheme.glass(), routerConfig: router),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Settings shows a Delete Account option that asks for confirmation before deleting', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _FakeAuthNotifier();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/login', builder: (c, s) => const Scaffold(body: Center(child: Text('LOGIN SCREEN')))),
      ],
    );

    await tester.pumpWidget(_app(router, notifier));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account'), findsOneWidget);

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears; deletion has not happened yet.
    expect(find.textContaining('permanently'), findsOneWidget);
    expect(notifier.deleteAccountCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.deleteAccountCalls, 0);
    expect(find.text('Delete Account'), findsOneWidget);

    // Re-open and confirm this time.
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(notifier.deleteAccountCalls, 1);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });
}
