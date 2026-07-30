import 'package:bjj_open_mat/core/rating/app_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldPromptForRating', () {
    test('does not prompt below the third check-in', () {
      expect(shouldPromptForRating(checkInCount: 0, alreadyPrompted: false), isFalse);
      expect(shouldPromptForRating(checkInCount: 1, alreadyPrompted: false), isFalse);
      expect(shouldPromptForRating(checkInCount: 2, alreadyPrompted: false), isFalse);
    });

    test('prompts at exactly the third check-in', () {
      expect(shouldPromptForRating(checkInCount: 3, alreadyPrompted: false), isTrue);
    });

    test('still prompts beyond three if never prompted before', () {
      expect(shouldPromptForRating(checkInCount: 9, alreadyPrompted: false), isTrue);
    });

    test('never prompts twice', () {
      expect(shouldPromptForRating(checkInCount: 3, alreadyPrompted: true), isFalse);
      expect(shouldPromptForRating(checkInCount: 99, alreadyPrompted: true), isFalse);
    });

    test('treats a negative or nonsense count as not eligible', () {
      expect(shouldPromptForRating(checkInCount: -1, alreadyPrompted: false), isFalse);
    });
  });
}
