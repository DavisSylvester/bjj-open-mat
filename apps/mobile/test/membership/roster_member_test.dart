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

  test('RosterMember.fromJson leaves visibleInRoster null when absent (public roster)', () {
    final r = RosterMember.fromJson(const {
      'userId': 'u1', 'name': 'Alice', 'gymRole': 'member',
      'verifiedMember': true, 'hasProfile': true,
    });
    expect(r.visibleInRoster, isNull);
    expect(r.isSelfHidden, false);
  });

  test('RosterMember.fromJson parses visibleInRoster when present (manager roster)', () {
    final r = RosterMember.fromJson(const {
      'userId': 'u1', 'name': 'Alice', 'gymRole': 'member',
      'verifiedMember': true, 'hasProfile': true, 'status': 'active',
      'visibleInRoster': false,
    });
    expect(r.visibleInRoster, false);
    expect(r.isSelfHidden, true);
  });
}
