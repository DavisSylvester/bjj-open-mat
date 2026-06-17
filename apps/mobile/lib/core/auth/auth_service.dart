import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

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
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'beltRank': beltRank,
    'weight': weight,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'homeGymId': homeGymId,
  };

  bool get isGymOwner => role == 'gym_owner';
  bool get isPractitioner => role == 'practitioner';
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _bootstrap();
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _bootstrap() async => checkAuth();

  AuthService get _authService => ref.read(authServiceProvider);

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await _authService.getStoredToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      await _authService.applyStoredToken();
      final user = await _authService.getOrCreateProfile();
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> setRole(String role) async {
    final updated = await _authService.updateProfile({'role': role});
    if (updated != null) state = state.copyWith(user: updated);
  }

  Future<void> loginWithGoogle() async => _socialLogin('google-oauth2');
  Future<void> loginWithApple() async => _socialLogin('apple');

  Future<void> _socialLogin(String connection) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final credentials = await _authService.login(connection);
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

  // Replace with your Auth0 domain and client ID
  late final Auth0 _auth0;

  AuthService({required this.apiClient}) {
    _auth0 = Auth0(
      const String.fromEnvironment('AUTH0_DOMAIN', defaultValue: 'your-tenant.auth0.com'),
      const String.fromEnvironment('AUTH0_CLIENT_ID', defaultValue: 'your-client-id'),
    );
  }

  Future<Credentials?> login(String connection) async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        parameters: {'connection': connection},
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );
      await _storage.write(key: 'access_token', value: credentials.accessToken);
      await _storage.write(key: 'refresh_token', value: credentials.refreshToken);
      await apiClient.setToken(credentials.accessToken);
      return credentials;
    } catch (_) {
      return null;
    }
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
    await _auth0.webAuthentication().logout();
    await _storage.deleteAll();
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
