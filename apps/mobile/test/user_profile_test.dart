import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';

void main() {
  UserProfile p(String id, {String? auth0Id, String? birthday}) => UserProfile(
        id: id, auth0Id: auth0Id, email: 'x@y.io', displayName: 'X', birthday: birthday,
      );

  test('isSocial from provider subject', () {
    expect(p('google-oauth2|1', auth0Id: 'google-oauth2|1').isSocial, true);
    expect(p('auth0|1', auth0Id: 'auth0|1').isSocial, false);
    expect(p('test-user@local.priv').isSocial, false);
  });

  test('birthday round-trips through json', () {
    final u = UserProfile.fromJson({'id': 'a', 'email': 'x@y.io', 'displayName': 'X', 'birthday': '1990-01-05'});
    expect(u.birthday, '1990-01-05');
    expect(u.toJson()['birthday'], '1990-01-05');
  });
}
