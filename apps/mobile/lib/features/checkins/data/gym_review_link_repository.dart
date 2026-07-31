import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

/// Whether to offer the Google Maps hand-off after an in-app review.
///
/// Offered to every reviewer regardless of score. Showing it only to happy
/// reviewers is review gating, which Google's Maps user-generated content
/// policy prohibits ("selectively soliciting positive reviews") and which the
/// FTC's review-suppression rule also reaches. The only condition is whether
/// the gym has a usable Google link.
bool shouldOfferGoogleReview({required String? writeAReviewUri}) {
  return writeAReviewUri != null && writeAReviewUri.isNotEmpty;
}

/// Google Maps "write a review" URI for a gym, or null when unavailable.
/// Null is a normal result, not an error — the caller omits the Google step.
final gymReviewLinkProvider = FutureProvider.family<String?, String>((ref, gymId) async {
  try {
    final res = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          Endpoints.gymReviewLink(gymId),
        );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data?['writeAReviewUri'] as String?;
  } catch (_) {
    return null;
  }
});
