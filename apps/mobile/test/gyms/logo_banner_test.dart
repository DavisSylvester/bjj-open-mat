import 'dart:io';

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

  group('gym_detail_screen banner render gating (source-text)', () {
    // Widget-level gating: the dismissal FutureProvider must drive rendering
    // via .when() so loading → SizedBox.shrink() and the banner only appears
    // in the resolved-and-not-dismissed state. We verify the source of truth
    // (the widget source) because a Riverpod widget test for _GlassGymDetail
    // requires stubbing 7+ providers (gym, favorites, auth, permissions, …)
    // and that scaffolding would add fragility with no incremental safety gain
    // over the source check.
    late String source;
    setUpAll(() {
      source = File('lib/features/gyms/screens/gym_detail_screen.dart').readAsStringSync();
    });

    test('uses .when() to gate on the resolved state', () {
      expect(
        source,
        contains('logoBannerDismissedProvider(gym.id)).when('),
        reason: 'the provider must be consumed via .when(), not .value',
      );
    });

    test('shows SizedBox.shrink() while loading', () {
      expect(
        source,
        contains('loading: () => const SizedBox.shrink()'),
        reason: 'banner must not render while the dismissal read is in-flight',
      );
    });

    test('shows SizedBox.shrink() on error', () {
      expect(
        source,
        contains('error: (err, _) => const SizedBox.shrink()'),
        reason: 'banner must not render when the dismissal read fails',
      );
    });

    test('does NOT fall back to .value ?? false (the old flickering pattern)', () {
      expect(
        source,
        isNot(contains('.value ?? false')),
        reason: '.value ?? false treats loading as not-dismissed, causing the flicker',
      );
    });
  });
}
