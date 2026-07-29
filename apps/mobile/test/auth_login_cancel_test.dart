import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:bjj_open_mat/core/api/api_client.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real service so the notifier's failure handling can be
/// exercised without Auth0 or the network.
class _StubAuthService extends AuthService {
  _StubAuthService(this.onLogin) : super(apiClient: ApiClient());

  final Future<Credentials?> Function() onLogin;

  @override
  Future<Credentials?> login(String? connection) => onLogin();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No stored token -> checkAuth() settles on unauthenticated without an
    // API call, so each test starts from a clean, error-free state.
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<AuthState> stateAfterLogin(Future<Credentials?> Function() onLogin) async {
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(_StubAuthService(onLogin))],
    );
    addTearDown(container.dispose);

    // Let the bootstrap microtask (checkAuth) settle first.
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);

    await container.read(authStateProvider.notifier).loginWithGoogle();
    return container.read(authStateProvider);
  }

  test('cancelling the hosted login shows no error', () async {
    final state = await stateAfterLogin(
      () async => throw const WebAuthenticationException(
        'USER_CANCELLED',
        'The user cancelled the Web Auth operation.',
        {},
      ),
    );

    expect(state.status, AuthStatus.unauthenticated);
    expect(state.error, isNull);
  });

  test('backing out with no credentials shows no error', () async {
    final state = await stateAfterLogin(() async => null);

    expect(state.status, AuthStatus.unauthenticated);
    expect(state.error, isNull);
  });

  test('a real login failure still surfaces a friendly message', () async {
    final state = await stateAfterLogin(
      () async => throw const WebAuthenticationException(
        'a0.invalid_configuration',
        'bad config',
        {},
      ),
    );

    expect(state.status, AuthStatus.unauthenticated);
    expect(state.error, isNotNull);
    expect(state.error, 'Something went wrong. Please try again.');
    expect(state.error, isNot(contains('a0.invalid_configuration')));
  });
}
