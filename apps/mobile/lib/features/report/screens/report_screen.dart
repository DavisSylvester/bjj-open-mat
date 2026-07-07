import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:record/record.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/report_audio_repository.dart';
import '../data/report_repository.dart';

/// Recording lifecycle for the voice-note capture on this screen.
enum RecordState { idle, recording, transcribing, error }

/// Exposes the private state to widget tests without making it public API.
///
/// Widget tests can't drive the real `record` plugin (no native audio
/// pipeline in the test harness), so the screen offers `@visibleForTesting`
/// seams that exercise the same repository calls a real recording would.
@visibleForTesting
typedef ReportScreenStateForTest = _ReportScreenState;

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'bug';
  bool _saving = false;
  bool _done = false;
  String? _error;

  final List<String> _audioKeys = [];
  RecordState _rec = RecordState.idle;
  String? _recordError;
  AudioRecorder? _recorder;
  Timer? _autoStopTimer;
  Timer? _tickTimer;
  int _recordSeconds = 0;

  static const _maxRecordSeconds = 120;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onChanged);
    _descCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tickTimer?.cancel();
    _autoStopTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canSubmit =>
      !_saving &&
      _titleCtrl.text.trim().length >= 3 &&
      _descCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(reportRepositoryProvider).create(
            type: _type,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            audioKeys: _audioKeys,
          );
      if (mounted) {
        setState(() {
          _saving = false;
          _done = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _titleCtrl.clear();
      _descCtrl.clear();
      _type = 'bug';
      _done = false;
      _error = null;
      _audioKeys.clear();
      _rec = RecordState.idle;
      _recordError = null;
    });
  }

  Future<void> _toggleRecording() async {
    if (_rec == RecordState.recording) {
      await _stopRecording();
    } else if (_rec == RecordState.idle || _rec == RecordState.error) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final recorder = _recorder ??= AudioRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      setState(() {
        _rec = RecordState.error;
        _recordError = 'Microphone permission is required to record.';
      });
      return;
    }
    final path =
        '${Directory.systemTemp.path}/report_audio_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _rec = RecordState.recording;
      _recordError = null;
      _recordSeconds = 0;
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
    });
    _autoStopTimer = Timer(const Duration(seconds: _maxRecordSeconds), () {
      _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final recorder = _recorder;
    if (recorder == null || _rec != RecordState.recording) return;
    final path = await recorder.stop();
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _rec = RecordState.error;
        _recordError = 'Recording failed. Please try again.';
      });
      return;
    }
    setState(() => _rec = RecordState.transcribing);
    await _uploadAndTranscribe(File(path));
  }

  Future<void> _uploadAndTranscribe(File file) async {
    try {
      final audio = ref.read(reportAudioRepositoryProvider);
      final pre = await audio.presignUpload('audio/mp4');
      await audio.putAudio(pre.uploadUrl, file, 'audio/mp4');
      final t = await audio.transcribe(pre.audioKey);
      _appendTranscript(t.text, pre.audioKey);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rec = RecordState.error;
        _recordError = 'Could not transcribe your recording. You can still type the description.';
      });
    }
  }

  void _appendTranscript(String text, String audioKey) {
    if (!mounted) return;
    setState(() {
      final sep = _descCtrl.text.trim().isEmpty ? '' : '\n\n';
      _descCtrl.text = '${_descCtrl.text}$sep${text.trim()}';
      _audioKeys.add(audioKey);
      _rec = RecordState.idle;
      _recordError = null;
    });
  }

  /// Test seam: exercises the transcribe→append path against whatever
  /// [reportAudioRepositoryProvider] resolves to in the widget tree (a fake
  /// in tests), without touching the real microphone/recorder plugin.
  @visibleForTesting
  Future<void> debugSimulateRecordingWithKey(String key) async {
    setState(() => _rec = RecordState.transcribing);
    try {
      final audio = ref.read(reportAudioRepositoryProvider);
      final t = await audio.transcribe(key);
      _appendTranscript(t.text, key);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rec = RecordState.error;
        _recordError = 'Could not transcribe your recording. You can still type the description.';
      });
    }
  }

  /// Test seam: drives the same submit path the Submit button uses.
  @visibleForTesting
  Future<void> debugSubmit() => _submit();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: _done ? _buildSuccess(t) : _buildForm(t),
      ),
    );
  }

  Widget _buildSuccess(AppTokens t) {
    final label = _type == 'bug' ? 'bug report' : 'feature request';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle2, size: 56, color: t.green),
            const SizedBox(height: 16),
            Text(
              'Thanks — we filed your $label.',
              textAlign: TextAlign.center,
              style: t.h2Style,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _reset();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                minimumSize: const Size(160, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
              ),
              child: Text('Done', style: t.h2Style.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppTokens t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report', style: t.h1Style),
          const SizedBox(height: 20),
          Text('WHAT KIND OF REPORT', style: t.labelStyle),
          const SizedBox(height: 8),
          Row(children: [
            _typeChip(t, 'bug', 'Bug', LucideIcons.bug),
            const SizedBox(width: 10),
            _typeChip(t, 'feature', 'Feature', LucideIcons.lightbulb),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TITLE', style: t.labelStyle),
                const SizedBox(height: 8),
                _fieldBox(
                  t,
                  child: TextField(
                    key: const Key('report-title'),
                    controller: _titleCtrl,
                    style: t.bodyStyle,
                    decoration: InputDecoration(
                      hintText: 'Short summary',
                      hintStyle: t.bodyStyle.copyWith(color: t.faint),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DESCRIPTION', style: t.labelStyle),
                    _micButton(t),
                  ],
                ),
                const SizedBox(height: 8),
                _fieldBox(
                  t,
                  child: TextField(
                    controller: _descCtrl,
                    style: t.bodyStyle,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'What happened / what would you like?',
                      hintStyle: t.bodyStyle.copyWith(color: t.faint),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_rec == RecordState.recording || _rec == RecordState.transcribing) ...[
                  const SizedBox(height: 12),
                  _recordingPanel(t),
                ],
                if (_rec == RecordState.error && _recordError != null) ...[
                  const SizedBox(height: 12),
                  Text(_recordError!, style: t.bodyStyle.copyWith(color: t.red)),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.red.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: t.bodyStyle.copyWith(color: t.red)),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              disabledBackgroundColor: t.border,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Submit', style: t.h2Style.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(AppTokens t, String value, String label, IconData icon) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? t.primary : t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: selected ? t.primary : t.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : t.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: t.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : t.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _micButton(AppTokens t) {
    final recording = _rec == RecordState.recording;
    final busy = _rec == RecordState.transcribing;
    return IconButton(
      onPressed: busy ? null : _toggleRecording,
      icon: Icon(
        recording ? LucideIcons.micOff : LucideIcons.mic,
        color: recording ? t.red : t.muted,
      ),
      tooltip: recording ? 'Stop recording' : 'Record a voice note',
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _recordingPanel(AppTokens t) {
    final recording = _rec == RecordState.recording;
    final minutes = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceHi,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (recording)
            Icon(LucideIcons.mic, size: 18, color: t.red)
          else
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
            ),
          const SizedBox(width: 10),
          Text(
            recording ? '$minutes:$seconds' : 'Transcribing...',
            style: t.bodyStyle,
          ),
          const Spacer(),
          if (recording)
            TextButton(
              onPressed: _stopRecording,
              child: Text('Stop', style: t.bodyStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _fieldBox(AppTokens t, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceHi,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: child,
    );
  }
}
