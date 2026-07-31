import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/app_bottom_nav.dart';

void main() {
  test('practitioner tabs put My Gym third, drop report, and end with messages', () {
    expect(kPracTabs, ['home', 'search', 'mygym', 'profile', 'messages']);
    expect(kPracTabs.length, 5, reason: 'the bar renders 2 tabs + FAB + 3 tabs');
    expect(kPracTabs.last, 'messages');
    expect(kPracTabs.indexOf('mygym'), 2);
    expect(kPracTabs.contains('report'), isFalse, reason: 'Report moved to Profile settings');
    expect(kPracTabs.contains('schedule'), isFalse);
  });
}
