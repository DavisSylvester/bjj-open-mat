import 'package:bjj_open_mat/features/gyms/data/logo_banner_dismissal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowLogoBanner', () {
    test('shows when a gym-owner account views a gym with no logo', () {
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: true, dismissed: false), isTrue);
      expect(shouldShowLogoBanner(logoUrl: '', isGymOwner: true, dismissed: false), isTrue);
    });

    test('hidden once the gym has a logo', () {
      expect(
        shouldShowLogoBanner(logoUrl: 'https://cdn/logo.jpg', isGymOwner: true, dismissed: false),
        isFalse,
      );
    });

    test('hidden for a non gym-owner account', () {
      // Both the router guard and the server's requireOwner check the ACCOUNT
      // role. A coach passes deriveCanManageGym but would be bounced to
      // Discover and 403'd, so the banner must not appear for them.
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: false, dismissed: false), isFalse);
    });

    test('hidden once dismissed', () {
      expect(shouldShowLogoBanner(logoUrl: null, isGymOwner: true, dismissed: true), isFalse);
    });
  });
}
