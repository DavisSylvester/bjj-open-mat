import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';

void main() {
  group('isPlausibleFix', () {
    test('rejects Null Island (0,0)', () {
      expect(isPlausibleFix(0, 0), isFalse);
    });
    test('rejects near-zero garbage fixes', () {
      expect(isPlausibleFix(0.0001, -0.0001), isFalse);
    });
    test('rejects out-of-range coordinates', () {
      expect(isPlausibleFix(91, 10), isFalse);
      expect(isPlausibleFix(10, 200), isFalse);
    });
    test('rejects non-finite coordinates', () {
      expect(isPlausibleFix(double.nan, 10), isFalse);
      expect(isPlausibleFix(10, double.infinity), isFalse);
    });
    test('accepts a real US city fix (San Diego)', () {
      expect(isPlausibleFix(32.7157, -117.1611), isTrue);
    });
    test('accepts a real fix in the southern/eastern hemisphere', () {
      expect(isPlausibleFix(-33.8688, 151.2093), isTrue); // Sydney
    });
  });
}
