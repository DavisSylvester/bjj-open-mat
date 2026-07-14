// apps/mobile/test/training_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/training/data/training_stats.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

CheckIn ci(String date, {String? gym, int? rounds}) => CheckIn.fromJson({
      'id': date + (gym ?? ''),
      'sessionDate': date,
      'checkedInAt': date,
      if (gym != null) 'gymId': gym,
      if (rounds != null) 'rounds': rounds,
    });

void main() {
  // 2026-07-14 is a Tuesday; week starts Monday 2026-07-13.
  final now = DateTime(2026, 7, 14);

  test('empty list yields zeros', () {
    final s = computeTrainingStats(const [], totalMats: 0, now: now);
    expect(s.mats, 0);
    expect(s.gyms, 0);
    expect(s.rounds, 0);
    expect(s.streakWeeks, 0);
  });

  test('mats uses envelope total, gyms distinct, rounds summed with null-safe', () {
    final s = computeTrainingStats([
      ci('2026-07-13', gym: 'g1', rounds: 5),
      ci('2026-07-10', gym: 'g1'),
      ci('2026-07-08', gym: 'g2', rounds: 3),
    ], totalMats: 47, now: now);
    expect(s.mats, 47);
    expect(s.gyms, 2);
    expect(s.rounds, 8);
  });

  test('streak counts consecutive weeks ending at current week', () {
    final s = computeTrainingStats([
      ci('2026-07-13'), // this week
      ci('2026-07-08'), // last week
      ci('2026-06-30'), // two weeks ago
    ], totalMats: 3, now: now);
    expect(s.streakWeeks, 3);
  });

  test('current week without a check-in does not break a streak from last week', () {
    final s = computeTrainingStats([
      ci('2026-07-08'), // last week
      ci('2026-06-30'), // two weeks ago
    ], totalMats: 2, now: now);
    expect(s.streakWeeks, 2);
  });

  test('a gap week breaks the streak', () {
    final s = computeTrainingStats([
      ci('2026-07-13'), // this week
      ci('2026-06-30'), // two weeks ago (last week missing)
    ], totalMats: 2, now: now);
    expect(s.streakWeeks, 1);
  });

  test('unparseable sessionDate is ignored for streak', () {
    final s = computeTrainingStats([ci('garbage', gym: 'g1', rounds: 2)], totalMats: 1, now: now);
    expect(s.streakWeeks, 0);
    expect(s.rounds, 2);
  });
}
