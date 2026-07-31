import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';
import 'package:bjj_open_mat/features/mygym/data/next_up.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduledClass _c({required String date, required String startTime, String title = 'Gi'}) =>
    ScheduledClass(
      classId: '$date-$startTime',
      gymId: 'g1',
      date: date,
      title: title,
      classType: 'gi',
      giType: 'gi',
      skillLevel: 'all',
      startTime: startTime,
      endTime: '20:00',
      status: 'scheduled',
      goingCount: 0,
    );

void main() {
  group('classStartsAt', () {
    test('combines a plain date with HH:mm', () {
      expect(classStartsAt(_c(date: '2026-08-01', startTime: '18:30')),
          DateTime(2026, 8, 1, 18, 30));
    });

    test('tolerates a full ISO timestamp in date', () {
      expect(classStartsAt(_c(date: '2026-08-01T00:00:00.000Z', startTime: '06:05')),
          DateTime(2026, 8, 1, 6, 5));
    });

    test('returns null for an unparseable value rather than throwing', () {
      expect(classStartsAt(_c(date: 'not-a-date', startTime: '18:30')), isNull);
      expect(classStartsAt(_c(date: '2026-08-01', startTime: 'nope')), isNull);
    });
  });

  group('nextUpcoming', () {
    final now = DateTime(2026, 8, 1, 12, 0);

    test('returns the soonest class at or after now', () {
      final result = nextUpcoming([
        _c(date: '2026-08-02', startTime: '10:00', title: 'Later'),
        _c(date: '2026-08-01', startTime: '18:00', title: 'Soonest'),
        _c(date: '2026-08-01', startTime: '06:00', title: 'Already past'),
      ], now);
      expect(result?.title, 'Soonest');
    });

    test('ignores classes that already started', () {
      final result = nextUpcoming([_c(date: '2026-08-01', startTime: '06:00')], now);
      expect(result, isNull);
    });

    test('includes a class starting exactly now', () {
      final result = nextUpcoming([_c(date: '2026-08-01', startTime: '12:00')], now);
      expect(result, isNotNull);
    });

    test('returns null for an empty schedule', () {
      expect(nextUpcoming(const [], now), isNull);
    });

    test('skips unparseable entries instead of throwing', () {
      final result = nextUpcoming([
        _c(date: 'garbage', startTime: '18:00'),
        _c(date: '2026-08-01', startTime: '18:00', title: 'Good'),
      ], now);
      expect(result?.title, 'Good');
    });
  });
}
