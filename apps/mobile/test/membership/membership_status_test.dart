import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/models/membership_status.dart';

void main() {
  group('hasMemberPrivileges', () {
    test('active has privileges', () {
      expect(hasMemberPrivileges('active'), true);
    });

    test('hidden has privileges', () {
      expect(hasMemberPrivileges('hidden'), true);
    });

    test('inactive has no privileges', () {
      expect(hasMemberPrivileges('inactive'), false);
    });

    test('pending has no privileges', () {
      expect(hasMemberPrivileges('pending'), false);
    });

    test('unrecognised status has no privileges', () {
      expect(hasMemberPrivileges('bogus'), false);
    });
  });
}
