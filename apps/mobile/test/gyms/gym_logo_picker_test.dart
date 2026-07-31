import 'dart:typed_data';

import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/widgets/gym_logo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGymRepository implements GymRepository {
  _FakeGymRepository({this.uploadResult, this.uploadError});

  final String? uploadResult;
  final Object? uploadError;
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
}
