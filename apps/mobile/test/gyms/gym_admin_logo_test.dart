import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/admin/screens/gym_admin_screen.dart').readAsStringSync();

  test('gym admin screen embeds the shared logo picker', () {
    expect(source, contains('GymLogoPicker'),
        reason: 'an existing gym has no other way to get a logo');
  });

  test('an uploaded logo is persisted through the update request', () {
    expect(source, contains("'logoUrl'"),
        reason: 'uploading without patching the gym would silently discard the logo');
  });

  test('save is blocked while a logo upload is in flight', () {
    expect(source, contains('_uploadingLogo'),
        reason: 'saving mid-upload persists a stale or empty logoUrl');
  });
}
