import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/models/gym_class.dart';

void main() {
  group('GymClass.fromJson', () {
    Map<String, dynamic> baseJson() => {
          'id': 'cls-1',
          'gymId': 'gym-1',
          'title': 'Morning Gi',
          'classType': 'gi',
          'giType': 'gi',
          'skillLevel': 'all',
          'isRecurring': true,
          'startTime': '06:00',
          'endTime': '07:30',
          'status': 'active',
        };

    test('parses dayOfWeek int and preserves value', () {
      final json = baseJson()..['dayOfWeek'] = 1;
      final gymClass = GymClass.fromJson(json);
      expect(gymClass.dayOfWeek, equals(1));
    });

    test('dayOfWeek is null when absent from JSON', () {
      final gymClass = GymClass.fromJson(baseJson());
      expect(gymClass.dayOfWeek, isNull);
    });

    test('parses dayOfWeek 0 (Sunday) correctly', () {
      final json = baseJson()..['dayOfWeek'] = 0;
      final gymClass = GymClass.fromJson(json);
      expect(gymClass.dayOfWeek, equals(0));
    });

    test('parses dayOfWeek 6 (Saturday) correctly', () {
      final json = baseJson()..['dayOfWeek'] = 6;
      final gymClass = GymClass.fromJson(json);
      expect(gymClass.dayOfWeek, equals(6));
    });
  });
}
