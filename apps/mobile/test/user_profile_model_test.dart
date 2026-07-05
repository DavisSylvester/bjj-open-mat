import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';

void main() {
  test('UserProfile round-trips the new profile fields', () {
    final json = {
      'id': 'u1',
      'email': 'a@b.co',
      'displayName': 'A',
      'city': 'Austin',
      'state': 'TX',
      'gender': 'male',
      'weightValue': 172.0,
      'weightUnit': 'lb',
      'weightDivision': 'light',
      'weightDivisionContext': 'nogi',
    };
    final p = UserProfile.fromJson(json);
    expect(p.city, 'Austin');
    expect(p.state, 'TX');
    expect(p.gender, 'male');
    expect(p.weightValue, 172.0);
    expect(p.weightUnit, 'lb');
    expect(p.weightDivision, 'light');
    expect(p.weightDivisionContext, 'nogi');
    expect(p.toJson()['city'], 'Austin');
    expect(p.toJson()['weightDivision'], 'light');
  });
}
