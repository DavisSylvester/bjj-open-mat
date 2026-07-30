import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/app_bottom_nav.dart';

void main() {
  test('practitioner tabs include messages as the last entry', () {
    expect(kPracTabs.contains('schedule'), isFalse);
    expect(kPracTabs.last, 'messages');
    expect(kPracTabs.indexOf('profile'), 2);
    expect(kPracTabs.indexOf('report'), 3);
    expect(kPracTabs.length, 5);
  });
}
