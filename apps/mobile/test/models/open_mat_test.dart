import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

void main() {
  test('parses giType and attendeeCount', () {
    final om = OpenMat.fromJson({
      'id': 'om-1', 'gymId': 'g-1', 'title': 'Fri', 'startTime': '19:00', 'endTime': '21:00',
      'skillLevel': 'all', 'giType': 'nogi', 'attendeeCount': 3,
    });
    expect(om.giType, 'nogi');
    expect(om.attendeeCount, 3);
    expect(om.giBadge, 'No-Gi');
  });
}
