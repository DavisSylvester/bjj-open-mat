import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

OpenMat _mat({String? specificDate, int? dayOfWeek}) => OpenMat(
      id: 'm1', gymId: 'g1', title: 't',
      startTime: '18:00', endTime: '20:00',
      specificDate: specificDate, dayOfWeek: dayOfWeek,
    );

void main() {
  test('one-off session returns the specific date (date part only)', () {
    final m = _mat(specificDate: '2026-08-01T00:00:00.000Z');
    expect(m.nextSessionDate(from: DateTime(2026, 7, 1)), '2026-08-01');
  });

  test('recurring session returns the next matching weekday', () {
    // dayOfWeek 3 == Wednesday (0=Sun..6=Sat)
    final m = _mat(dayOfWeek: 3);
    final result = m.nextSessionDate(from: DateTime(2026, 7, 6)); // a Monday
    final parsed = DateTime.parse(result);
    expect(parsed.weekday, DateTime.wednesday);
    expect(parsed.isBefore(DateTime(2026, 7, 6)), false);
  });

  test('returns YYYY-MM-DD format', () {
    final m = _mat(dayOfWeek: 0);
    expect(m.nextSessionDate(from: DateTime(2026, 7, 6)).length, 10);
  });
}
