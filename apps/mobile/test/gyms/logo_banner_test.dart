import 'package:bjj_open_mat/features/gyms/data/logo_banner_dismissal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowLogoBanner', () {
    test('shows for the gym-owner account that owns this gym and it has no logo', () {
      expect(
        shouldShowLogoBanner(logoUrl: null, isGymOwner: true, ownsThisGym: true, dismissed: false),
        isTrue,
      );
      expect(
        shouldShowLogoBanner(logoUrl: '', isGymOwner: true, ownsThisGym: true, dismissed: false),
        isTrue,
      );
    });

    test('hidden once the gym has a logo', () {
      expect(
        shouldShowLogoBanner(
          logoUrl: 'https://cdn/logo.jpg',
          isGymOwner: true,
          ownsThisGym: true,
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('hidden for a non gym-owner account', () {
      // Both the router guard and the server's requireOwner check the ACCOUNT
      // role. A coach passes deriveCanManageGym but would be bounced to
      // Discover and 403'd, so the banner must not appear for them.
      expect(
        shouldShowLogoBanner(logoUrl: null, isGymOwner: false, ownsThisGym: true, dismissed: false),
        isFalse,
      );
    });

    test('hidden for a gym_owner account that does NOT own this gym', () {
      // The `gym_owner` role is account-wide, not per-gym. The server's admin
      // update path additionally checks `gym.ownerId == ownerId`
      // (gym.facade.mts), so an owner viewing someone else's logo-less gym
      // must not be offered an action that dead-ends in a 403 after an
      // already-completed S3 upload.
      expect(
        shouldShowLogoBanner(logoUrl: null, isGymOwner: true, ownsThisGym: false, dismissed: false),
        isFalse,
      );
    });

    test('hidden once dismissed', () {
      expect(
        shouldShowLogoBanner(logoUrl: null, isGymOwner: true, ownsThisGym: true, dismissed: true),
        isFalse,
      );
    });
  });
}
