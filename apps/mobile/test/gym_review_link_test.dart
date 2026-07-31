import 'package:bjj_open_mat/features/checkins/data/gym_review_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldOfferGoogleReview', () {
    const uri = 'https://maps.google.com/write';

    test('offered whenever the gym has a Google link', () {
      expect(shouldOfferGoogleReview(writeAReviewUri: uri), isTrue);
    });

    test('hidden when the gym has no Google link', () {
      expect(shouldOfferGoogleReview(writeAReviewUri: null), isFalse);
      expect(shouldOfferGoogleReview(writeAReviewUri: ''), isFalse);
    });

    test('does not depend on the rating — gating positive reviewers only is '
        'review gating, which Google prohibits', () {
      // Deliberately no rating parameter. If a future change reintroduces one,
      // this test should be the thing that argues against it.
      expect(shouldOfferGoogleReview(writeAReviewUri: uri), isTrue);
    });
  });
}
