import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';

void main() {
  test('GymClaim.fromJson parses fields and status', () {
    final c = GymClaim.fromJson({
      'id': 'c1',
      'gymId': 'g1',
      'claimantId': 'u1',
      'kind': 'transfer',
      'relationship': 'owner',
      'contact': 'me@gym.com',
      'message': 'mine',
      'status': 'pending',
      'createdAt': '2026-07-30T00:00:00.000Z',
    });
    expect(c.id, 'c1');
    expect(c.kind, 'transfer');
    expect(c.status, 'pending');
  });

  test('AdminGymClaim.fromJson parses nested gym + claimant', () {
    final a = AdminGymClaim.fromJson({
      'claim': {
        'id': 'c1', 'gymId': 'g1', 'claimantId': 'u1', 'kind': 'claim',
        'relationship': 'owner', 'contact': 'me@gym.com', 'message': 'mine',
        'status': 'pending', 'createdAt': '2026-07-30T00:00:00.000Z',
      },
      'gymName': 'Alliance',
      'gymPhone': '555-1212',
      'gymWebsite': 'alliance.com',
      'claimantEmail': 'me@gym.com',
    });
    expect(a.claim.id, 'c1');
    expect(a.gymName, 'Alliance');
    expect(a.gymPhone, '555-1212');
    expect(a.claimantEmail, 'me@gym.com');
  });
}
