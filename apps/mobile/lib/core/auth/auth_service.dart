import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

// Auth0 config (supplied via --dart-define). Domain/clientId/audience are
// public client values; the audience must match the Auth0 API identifier.
const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN', defaultValue: 'your-tenant.auth0.com');
const String _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID', defaultValue: 'your-client-id');
const String _auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE', defaultValue: '');
const Set<String> _auth0Scopes = {'openid', 'profile', 'email', 'offline_access'};

final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserProfile? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class UserProfile {
  final String id;
  final String? auth0Id;
  final String email;
  final String displayName;
  final String? role;
  final String? beltRank;
  final String? weight;
  final String? bio;
  final String? avatarUrl;
  final String? homeGymId;
  final String? city;
  final String? state;
  final String? gender;
  final double? weightValue;
  final String? weightUnit;
  final String? weightDivision;
  final String? weightDivisionContext;

  const UserProfile({
    required this.id,
    this.auth0Id,
    required this.email,
    required this.displayName,
    this.role,
    this.beltRank,
    this.weight,
    this.bio,
    this.avatarUrl,
    this.homeGymId,
    this.city,
    this.state,
    this.gender,
    this.weightValue,
    this.weightUnit,
    this.weightDivision,
    this.weightDivisionContext,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      auth0Id: json['auth0Id'] as String?,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String?,
      beltRank: json['beltRank'] as String?,
      weight: json['weight'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      homeGymId: json['homeGymId'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      gender: json['gender'] as String?,
      weightValue: (json['weightValue'] as num?)?.toDouble(),
      weightUnit: json['weightUnit'] as String?,
      weightDivision: json['weightDivision'] as String?,
      weightDivisionContext: json['weightDivisionContext'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'beltRank': beltRank,
    'weight': weight,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'homeGymId': homeGymId,
    'city': city,
    'state': state,
    'gender': gender,
    'weightValue': weightValue,
    'weightUnit': weightUnit,
    'weightDivision': weightDivision,
    'weightDivisionContext': weightDivisionContext,
  };

  bool get isGymOwner => role == 'gym_owner';
  bool get isPractitioner => role == 'practitioner';
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Defer to a microtask so checkAuth() runs AFTER build() returns and the
    // provider is initialized — reading/setting `state` during build() throws
    // "Tried to read the state of an uninitialized provider".
    Future.microtask(_bootstrap);
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _bootstrap() async => checkAuth();

  AuthService get _authService => ref.read(authServiceProvider);

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // Dev-only bypass (off by default): authenticate as the demo owner using
      // the API bypass token, skipping Auth0. Enable with
      // --dart-define=DEV_BYPASS=true --dart-define=AUTH_BYPASS_TOKEN=<secret>.
      const devBypass = bool.fromEnvironment('DEV_BYPASS');
      const bypassToken = String.fromEnvironment('AUTH_BYPASS_TOKEN');
      if (devBypass && bypassToken.isNotEmpty) {
        await _authService.apiClient.setToken(bypassToken);
        state = const AuthState(
          status: AuthStatus.authenticated,
          user: UserProfile(
            // Must match the API's DEMO_USER_ID so the client user id lines up
            // with the server identity RSVPs/check-ins are saved under.
            id: 'test-user@local.priv',
            email: 'demo@bjj-open-mat.test',
            displayName: 'Demo Owner',
            role: 'gym_owner',
          ),
        );
        return;
      }
      if (kIsWeb) {
        // Completes a redirect callback or restores an existing SPA session.
        final user = await _authService.webOnLoad();
        state = user != null
            ? AuthState(status: AuthStatus.authenticated, user: user)
            : const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final token = await _authService.getStoredToken();
      if (token == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      await _authService.applyStoredToken();
      final user = await _authService.getOrCreateProfile();
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      // Any failure (e.g. token exchange / secure storage / Auth0 init on web) ->
      // unauthenticated so the app always leaves the splash and lands on /login,
      // but keep the reason so the login screen and console can show it.
      debugPrint('checkAuth failed: $e');
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> setRole(String role) async {
    final updated = await _authService.updateProfile({'role': role});
    if (updated != null) state = state.copyWith(user: updated);
  }

  Future<void> loginWithGoogle() async => _socialLogin('google-oauth2');
  Future<void> loginWithApple() async => _socialLogin('apple');
  // Universal Login (shows the email/password Database form + any social).
  Future<void> loginWithEmail() async => _socialLogin(null);

  Future<void> _socialLogin(String? connection) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // On web this navigates to Auth0 and the page unloads; the session is
      // completed by checkAuth()/webOnLoad() after the callback redirect.
      final credentials = await _authService.login(connection);
      if (kIsWeb) return;
      if (credentials != null) {
        final user = await _authService.getOrCreateProfile();
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: 'Login cancelled');
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final updated = await _authService.updateProfile(updates);
    if (updated != null) {
      state = state.copyWith(user: updated);
    }
  }
}

class AuthService {
  final ApiClient apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late final Auth0 _auth0;
  // Web uses the redirect-based SPA flow (the native webAuthentication channel
  // is not implemented on web). Null on non-web platforms.
  Auth0Web? _auth0Web;

  AuthService({required this.apiClient}) {
    _auth0 = Auth0(_auth0Domain, _auth0ClientId);
    if (kIsWeb) {
      _auth0Web = Auth0Web(
        _auth0Domain,
        _auth0ClientId,
        redirectUrl: Uri.base.origin,
        cacheLocation: CacheLocation.localStorage,
      );
    }
  }

  /// Web only: completes a redirect callback (or restores an existing session),
  /// returning the profile if authenticated. Call during app load.
  Future<UserProfile?> webOnLoad() async {
    final creds = await _auth0Web!.onLoad(
      audience: _auth0Audience.isEmpty ? null : _auth0Audience,
      scopes: _auth0Scopes,
    );
    if (creds == null) return null;
    await apiClient.setToken(creds.accessToken);
    return getOrCreateProfile();
  }

  /// [connection] selects a specific Auth0 connection (e.g. "google-oauth2").
  /// Pass null to show Auth0 Universal Login with all enabled connections
  /// (including the email/password Database form).
  Future<Credentials?> login(String? connection) async {
    final params = connection != null ? {'connection': connection} : const <String, String>{};
    if (kIsWeb) {
      // Navigates the page to Auth0; the flow resumes via webOnLoad() after the
      // callback redirect. Nothing after this runs (the page unloads).
      await _auth0Web!.loginWithRedirect(
        audience: _auth0Audience.isEmpty ? null : _auth0Audience,
        redirectUrl: Uri.base.origin,
        scopes: _auth0Scopes,
        parameters: params,
      );
      return null;
    }
    final credentials = await _auth0.webAuthentication().login(
      audience: _auth0Audience.isEmpty ? null : _auth0Audience,
      parameters: params,
      scopes: _auth0Scopes,
    );
    await _storage.write(key: 'access_token', value: credentials.accessToken);
    await _storage.write(key: 'refresh_token', value: credentials.refreshToken);
    await apiClient.setToken(credentials.accessToken);
    return credentials;
  }

  Future<UserProfile?> getOrCreateProfile() async {
    final response = await apiClient.get(Endpoints.authMe);
    final data = response.data;
    if (data != null && data['data'] != null) {
      return UserProfile.fromJson(data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<UserProfile?> updateProfile(Map<String, dynamic> updates) async {
    final response = await apiClient.put(Endpoints.usersMe, data: updates);
    final data = response.data;
    if (data != null && data['data'] != null) {
      return UserProfile.fromJson(data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> logout() async {
    if (kIsWeb) {
      await _auth0Web!.logout(returnToUrl: Uri.base.origin);
    } else {
      await _auth0.webAuthentication().logout();
      await _storage.deleteAll();
    }
    await apiClient.clearToken();
  }

  Future<String?> getStoredToken() async {
    return _storage.read(key: 'access_token');
  }

  Future<void> applyStoredToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) await apiClient.setToken(token);
  }
}
