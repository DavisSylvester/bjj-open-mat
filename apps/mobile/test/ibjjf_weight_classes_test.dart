import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/reference/ibjjf_weight_classes.dart';

void main() {
  test('male gi feather max is 70 kg', () {
    final row = divisionsFor('male', 'gi').firstWhere((r) => r.division == 'feather');
    expect(row.maxKg, 70);
  });

  test('female gi list has 8 divisions incl. heavy and no ultra_heavy', () {
    final list = divisionsFor('female', 'gi');
    expect(list.length, 8);
    expect(list.any((r) => r.division == 'heavy'), true);
    expect(list.any((r) => r.division == 'ultra_heavy'), false);
  });
}
