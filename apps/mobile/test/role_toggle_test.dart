import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/settings/role_toggle.dart';

void main() {
  test('practitioner toggles to gym_owner', () {
    final t = roleToggle('practitioner');
    expect(t.targetRole, 'gym_owner');
    expect(t.label, 'Switch to Gym Owner');
    expect(t.destination, '/owner/dashboard');
  });

  test('gym_owner toggles to practitioner', () {
    final t = roleToggle('gym_owner');
    expect(t.targetRole, 'practitioner');
    expect(t.label, 'Switch to Practitioner');
    expect(t.destination, '/');
  });

  test('null/unknown role defaults to becoming a gym owner', () {
    expect(roleToggle(null).targetRole, 'gym_owner');
    expect(roleToggle('admin').targetRole, 'gym_owner');
  });
}
