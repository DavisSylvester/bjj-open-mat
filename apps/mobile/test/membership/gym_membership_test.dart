import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';

void main() {
  test('GymMembership.fromJson maps required fields', () {
    final m = GymMembership.fromJson(const {
      'id': 'm1', 'gymId': 'g1', 'userId': 'u1', 'status': 'hidden',
      'verifiedMember': true, 'gymRole': 'member', 'isHome': false,
      'visibleInRoster': true, 'joinMethod': 'self', 'joinedAt': 't',
    });
    expect(m.id, 'm1');
    expect(m.status, 'hidden');
    expect(m.gymRole, 'member');
  });

  test('GymMembership.fromJson defaults status to active when the field is absent (legacy doc)', () {
    final m = GymMembership.fromJson(const {
      'id': 'm1', 'gymId': 'g1', 'userId': 'u1',
      'verifiedMember': true, 'gymRole': 'member', 'isHome': false,
      'visibleInRoster': true, 'joinMethod': 'self', 'joinedAt': 't',
    });
    expect(m.status, 'active');
  });
}
