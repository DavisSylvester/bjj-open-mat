import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../data/class_repository.dart';
import '../models/gym_class.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/models/roster_member.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kClassTypes = [
  ('fundamentals', 'Fundamentals'),
  ('all_levels', 'All Levels'),
  ('advanced', 'Advanced'),
  ('gi', 'Gi'),
  ('nogi', 'No-Gi'),
  ('kids', 'Kids'),
  ('womens', "Women's"),
  ('competition', 'Competition'),
  ('private', 'Private'),
  ('other', 'Other'),
];

const _kGiTypes = [
  ('gi', 'Gi'),
  ('nogi', 'No-Gi'),
  ('both', 'Both'),
];

const _kSkillLevels = [
  ('all', 'All Levels'),
  ('beginner', 'Beginner'),
  ('intermediate', 'Intermediate'),
  ('advanced', 'Advanced'),
];

const _kDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Create or edit a [GymClass].
///
/// Pass [existing] to pre-populate the form for editing; omit it (or pass
/// null) to create a new class.
class ClassEditScreen extends ConsumerStatefulWidget {
  final String gymId;
  final GymClass? existing;

  const ClassEditScreen({
    super.key,
    required this.gymId,
    this.existing,
  });

  @override
  ConsumerState<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends ConsumerState<ClassEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _classTypeLabelCtrl = TextEditingController();
  final _instructorNameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  String _classType = 'gi';
  String _giType = 'gi';
  String _skillLevel = 'all';
  bool _isRecurring = true;
  int? _dayOfWeek; // 0=Mon … 6=Sun for recurring
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 30);
  DateTime? _specificDate; // one-off date

  // Instructor: roster picker vs free-text toggle.
  bool _useRosterInstructor = false;
  RosterMember? _selectedInstructor;

  bool _saving = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _classType = e.classType;
      _classTypeLabelCtrl.text = e.classTypeLabel ?? '';
      _giType = e.giType;
      _skillLevel = e.skillLevel;
      _isRecurring = e.isRecurring;
      if (e.dayOfWeek != null) {
        _dayOfWeek = int.tryParse(e.dayOfWeek!);
      }
      _startTime = _parseTime(e.startTime) ?? _startTime;
      _endTime = _parseTime(e.endTime) ?? _endTime;
      if (e.specificDate != null) {
        _specificDate = DateTime.tryParse(e.specificDate!);
      }
      if (e.instructorName != null) {
        _instructorNameCtrl.text = e.instructorName!;
      }
      if (e.capacity != null) {
        _capacityCtrl.text = e.capacity!.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _classTypeLabelCtrl.dispose();
    _instructorNameCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool get _isValid {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_isRecurring) return _dayOfWeek != null;
    return _specificDate != null;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _specificDate = picked);
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'classType': _classType,
        if (_classType == 'other' && _classTypeLabelCtrl.text.trim().isNotEmpty)
          'classTypeLabel': _classTypeLabelCtrl.text.trim(),
        'giType': _giType,
        'skillLevel': _skillLevel,
        'isRecurring': _isRecurring,
        if (_isRecurring && _dayOfWeek != null) 'dayOfWeek': _dayOfWeek,
        if (!_isRecurring && _specificDate != null)
          'specificDate': _fmtDate(_specificDate!),
        'startTime': _fmtTime(_startTime),
        'endTime': _fmtTime(_endTime),
        if (_useRosterInstructor && _selectedInstructor != null)
          'instructorUserId': _selectedInstructor!.userId,
        if (!_useRosterInstructor && _instructorNameCtrl.text.trim().isNotEmpty)
          'instructorName': _instructorNameCtrl.text.trim(),
        if (_capacityCtrl.text.trim().isNotEmpty)
          'capacity': int.tryParse(_capacityCtrl.text.trim()),
      };

      final repo = ref.read(classRepositoryProvider);
      final e = widget.existing;
      if (e != null) {
        await repo.update(e.id, body);
      } else {
        await repo.create(widget.gymId, body);
      }
      ref.invalidate(scheduleProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save class: $err")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        title: Text(isEdit ? 'Edit Class' : 'New Class', style: t.h2Style),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ────────────────────────────────────────────────────
            _SectionLabel('Title', t: t),
            TextFormField(
              key: const Key('class_edit_title'),
              controller: _titleCtrl,
              style: t.bodyStyle.copyWith(color: t.text),
              decoration: _inputDecoration('Class title (required)', t),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── Class type ───────────────────────────────────────────────
            _SectionLabel('Class Type', t: t),
            _StyledDropdown<String>(
              key: const Key('class_edit_class_type'),
              value: _classType,
              items: _kClassTypes
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _classType = v ?? _classType),
              t: t,
            ),
            if (_classType == 'other') ...[
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('class_edit_class_type_label'),
                controller: _classTypeLabelCtrl,
                style: t.bodyStyle.copyWith(color: t.text),
                decoration: _inputDecoration('Label (e.g. "Wrestling")', t),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),

            // ── Gi type ──────────────────────────────────────────────────
            _SectionLabel('Gi / No-Gi', t: t),
            _StyledDropdown<String>(
              value: _giType,
              items: _kGiTypes
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _giType = v ?? _giType),
              t: t,
            ),
            const SizedBox(height: 16),

            // ── Skill level ──────────────────────────────────────────────
            _SectionLabel('Skill Level', t: t),
            _StyledDropdown<String>(
              value: _skillLevel,
              items: _kSkillLevels
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _skillLevel = v ?? _skillLevel),
              t: t,
            ),
            const SizedBox(height: 16),

            // ── Recurrence toggle ─────────────────────────────────────────
            _SectionLabel('Schedule', t: t),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isRecurring = true),
                    child: _ToggleChip(
                      label: 'Weekly',
                      selected: _isRecurring,
                      t: t,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: const Key('class_edit_recurring_toggle'),
                    onTap: () => setState(() => _isRecurring = false),
                    child: _ToggleChip(
                      label: 'One-off',
                      selected: !_isRecurring,
                      t: t,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isRecurring) ...[
              // Day of week picker.
              _SectionLabel('Day of Week', t: t),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final selected = _dayOfWeek == i;
                  return GestureDetector(
                    key: Key('class_edit_day_$i'),
                    onTap: () => setState(() => _dayOfWeek = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? t.primary : t.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? t.primary : t.border,
                        ),
                      ),
                      child: Text(
                        _kDayLabels[i],
                        style: t.labelStyle.copyWith(
                          color: selected ? Colors.white : t.text,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ] else ...[
              // Specific date picker.
              _SectionLabel('Date', t: t),
              InkWell(
                key: const Key('class_edit_date_picker'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.calendar, size: 16, color: t.muted),
                      const SizedBox(width: 8),
                      Text(
                        _specificDate != null
                            ? _fmtDate(_specificDate!)
                            : 'Pick a date',
                        style: t.bodyStyle.copyWith(
                          color: _specificDate != null ? t.text : t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Start / End time ─────────────────────────────────────────
            _SectionLabel('Time', t: t),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Start',
                    time: _startTime,
                    onTap: () => _pickTime(isStart: true),
                    t: t,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeTile(
                    label: 'End',
                    time: _endTime,
                    onTap: () => _pickTime(isStart: false),
                    t: t,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Instructor ───────────────────────────────────────────────
            _SectionLabel('Instructor', t: t),
            rosterAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => _InstructorFreeText(
                controller: _instructorNameCtrl,
                onChange: () => setState(() {}),
                t: t,
              ),
              data: (members) {
                if (members.isEmpty) {
                  return _InstructorFreeText(
                    controller: _instructorNameCtrl,
                    onChange: () => setState(() {}),
                    t: t,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _useRosterInstructor = false),
                            child: _ToggleChip(
                              label: 'Free text',
                              selected: !_useRosterInstructor,
                              t: t,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _useRosterInstructor = true),
                            child: _ToggleChip(
                              label: 'From roster',
                              selected: _useRosterInstructor,
                              t: t,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_useRosterInstructor)
                      _StyledDropdown<RosterMember>(
                        value: _selectedInstructor,
                        hint: 'Select instructor',
                        items: members
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedInstructor = v),
                        t: t,
                      )
                    else
                      _InstructorFreeText(
                        controller: _instructorNameCtrl,
                        onChange: () => setState(() {}),
                        t: t,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Capacity ─────────────────────────────────────────────────
            _SectionLabel('Capacity (optional)', t: t),
            TextFormField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              style: t.bodyStyle.copyWith(color: t.text),
              decoration: _inputDecoration('Max attendees', t),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),

            // ── Save button ──────────────────────────────────────────────
            ElevatedButton(
              key: const Key('class_edit_save'),
              onPressed: _isValid && !_saving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.existing != null ? 'Save Changes' : 'Create Class',
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, AppTokens t) {
    return InputDecoration(
      hintText: hint,
      hintStyle: t.bodyStyle.copyWith(color: t.muted),
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppTokens t;

  const _SectionLabel(this.text, {required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: t.labelStyle.copyWith(color: t.muted, fontSize: 12),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppTokens t;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? t.primary : t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? t.primary : t.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: t.labelStyle.copyWith(
          color: selected ? Colors.white : t.text,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final AppTokens t;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
    required this.t,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.miniStyle.copyWith(color: t.muted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.clock, size: 14, color: t.muted),
                const SizedBox(width: 6),
                Text(_fmt(time), style: t.labelStyle.copyWith(color: t.text)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppTokens t;
  final String? hint;

  const _StyledDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.t,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: t.surface,
          style: t.bodyStyle.copyWith(color: t.text),
          hint: hint != null
              ? Text(hint!, style: t.bodyStyle.copyWith(color: t.muted))
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InstructorFreeText extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChange;
  final AppTokens t;

  const _InstructorFreeText({
    required this.controller,
    required this.onChange,
    required this.t,
  });

  InputDecoration _dec(AppTokens t) => InputDecoration(
        hintText: 'Instructor name (optional)',
        hintStyle: t.bodyStyle.copyWith(color: t.muted),
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: t.bodyStyle.copyWith(color: t.text),
      decoration: _dec(t),
      onChanged: (_) => onChange(),
    );
  }
}
