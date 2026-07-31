import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `add_gym_screen.dart` has no widget-test harness (nothing currently pumps
/// the whole screen), so the `GymLogoPicker` callback wiring at the call site
/// can't be exercised end-to-end from a widget test. This is a source-level
/// regression guard: it fails loudly if a future edit removes the
/// `onUploadingChanged` error-clearing logic, so a stale "Logo upload
/// failed…" message can't silently start persisting across a successful
/// retry again. See gym_logo_picker_test.dart for the behavioral half of
/// this contract (the widget re-signals uploading=true on every attempt).
void main() {
  test('GymLogoPicker call site clears the stale error when a new upload starts', () {
    final file = File(
      '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}features'
      '${Platform.pathSeparator}admin${Platform.pathSeparator}screens${Platform.pathSeparator}add_gym_screen.dart',
    );
    expect(file.existsSync(), isTrue, reason: 'expected to find add_gym_screen.dart at ${file.path}');
    final source = file.readAsStringSync();

    final pickerCallIndex = source.indexOf('GymLogoPicker(');
    expect(pickerCallIndex, isNot(-1), reason: 'add_gym_screen.dart must still construct a GymLogoPicker');

    final onUploadingChangedIndex = source.indexOf('onUploadingChanged:', pickerCallIndex);
    expect(onUploadingChangedIndex, isNot(-1),
        reason: 'GymLogoPicker call site must wire onUploadingChanged');

    // Look at the onUploadingChanged callback body specifically (up to the
    // next named callback argument) so this assertion targets the right
    // clause and not some unrelated part of the file.
    final onErrorIndex = source.indexOf('onError:', onUploadingChangedIndex);
    expect(onErrorIndex, isNot(-1));
    final callbackBody = source.substring(onUploadingChangedIndex, onErrorIndex);

    expect(
      callbackBody.contains('_error = null'),
      isTrue,
      reason: 'onUploadingChanged must clear _error when a new upload starts '
          '(if (up) _error = null), otherwise a stale "Logo upload failed…" '
          'message survives a successful retry.',
    );
  });
}
