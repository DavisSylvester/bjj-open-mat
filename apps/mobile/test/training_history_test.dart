import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/training/data/training_provider.dart';

void main() {
  test('formatSessionDate renders month + day', () {
    expect(formatSessionDate('2026-07-13'), 'Jul 13');
    expect(formatSessionDate('2026-01-02'), 'Jan 2');
  });

  test('formatSessionDate falls back to raw string when unparseable', () {
    expect(formatSessionDate('soon'), 'soon');
  });
}
