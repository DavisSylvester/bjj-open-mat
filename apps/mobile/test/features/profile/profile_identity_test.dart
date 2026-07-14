import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/profile/widgets/profile_view.dart';

void main() {
  group('profileDisplayName', () {
    test('falls back when empty', () {
      expect(profileDisplayName(''), 'BJJ Practitioner');
      expect(profileDisplayName('   '), 'BJJ Practitioner');
    });
    test('keeps a real name', () {
      expect(profileDisplayName('Danaher'), 'Danaher');
    });
  });
  group('profileEmailForDisplay', () {
    test('hides the synthetic placeholder email', () {
      expect(profileEmailForDisplay('auth0-6a36dd6a90830c3d8fb430aa@users.bjj-open-mat.app'), isNull);
    });
    test('hides an empty email', () {
      expect(profileEmailForDisplay(''), isNull);
    });
    test('keeps a real email', () {
      expect(profileEmailForDisplay('john@example.com'), 'john@example.com');
    });
  });
}
