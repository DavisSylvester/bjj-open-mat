import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';

/// Number of check-ins that marks a user as genuinely engaged.
const int kRatingPromptCheckInThreshold = 3;

/// Secure-storage key recording that the system prompt has been requested.
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
  AppRatingService({InAppReview? inAppReview, FlutterSecureStorage? storage})
      : _inAppReview = inAppReview ?? InAppReview.instance,
        _storage = storage ?? const FlutterSecureStorage();

  final InAppReview _inAppReview;
  final FlutterSecureStorage _storage;

  /// Prompts once the user has enough check-ins, then records that it fired.
  ///
  /// `requestReview()` intentionally gives no success signal — iOS may show
  /// nothing at all. Never branch on the outcome and never claim to the user
  /// that a review was left.
  Future<void> maybePrompt(int checkInCount) async {
    try {
      final alreadyPrompted = await _storage.read(key: kRatingPromptedKey) != null;
      if (!shouldPromptForRating(checkInCount: checkInCount, alreadyPrompted: alreadyPrompted)) {
        return;
      }
      if (!await _inAppReview.isAvailable()) return;
      await _storage.write(key: kRatingPromptedKey, value: 'true');
      await _inAppReview.requestReview();
    } catch (e) {
      // A rating prompt is never worth interrupting the user for.
      debugPrint('rating prompt skipped: $e');
    }
  }
}

final appRatingServiceProvider = Provider<AppRatingService>((ref) => AppRatingService());
