import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _dayOfWeek = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  String _skillLevel = 'all';
  bool _isGi = false;
  bool _isRecurring = true;
  int? _maxParticipants;
  bool _isSaving = false;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _levels = ['all', 'beginner', 'intermediate', 'advanced'];

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.openMats, data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'dayOfWeek': _dayOfWeek,
        'startTime': _fmtTime(_startTime),
        'endTime': _fmtTime(_endTime),
        'skillLevel': _skillLevel,
        'isGiSession': _isGi,
        'isRecurring': _isRecurring,
        'maxParticipants': _maxParticipants ?? 0,
      });
      HapticFeedback.heavyImpact();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session created!'))); context.go('/owner/sessions'); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Open Mat')),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.lg),
        children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Session Title *')),
          const SizedBox(height: StitchTokens.md),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: StitchTokens.lg),

          // Day of week
          Text('Day of Week', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(spacing: 6, children: List.generate(7, (i) => ChoiceChip(
            label: Text(_days[i]),
            selected: _dayOfWeek == i,
            onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _dayOfWeek = i); },
          ))),
          const SizedBox(height: StitchTokens.md),

          // Time
          Row(children: [
            Expanded(child: ListTile(title: const Text('Start'), subtitle: Text(_fmtTime(_startTime)), onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _startTime);
              if (t != null) setState(() => _startTime = t);
            })),
            Expanded(child: ListTile(title: const Text('End'), subtitle: Text(_fmtTime(_endTime)), onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _endTime);
              if (t != null) setState(() => _endTime = t);
            })),
          ]),
          const SizedBox(height: StitchTokens.md),

          // Skill level
          Text('Skill Level', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(spacing: 6, children: _levels.map((l) => ChoiceChip(
            label: Text(l[0].toUpperCase() + l.substring(1)),
            selected: _skillLevel == l,
            onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _skillLevel = l); },
          )).toList()),
          const SizedBox(height: StitchTokens.md),

          // Toggles
          SwitchListTile(title: const Text('Gi Session'), value: _isGi, onChanged: (v) => setState(() => _isGi = v)),
          SwitchListTile(title: const Text('Recurring Weekly'), value: _isRecurring, onChanged: (v) => setState(() => _isRecurring = v)),
          const SizedBox(height: StitchTokens.xl),

          SizedBox(height: 52, child: ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Session'))),
        ],
      ),
    );
  }
}
