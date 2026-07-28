import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';

void main() {
  test('RosterMember.fromJson maps role and verified flags', () {
    final r = RosterMember.fromJson(const {
      'userId': 'u1', 'name': 'Alice', 'beltRank': 'blue',
      'gymRole': 'coach', 'verifiedMember': true, 'hasProfile': true,
    });
    expect(r.userId, 'u1');
    expect(r.gymRole, 'coach');
    expect(r.verifiedMember, true);
    expect(r.beltRank, 'blue');
  });
}
