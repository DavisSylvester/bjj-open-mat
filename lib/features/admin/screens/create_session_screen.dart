import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _nameCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  String _giType = 'gi';
  String _expLevel = 'all';
  bool _isToday = true;
  bool _isRecurring = false;
  late int _selectedWeekDay;
  late Set<int> _recurringDays;

  static const _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    _selectedWeekDay = DateTime.now().weekday;
    _recurringDays = {DateTime.now().weekday};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _feeCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  DateTime get _resolvedDate {
    if (_isToday) return DateTime.now();
    final today = DateTime.now();
    return today.add(Duration(days: _selectedWeekDay - today.weekday));
  }

  String get _dateLabel {
    final d = _resolvedDate;
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  }

  String get _dayLabel => _dayLabels[_resolvedDate.weekday - 1];

  String get _recurringDaysSummary {
    if (_recurringDays.isEmpty) return '—';
    final sorted = _recurringDays.toList()..sort();
    return sorted.map((d) => _dayLabels[d - 1]).join(' · ');
  }

  Widget _buildCapsule(AppTokens t, {
    required List<String> options,
    required int activeIndex,
    required Color accent,
    required void Function(int) onTap,
  }) {
    return Row(
      children: List.generate(options.length, (i) {
        final active = i == activeIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onTap(i); },
            child: Container(
              height: 32,
              margin: EdgeInsets.only(right: i < options.length - 1 ? 1 : 0),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.18) : t.surface,
                border: Border(bottom: BorderSide(color: active ? accent : t.border, width: 2)),
              ),
              alignment: Alignment.center,
              child: Text(options[i], style: t.miniStyle.copyWith(color: active ? accent : t.muted)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayPicker(AppTokens t, {required bool multiSelect}) {
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final active = multiSelect ? _recurringDays.contains(day) : _selectedWeekDay == day;
        final isToday = DateTime.now().weekday == day;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (multiSelect) {
                  if (_recurringDays.contains(day)) {
                    if (_recurringDays.length > 1) _recurringDays.remove(day);
                  } else {
                    _recurringDays.add(day);
                  }
                } else {
                  _selectedWeekDay = day;
                }
              });
            },
            child: Container(
              height: 40,
              margin: EdgeInsets.only(right: i < 6 ? 1 : 0),
              decoration: BoxDecoration(
                color: active ? t.amber.withValues(alpha: 0.18) : t.surface,
                border: Border(top: BorderSide(color: active ? t.amber : t.border, width: 2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_dayLabels[i], style: t.miniStyle.copyWith(color: active ? t.amber : t.muted)),
                  if (isToday)
                    Container(
                      width: 4, height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(color: t.amber, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              if (t.isSport)
                Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Expanded(child: Text('Create Open Mat', style: t.h1Style.copyWith(fontSize: 20))),
            ]),
          ),
          if (t.isSport) Divider(height: 1, color: t.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(t: t, label: 'Session Name', ctrl: _nameCtrl, hint: 'e.g. Saturday Open Mat'),
                  const SizedBox(height: 16),
                  // Today/Week + Single/Recurring capsules
                  Row(children: [
                    Expanded(child: _buildCapsule(t,
                      options: const ['TODAY', 'WEEK'],
                      activeIndex: _isToday ? 0 : 1,
                      accent: t.amber,
                      onTap: (i) => setState(() => _isToday = i == 0),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCapsule(t,
                      options: const ['SINGLE', 'RECURRING'],
                      activeIndex: _isRecurring ? 1 : 0,
                      accent: t.red,
                      onTap: (i) => setState(() => _isRecurring = i == 1),
                    )),
                  ]),
                  if (!_isToday || _isRecurring) ...[
                    const SizedBox(height: 12),
                    _buildDayPicker(t, multiSelect: _isRecurring),
                  ],
                  if (_isRecurring) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(width: 3, height: 16, color: t.red),
                      const SizedBox(width: 8),
                      Text('REPEATS EVERY', style: t.miniStyle.copyWith(color: t.muted)),
                      const SizedBox(width: 6),
                      Text(_recurringDaysSummary, style: t.miniStyle.copyWith(color: t.red)),
                      const Spacer(),
                      Text('UNTIL CANCELLED', style: t.miniStyle.copyWith(color: t.faint)),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  // Date strip + time fields
                  Row(children: [
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(t.cardRadius),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(children: [
                        Text(_dateLabel, style: t.miniStyle.copyWith(color: t.amber, fontSize: 11)),
                        Text(_dayLabel, style: t.miniStyle),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _Field(t: t, label: 'Start', ctrl: _startCtrl, hint: '7:00 PM')),
                    const SizedBox(width: 8),
                    Expanded(child: _Field(t: t, label: 'End', ctrl: _endCtrl, hint: '9:00 PM')),
                  ]),
                  const SizedBox(height: 16),
                  // Gi type
                  Text('Gi Type'.toUpperCase(), style: t.labelStyle),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final opt in [('gi', 'Gi'), ('nogi', 'No-Gi'), ('both', 'Both')])
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _giType = opt.$1),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _giType == opt.$1 ? t.giColor(opt.$1).withValues(alpha: 0.15) : t.surface,
                            border: Border.all(
                              color: _giType == opt.$1 ? t.giColor(opt.$1) : t.border,
                              width: _giType == opt.$1 ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(t.cardRadius),
                          ),
                          child: Text(opt.$2, textAlign: TextAlign.center,
                              style: t.miniStyle.copyWith(color: _giType == opt.$1 ? t.giColor(opt.$1) : t.muted)),
                        ),
                      )),
                  ]),
                  const SizedBox(height: 16),
                  // Exp level
                  Text('Experience Level'.toUpperCase(), style: t.labelStyle),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final opt in [('all', 'All'), ('beg', 'Beg'), ('int', 'Inter'), ('adv', 'Adv')])
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _expLevel = opt.$1),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _expLevel == opt.$1 ? t.expColor(opt.$1).withValues(alpha: 0.15) : t.surface,
                            border: Border.all(
                              color: _expLevel == opt.$1 ? t.expColor(opt.$1) : t.border,
                              width: _expLevel == opt.$1 ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(t.cardRadius),
                          ),
                          child: Text(opt.$2, textAlign: TextAlign.center,
                              style: t.miniStyle.copyWith(color: _expLevel == opt.$1 ? t.expColor(opt.$1) : t.muted)),
                        ),
                      )),
                  ]),
                  const SizedBox(height: 16),
                  _Field(t: t, label: r'Mat Fee ($)', ctrl: _feeCtrl, hint: '0 for free', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _Field(t: t, label: 'Description', ctrl: _descCtrl, hint: 'Details about the session…', maxLines: 3),
                  const SizedBox(height: 12),
                  _Field(t: t, label: 'Max Participants', ctrl: _maxCtrl, hint: '20', keyboardType: TextInputType.number),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: t.isSport
                ? GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, height: 54,
                      color: t.red,
                      child: Center(child: Text(
                        _isRecurring ? 'Schedule Recurring Mat' : 'Post Open Mat',
                        style: t.h2Style.copyWith(color: Colors.white, fontSize: 16),
                      )),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
                    ),
                    child: Text(
                      _isRecurring ? 'Schedule Recurring Mat' : 'Post Open Mat',
                      style: t.h2Style.copyWith(color: Colors.white),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final AppTokens t;
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.t,
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: t.labelStyle),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: TextField(
          controller: ctrl,
          style: t.bodyStyle,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.miniStyle.copyWith(fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    ]);
  }
}
