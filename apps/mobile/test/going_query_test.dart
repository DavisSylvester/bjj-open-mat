import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/data/rsvp_repository.dart';

void main() {
  test('GoingQuery value equality + hashCode', () {
    const a = GoingQuery('m1', '2026-08-01');
    const b = GoingQuery('m1', '2026-08-01');
    const c = GoingQuery('m1', '2026-08-02');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
  });
}
