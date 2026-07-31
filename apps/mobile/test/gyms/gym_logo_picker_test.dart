import 'dart:typed_data';

import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/widgets/gym_logo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGymRepository implements GymRepository {
  _FakeGymRepository({this.uploadResult, this.uploadError});

  String? uploadResult;
  Object? uploadError;
  int uploadCalls = 0;
  String? lastContentType;

  @override
  Future<String> uploadLogo(Uint8List bytes, String contentType) async {
    uploadCalls += 1;
    lastContentType = contentType;
    if (uploadError != null) throw uploadError!;
    return uploadResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required GymRepository repo,
  required void Function(String) onUploaded,
  String? existingLogoUrl,
  void Function(bool)? onUploadingChanged,
  void Function(String)? onError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gymRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(
          body: GymLogoPicker(
            onUploaded: onUploaded,
            onUploadingChanged: onUploadingChanged,
            onError: onError,
            existingLogoUrl: existingLogoUrl,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders a tappable dropzone', (tester) async {
    await _pump(tester, repo: _FakeGymRepository(uploadResult: 'x'), onUploaded: (_) {});
    expect(find.byKey(const Key('gym-logo-picker')), findsOneWidget);
  });

  testWidgets('a successful upload reports the url and clears uploading', (tester) async {
    final repo = _FakeGymRepository(uploadResult: 'https://cdn/logo.jpg');
    String? uploaded;
    final uploadingStates = <bool>[];
    await _pump(
      tester,
      repo: repo,
      onUploaded: (u) => uploaded = u,
      onUploadingChanged: uploadingStates.add,
    );

    final state = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await state.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pump();

    expect(uploaded, 'https://cdn/logo.jpg');
    expect(repo.uploadCalls, 1);
    expect(repo.lastContentType, 'image/jpeg');
    expect(uploadingStates, [true, false]);
  });

  testWidgets('a failed upload reports an error and stops uploading', (tester) async {
    final repo = _FakeGymRepository(uploadError: StateError('nope'));
    String? uploaded;
    String? error;
    final uploadingStates = <bool>[];
    await _pump(
      tester,
      repo: repo,
      onUploaded: (u) => uploaded = u,
      onUploadingChanged: uploadingStates.add,
      onError: (m) => error = m,
    );

    final state = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await state.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pump();

    expect(uploaded, isNull, reason: 'a failed upload must not report a url');
    expect(error, isNotNull);
    expect(uploadingStates, [true, false],
        reason: 'uploading must be cleared on failure or the parent stays disabled forever');
  });

  testWidgets(
      'a retry after a failed upload signals uploading-start again, so a '
      'caller that clears its error on that signal ends up with no stale error',
      (tester) async {
    // Mirrors the add_gym_screen.dart call site pattern:
    //   onUploadingChanged: (up) => setState(() {
    //     _uploadingLogo = up;
    //     if (up) _error = null;
    //   }),
    //   onError: (m) => setState(() => _error = m),
    // A caller that clears its own error flag whenever `up == true` must end
    // up with no visible error after a failed attempt is followed by a
    // successful retry.
    final repo = _FakeGymRepository(uploadError: StateError('nope'));
    String? uploaded;
    String? error;
    await _pump(
      tester,
      repo: repo,
      onUploaded: (u) => uploaded = u,
      onUploadingChanged: (up) {
        if (up) error = null;
      },
      onError: (m) => error = m,
    );

    final state = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));

    // First attempt fails: error is set.
    await state.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pump();
    expect(error, isNotNull, reason: 'sanity check: the first attempt must fail');

    // Retry succeeds: the widget must signal uploading=true again at the
    // start of the new attempt, giving the caller its chance to clear the
    // stale error before the success callback lands.
    repo.uploadError = null;
    repo.uploadResult = 'https://cdn/logo2.jpg';
    await state.uploadBytes(Uint8List.fromList([4, 5, 6]));
    await tester.pump();

    expect(uploaded, 'https://cdn/logo2.jpg');
    expect(error, isNull, reason: 'a stale error from a prior failed attempt must not survive a successful retry');
  });
}
