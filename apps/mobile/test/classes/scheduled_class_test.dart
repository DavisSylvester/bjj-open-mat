import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/models/scheduled_class.dart';

void main() {
  test('ScheduledClass.fromJson maps fields incl goingCount + status', () {
    final s = ScheduledClass.fromJson(const {
      'classId': 'c1', 'gymId': 'g1', 'date': '2026-08-03', 'title': 'Fundamentals',
      'classType': 'fundamentals', 'giType': 'gi', 'skillLevel': 'beginner',
      'startTime': '18:00', 'endTime': '19:00', 'status': 'scheduled', 'goingCount': 4,
    });
    expect(s.classId, 'c1');
    expect(s.status, 'scheduled');
    expect(s.goingCount, 4);
    expect(s.title, 'Fundamentals');
  });
}
