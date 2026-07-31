import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String _key(String gymId) => 'gym_logo_banner_dismissed_$gymId';

/// Whether to prompt for a gym logo.
///
/// Gated on [isGymOwner] — the ACCOUNT role — not on `deriveCanManageGym`.
/// Both guards this prompt has to satisfy check the account role: the server's
/// `requireOwner` rejects anything but `gym_owner`, and the router redirects
/// non-owners away from `/owner/**`. A coach passes `deriveCanManageGym` but
/// would be bounced to Discover and then 403'd, so a broader gate would offer
/// an action that cannot complete.
///
/// [ownsThisGym] adds the per-gym dimension the account role lacks: a
/// `gym_owner` account owns SOME gym, not necessarily THIS one. The server's
/// admin update path additionally checks `gym.ownerId == ownerId`
/// (`gym.facade.mts`), so without this the banner would offer an "Add" action
/// that uploads bytes to S3 and then 403s on save for any logo-less gym the
/// viewer does not own (e.g. reached via Favorites).
bool shouldShowLogoBanner({
  required String? logoUrl,
  required bool isGymOwner,
  required bool ownsThisGym,
  required bool dismissed,
}) {
  if (!isGymOwner) return false;
  if (!ownsThisGym) return false;
  if (dismissed) return false;
  return logoUrl == null || logoUrl.isEmpty;
}

/// Whether this gym's banner has been dismissed. Per gym, so dismissing one
/// does not silence the prompt for another. A storage failure resolves to
/// false — showing the banner is a better failure than silently suppressing it.
final logoBannerDismissedProvider = FutureProvider.family<bool, String>((ref, gymId) async {
  try {
    return await const FlutterSecureStorage().read(key: _key(gymId)) != null;
  } catch (_) {
    return false;
  }
});

Future<void> dismissLogoBanner(String gymId) async {
  try {
    await const FlutterSecureStorage().write(key: _key(gymId), value: 'true');
  } catch (_) {
    // A failed dismissal just means the banner returns; never surface it.
  }
}
