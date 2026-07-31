import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Number of check-ins that marks a user as genuinely engaged.
const int kRatingPromptCheckInThreshold = 3;

/// SharedPreferences key recording that the system prompt has been requested.
///
/// Deliberately stored in SharedPreferences (not FlutterSecureStorage) so that
/// [AuthService.logout]'s `deleteAll()` wipe does not clear it. A "have we
/// asked the device for a rating?" flag is device-scoped, not account-scoped —
/// it must survive a logout/login cycle.
const String kRatingPromptedKey = 'app_rating_prompted';

/// Whether the App Store rating prompt should be requested now.
///
/// Apple caps the system prompt at three presentations per user per year, so
/// it must never be spent on launch or first run. Gate it on demonstrated
/// usage instead, and only ever ask once.
bool shouldPromptForRating({required int checkInCount, required bool alreadyPrompted}) {
  if (alreadyPrompted) return false;
  return checkInCount >= kRatingPromptCheckInThreshold;
}

/// Requests the native App Store rating prompt at an appropriate moment.
class AppRatingService {
  AppRatingService({InAppReview? inAppReview, SharedPreferences? prefs})
      : _inAppReview = inAppReview ?? InAppReview.instance,
        _prefs = prefs;

  final InAppReview _inAppReview;
  // Nullable so tests can inject a fake; production path resolves lazily.
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Prompts once the user has enough check-ins, then records that it fired.
  ///
  /// `requestReview()` intentionally gives no success signal — iOS may show
  /// nothing at all. Never branch on the outcome and never claim to the user
  /// that a review was left.
  Future<void> maybePrompt(int checkInCount) async {
    try {
      final prefs = await _getPrefs();
      final alreadyPrompted = prefs.getBool(kRatingPromptedKey) ?? false;
      if (!shouldPromptForRating(checkInCount: checkInCount, alreadyPrompted: alreadyPrompted)) {
        return;
      }
      if (!await _inAppReview.isAvailable()) return;
      await prefs.setBool(kRatingPromptedKey, true);
      await _inAppReview.requestReview();
    } catch (e) {
      // A rating prompt is never worth interrupting the user for.
      debugPrint('rating prompt skipped: $e');
    }
  }
}

final appRatingServiceProvider = Provider<AppRatingService>((ref) => AppRatingService());
