import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/app_bottom_nav.dart';

void main() {
  test('practitioner tabs put My Gym in the third slot and drop report', () {
    expect(kPracTabs, ['home', 'search', 'mygym', 'profile']);
    expect(kPracTabs.length, 4, reason: 'the bar renders 2 tabs + FAB + 2 tabs');
    expect(kPracTabs.contains('report'), isFalse, reason: 'Report moved to Profile settings');
    expect(kPracTabs.contains('schedule'), isFalse);
  });
}
