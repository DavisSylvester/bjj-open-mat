import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/data/api_exception.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/report/data/report_audio_repository.dart';
import 'package:bjj_open_mat/features/report/data/report_repository.dart';
import 'package:bjj_open_mat/features/report/models/report.dart';
import 'package:bjj_open_mat/features/report/screens/report_screen.dart';

class _FakeAudioRepo implements ReportAudioRepository {
  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String c) async =>
      (uploadUrl: 'u', audioKey: 'reports/audio/u/a.m4a');
  @override
  Future<void> putAudio(String u, dynamic f, String c) async {}
  @override
  Future<({String text, int durationMs})> transcribe(String k) async =>
      (text: 'transcribed text', durationMs: 1000);
}

/// Transcribe fails with a 503 / service_unavailable (transcription not configured).
class _ServiceUnavailableAudioRepo implements ReportAudioRepository {
  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String c) async =>
      (uploadUrl: 'u', audioKey: 'reports/audio/u/x.m4a');
  @override
  Future<void> putAudio(String u, dynamic f, String c) async {}
  @override
  Future<({String text, int durationMs})> transcribe(String k) async =>
      throw const ApiException(
        code: 'service_unavailable',
        message: 'Voice transcription is not configured',
        status: 503,
      );
}

/// Transcribe fails with a generic (non-503) error.
class _GenericFailureAudioRepo implements ReportAudioRepository {
  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String c) async =>
      (uploadUrl: 'u', audioKey: 'reports/audio/u/x.m4a');
  @override
  Future<void> putAudio(String u, dynamic f, String c) async {}
  @override
  Future<({String text, int durationMs})> transcribe(String k) async =>
      throw const ApiException(
        code: 'internal_error',
        message: 'boom',
        status: 500,
      );
}

class _CapturingReportRepo implements ReportRepository {
  List<String>? lastAudioKeys;
  @override
  Future<Report> create({
    required String type,
    required String title,
    required String description,
    List<String> audioKeys = const [],
  }) async {
    lastAudioKeys = audioKeys;
    return Report(id: 'r1', userId: 'u', type: type, title: title, description: description, status: 'open');
  }

  @override
  Future<List<Report>> listMine() async => [];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('spoken text appends to description and submit carries audioKeys', (tester) async {
    final capture = _CapturingReportRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportAudioRepositoryProvider.overrideWithValue(_FakeAudioRepo()),
        reportRepositoryProvider.overrideWithValue(capture),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const ReportScreen()),
    ));
    // Drive the recording seam directly (test hook exposed on the state).
    final state = tester.state<ReportScreenStateForTest>(find.byType(ReportScreen));
    await state.debugSimulateRecordingWithKey('reports/audio/u/a.m4a');
    await tester.pump();
    expect(find.textContaining('transcribed text'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('report-title')), 'A valid title');
    await state.debugSubmit();
    expect(capture.lastAudioKeys, ['reports/audio/u/a.m4a']);
  });

  testWidgets('503 transcription failure shows the "not available" message', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportAudioRepositoryProvider.overrideWithValue(_ServiceUnavailableAudioRepo()),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const ReportScreen()),
    ));
    final state = tester.state<ReportScreenStateForTest>(find.byType(ReportScreen));
    await state.debugSimulateRecordingWithKey('reports/audio/u/x.m4a');
    await tester.pump();

    expect(find.textContaining("isn't available"), findsOneWidget);
    expect(find.textContaining('Could not transcribe'), findsNothing);
  });

  testWidgets('non-503 transcription failure shows the generic message', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportAudioRepositoryProvider.overrideWithValue(_GenericFailureAudioRepo()),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const ReportScreen()),
    ));
    final state = tester.state<ReportScreenStateForTest>(find.byType(ReportScreen));
    await state.debugSimulateRecordingWithKey('reports/audio/u/x.m4a');
    await tester.pump();

    expect(find.textContaining('Could not transcribe'), findsOneWidget);
    expect(find.textContaining("isn't available"), findsNothing);
  });
}
