import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/mygym/data/home_gym_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GymMembership _m({required String gymId, required bool isHome}) => GymMembership(
      id: 'm-$gymId',
      gymId: gymId,
      userId: 'u1',
      status: 'active',
      verifiedMember: true,
      gymRole: 'member',
      isHome: isHome,
      visibleInRoster: true,
      joinMethod: 'manual',
      joinedAt: '2026-01-01T00:00:00Z',
    );

class _AuthStateNotifierWithProfile extends AuthStateNotifier {
  final String? homeGymId;
  _AuthStateNotifierWithProfile({required this.homeGymId});
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: UserProfile(
      id: 'u1',
      email: 'test@example.com',
      displayName: 'Test User',
      homeGymId: homeGymId,
    ),
  );
}

void main() {
  group('resolveHomeGymId', () {
    test('profile home gym wins when set', () {
      expect(
        resolveHomeGymId(
          profileHomeGymId: 'gym-profile',
          memberships: [_m(gymId: 'gym-member', isHome: true)],
        ),
        'gym-profile',
      );
    });

    test('falls back to the membership flagged isHome', () {
      expect(
        resolveHomeGymId(
          profileHomeGymId: null,
          memberships: [_m(gymId: 'gym-a', isHome: false), _m(gymId: 'gym-b', isHome: true)],
        ),
        'gym-b',
      );
    });

    test('treats an empty profile value as unset', () {
      expect(
        resolveHomeGymId(
          profileHomeGymId: '',
          memberships: [_m(gymId: 'gym-b', isHome: true)],
        ),
        'gym-b',
      );
    });

    test('returns null when there is no gym at all', () {
      expect(resolveHomeGymId(profileHomeGymId: null, memberships: const []), isNull);
    });

    test('returns null when memberships exist but none is home', () {
      expect(
        resolveHomeGymId(
          profileHomeGymId: null,
          memberships: [_m(gymId: 'gym-a', isHome: false)],
        ),
        isNull,
      );
    });
  });

  group('homeGymIdProvider', () {
    test('profile home gym wins over membership isHome', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => _AuthStateNotifierWithProfile(homeGymId: 'gym-profile'),
          ),
          myMembershipsProvider.overrideWith((ref) =>
              Future.value([_m(gymId: 'gym-member', isHome: true)])),
        ],
      );

      final result = await container.read(homeGymIdProvider.future);
      expect(result, 'gym-profile');
    });

    test('falls back to membership isHome when profile homeGymId is null', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => _AuthStateNotifierWithProfile(homeGymId: null),
          ),
          myMembershipsProvider.overrideWith((ref) =>
              Future.value([_m(gymId: 'gym-b', isHome: true)])),
        ],
      );

      final result = await container.read(homeGymIdProvider.future);
      expect(result, 'gym-b');
    });

    test('treats empty profile value as unset in provider', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => _AuthStateNotifierWithProfile(homeGymId: ''),
          ),
          myMembershipsProvider.overrideWith((ref) =>
              Future.value([_m(gymId: 'gym-c', isHome: true)])),
        ],
      );

      final result = await container.read(homeGymIdProvider.future);
      expect(result, 'gym-c');
    });
  });
}
