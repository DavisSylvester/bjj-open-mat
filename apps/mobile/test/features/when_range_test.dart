import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/search/data/when_range.dart';

void main() {
  test('thisWeekend spans the upcoming Sat..Sun', () {
    final r = WhenRange.thisWeekend(DateTime(2026, 7, 1)); // Wed
    expect(r.start.weekday, DateTime.saturday);
    expect(r.end.weekday, DateTime.sunday);
    expect(r.startIso, '2026-07-04');
    expect(r.endIso, '2026-07-05');
  });

  test('singleDay start==end', () {
    final r = WhenRange.singleDay(DateTime(2026, 7, 8)); // Wed
    expect(r.startIso, '2026-07-08');
    expect(r.endIso, '2026-07-08');
  });

  test('thisWeek is a 7-day window from the given day', () {
    final r = WhenRange.thisWeek(DateTime(2026, 7, 1));
    expect(r.startIso, '2026-07-01');
    expect(r.endIso, '2026-07-07');
  });
}
