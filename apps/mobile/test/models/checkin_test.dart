import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

void main() {
  test('parses gps + flag + log fields', () {
    final c = CheckIn.fromJson({
      'id': 'c1', 'openMatId': 'om1', 'userId': 'u1', 'sessionDate': '2026-06-22', 'checkedInAt': 't',
      'latitude': 32.9, 'longitude': -117.2, 'locationStatus': 'verified', 'distanceM': 120.5,
      'gymCity': 'San Diego', 'note': 'good', 'rounds': 5, 'intensity': 4, 'partners': 2,
    });
    expect(c.latitude, 32.9);
    expect(c.locationStatus, 'verified');
    expect(c.rounds, 5);
    expect(c.gymCity, 'San Diego');
    final d = CheckIn.fromJson({'id': 'c2', 'openMatId': 'o', 'userId': 'u', 'sessionDate': 'd', 'checkedInAt': 't'});
    expect(d.locationStatus, 'no_location'); // default
    expect(d.rounds, isNull);
  });
}
