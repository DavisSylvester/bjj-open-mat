import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_sessions_provider.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

void main() {
  test('sessionRowFromOpenMat maps fields for SessionRow', () {
    final m = OpenMat.fromJson({
      'id': 'om1',
      'gymId': 'g1',
      'title': 'Sunday Open Mat',
      'gymName': 'Atos HQ',
      'giType': 'nogi',
      'skillLevel': 'advanced',
      'dayOfWeek': 0,
      'startTime': '10:00',
      'endTime': '12:00',
      'feeCents': 1000,
      'status': 'scheduled',
      'verified': true,
    });
    final row = sessionRowFromOpenMat(m);
    expect(row.id, 'om1');
    expect(row.gymName, 'Atos HQ');
    expect(row.giType, 'nogi');
    expect(row.expLevel, 'adv');
    expect(row.fee, 10.0);
    expect(row.distance, '');
  });
}
