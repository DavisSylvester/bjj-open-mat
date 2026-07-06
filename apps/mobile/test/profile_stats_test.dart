import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/profile/data/profile_stats.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

void main() {
  test('computeProfileStats counts check-ins, reviews, distinct gyms', () {
    final list = [
      CheckIn.fromJson({'id': '1', 'checkedInAt': '2026-07-01', 'gymId': 'g1', 'rating': 5}),
      CheckIn.fromJson({'id': '2', 'checkedInAt': '2026-07-02', 'gymId': 'g1'}),
      CheckIn.fromJson({'id': '3', 'checkedInAt': '2026-07-03', 'gymId': 'g2', 'rating': 4}),
    ];
    final s = computeProfileStats(list);
    expect(s.checkIns, 3);
    expect(s.reviews, 2);
    expect(s.gyms, 2);
  });

  test('ageFromBirthday computes years', () {
    expect(ageFromBirthday('1990-01-05', now: DateTime(2026, 7, 6)), 36);
    expect(ageFromBirthday('2000-12-31', now: DateTime(2026, 7, 6)), 25);
    expect(ageFromBirthday('bad'), null);
  });
}
