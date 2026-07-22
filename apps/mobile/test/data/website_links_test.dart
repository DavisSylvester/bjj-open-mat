import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/website_links.dart';

void main() {
  group('websiteDisplayHost', () {
    test('strips scheme and www and path', () {
      expect(websiteDisplayHost('https://www.rmelitebjj.com/schedule'), 'rmelitebjj.com');
    });
    test('leaves a bare host unchanged', () {
      expect(websiteDisplayHost('rmelitebjj.com'), 'rmelitebjj.com');
    });
    test('strips http scheme without www', () {
      expect(websiteDisplayHost('http://atosjj.com'), 'atosjj.com');
    });
  });

  group('normalizeWebsiteUrl', () {
    test('adds https:// when no scheme present', () {
      expect(normalizeWebsiteUrl('rmelitebjj.com'), 'https://rmelitebjj.com');
    });
    test('keeps an existing scheme', () {
      expect(normalizeWebsiteUrl('http://atosjj.com'), 'http://atosjj.com');
    });
    test('trims surrounding whitespace', () {
      expect(normalizeWebsiteUrl('  gym.com '), 'https://gym.com');
    });
  });
}
