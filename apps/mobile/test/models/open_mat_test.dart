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

  test('parses verified and status with safe defaults', () {
    final m = OpenMat.fromJson({'id': 'x', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '21:00', 'verified': true, 'status': 'hidden'});
    expect(m.verified, isTrue);
    expect(m.status, 'hidden');
    final d = OpenMat.fromJson({'id': 'y', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '21:00'});
    expect(d.verified, isFalse);
    expect(d.status, 'live');
  });

  test('parses detail-only fields (city, state, feeCents, gymRating)', () {
    final m = OpenMat.fromJson({
      'id': 'om-atos', 'gymId': 'g', 'title': 'Friday Night', 'startTime': '19:00', 'endTime': '21:00',
      'skillLevel': 'all', 'giType': 'gi', 'city': 'San Diego', 'state': 'CA', 'feeCents': 1500, 'gymRating': 4.8,
    });
    expect(m.city, 'San Diego');
    expect(m.state, 'CA');
    expect(m.feeCents, 1500);
    expect(m.gymRating, 4.8);
    expect(m.locationLabel, 'San Diego, CA');
  });

  test('feeLabel formats cents as Free or dollars', () {
    OpenMat withFee(int? cents) => OpenMat.fromJson({
          'id': 'x', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '21:00',
          if (cents != null) 'feeCents': cents,
        });
    expect(withFee(0).feeLabel, 'Free');
    expect(withFee(null).feeLabel, 'Free');
    expect(withFee(1500).feeLabel, '\$15');
    expect(withFee(1250).feeLabel, '\$12.50');
  });

  test('12-hour time labels', () {
    final m = OpenMat.fromJson({'id': 'x', 'gymId': 'g', 'title': 'T', 'startTime': '19:00', 'endTime': '09:30'});
    expect(m.startLabel, '7:00 PM');
    expect(m.endLabel, '9:30 AM');
  });
}
