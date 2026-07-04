import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/main.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';

// Deterministic auth state for the smoke test: synchronous unauthenticated,
// so the real bootstrap (secure storage / Auth0 / API) never runs in tests.
class _UnauthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  testWidgets('App starts without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith(_UnauthNotifier.new)],
        child: const BjjOpenMatApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BjjOpenMatApp), findsOneWidget);
  });
}
