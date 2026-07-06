import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/attendee.dart';

void main() {
  test('Attendee.fromJson parses fields', () {
    final a = Attendee.fromJson({
      'userId': 'u1',
      'name': 'Alex',
      'beltRank': 'blue',
      'beltStripes': 3,
      'avatarUrl': 'https://x/y.png',
    });
    expect(a.userId, 'u1');
    expect(a.name, 'Alex');
    expect(a.beltRank, 'blue');
    expect(a.beltStripes, 3);
    expect(a.avatarUrl, 'https://x/y.png');
  });

  test('Attendee.fromJson tolerates missing optional fields', () {
    final a = Attendee.fromJson({'userId': 'u2', 'name': 'Sam'});
    expect(a.beltRank, 'white');
    expect(a.beltStripes, 0);
    expect(a.avatarUrl, isNull);
  });
}
