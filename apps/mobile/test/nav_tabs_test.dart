import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/app_bottom_nav.dart';

void main() {
  test('practitioner tabs drop schedule and end with report', () {
    expect(kPracTabs.contains('schedule'), isFalse);
    expect(kPracTabs.last, 'report');
    expect(kPracTabs.indexOf('profile'), 2);
    expect(kPracTabs.length, 4);
  });
}
