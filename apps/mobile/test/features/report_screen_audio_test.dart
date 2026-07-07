import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
}
