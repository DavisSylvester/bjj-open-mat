import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';

void main() {
  test('ClassJournalEntry.fromJson maps fields + tags', () {
    final e = ClassJournalEntry.fromJson(const {
      'id': 'j1', 'classId': 'c1', 'gymId': 'g1', 'userId': 'u1', 'date': '2026-08-03',
      'whatWasTaught': 'guard passing', 'techniqueTags': ['armbar', 'triangle'],
      'intensity': 4, 'shared': true,
    });
    expect(e.classId, 'c1');
    expect(e.techniqueTags, ['armbar', 'triangle']);
    expect(e.shared, true);
    expect(e.intensity, 4);
  });
}
