import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/models/gym.dart';
import '../../open_mats/data/session_repository.dart';
import '../../open_mats/data/session_requests.dart';
import 'session_mgmt_screen.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  String _giType = 'both';
  String _expLevel = 'all';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 5));
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  bool _isFree = true;
  bool _isRecurring = true;
  final _feeCtrl = TextEditingController(text: '15');
  final _capCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(text: 'Visitors welcome. Bring both gi and rashguard.');
  bool _submitted = false;
  bool _saving = false;
  String? _error;
  String? _gymId;
  bool _addingNewGym = false;
  final _gymNameCtrl = TextEditingController();
  final _gymAddrCtrl = TextEditingController();
  final _gymCityCtrl = TextEditingController();
  final _gymStateCtrl = TextEditingController();

  static const _expToSkill = {'all': 'all', 'beg': 'beginner', 'int': 'intermediate', 'adv': 'advanced'};

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _title() {
    final gi = _giType == 'gi' ? 'Gi' : _giType == 'nogi' ? 'No-Gi' : 'Gi & No-Gi';
    return '$gi Open Mat';
  }

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fee = _isFree ? 0 : ((int.tryParse(_feeCtrl.text.trim()) ?? 0) * 100);
      final req = _addingNewGym
          ? CreateSessionRequest(
              newGym: NewGymInput(
                name: _gymNameCtrl.text.trim(),
                address: _gymAddrCtrl.text.trim(),
                city: _gymCityCtrl.text.trim(),
                state: _gymStateCtrl.text.trim(),
              ),
              title: _title(),
              startTime: _hhmm(_startTime),
              endTime: _hhmm(_endTime),
              isRecurring: _isRecurring,
              dayOfWeek: _isRecurring ? _selectedDate.weekday % 7 : null,
              specificDate: _isRecurring ? null : _selectedDate.toIso8601String().split('T').first,
              giType: _giType,
              skillLevel: _expToSkill[_expLevel] ?? 'all',
              feeCents: fee,
              maxParticipants: int.tryParse(_capCtrl.text.trim()),
              description: _notesCtrl.text.trim(),
            )
          : CreateSessionRequest(
              gymId: _gymId!,
              title: _title(),
              startTime: _hhmm(_startTime),
              endTime: _hhmm(_endTime),
              isRecurring: _isRecurring,
              dayOfWeek: _isRecurring ? _selectedDate.weekday % 7 : null,
              specificDate: _isRecurring ? null : _selectedDate.toIso8601String().split('T').first,
              giType: _giType,
              skillLevel: _expToSkill[_expLevel] ?? 'all',
              feeCents: fee,
              maxParticipants: int.tryParse(_capCtrl.text.trim()),
              description: _notesCtrl.text.trim(),
            );
      await ref.read(sessionRepositoryProvider).create(req);
      ref.invalidate(mySessionsProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _submitted = true;
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

  @override
  void dispose() {
    _feeCtrl.dispose();
    _capCtrl.dispose();
    _notesCtrl.dispose();
    _gymNameCtrl.dispose();
    _gymAddrCtrl.dispose();
    _gymCityCtrl.dispose();
    _gymStateCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  bool get _canSubmit => _addingNewGym
      ? (_gymNameCtrl.text.trim().isNotEmpty && _gymAddrCtrl.text.trim().isNotEmpty)
      : (_gymId != null);

  String get _recurringLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'Every ${days[_selectedDate.weekday - 1]} at this time';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymsAsync = ref.watch(allGymsProvider);
    final gyms = gymsAsync.asData?.value ?? const <Gym>[];
    if (_gymId == null && gyms.isNotEmpty && !_addingNewGym) {
      _gymId = gyms.first.id;
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _buildHeader(context, t),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostingAs(t, gyms),
                    const SizedBox(height: 12),
                    _buildQuotaWarning(t),
                    const SizedBox(height: 16),
                    _SessionSection(t: t, title: 'When'),
                    const SizedBox(height: 12),
                    _buildDateField(t),
                    const SizedBox(height: 12),
                    _buildTimeRow(t),
                    const SizedBox(height: 12),
                    _buildRepeatCard(t),
                    const SizedBox(height: 16),
                    _SessionSection(t: t, title: 'Format'),
                    const SizedBox(height: 12),
                    _buildGiPills(t),
                    const SizedBox(height: 12),
                    _buildExpPills(t),
                    const SizedBox(height: 16),
                    _SessionSection(t: t, title: 'Access'),
                    const SizedBox(height: 12),
                    _buildFreeCard(t),
                    const SizedBox(height: 12),
                    _buildCapacityField(t),
                    const SizedBox(height: 16),
                    _buildNotesField(t),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ]),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg.withValues(alpha: 0), t.bg],
                  stops: const [0, 0.35],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null) ...[
                  Text(_error!, style: t.miniStyle.copyWith(color: t.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSubmitButton(context, t),
              ]),
            ),
          ),
          if (_submitted)
            _SuccessOverlay(
              t: t,
              title: 'Session posted!',
              subtitle: "It's live now, marked unverified until the gym or an admin confirms it.",
              onDone: () => context.pop(),
            ),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: t.isSport ? t.bg2 : t.bg,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.badgeRadius + 6),
              border: Border.all(color: t.border),
            ),
            child: Icon(LucideIcons.x, size: 18, color: t.text),
          ),
        ),
        Expanded(child: Center(child: Text('New Open Mat', style: t.h2Style.copyWith(fontSize: 16)))),
        const SizedBox(width: 36),
      ]),
    );
  }

  Widget _buildPostingAs(AppTokens t, List<Gym> gyms) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('POSTING AS', style: t.labelStyle),
      const SizedBox(height: 6),
      if (_addingNewGym) ...[
        _buildNewGymFields(t),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _addingNewGym = false),
          child: Text(
            'Choose existing gym instead',
            style: t.miniStyle.copyWith(fontSize: 12, color: t.gi, decoration: TextDecoration.underline),
          ),
        ),
      ] else ...[
        if (gyms.isNotEmpty) ...[
          GestureDetector(
            onTap: gyms.length > 1 ? () => _pickGym(t, gyms) : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.gi, t.both]),
                    borderRadius: BorderRadius.circular(t.badgeRadius + 4),
                  ),
                  child: Center(child: Text(
                    () {
                      final selected = gyms.firstWhere((g) => g.id == _gymId, orElse: () => gyms.first);
                      return selected.name.trim().isNotEmpty ? selected.name.trim()[0].toUpperCase() : 'G';
                    }(),
                    style: t.h2Style.copyWith(color: Colors.white, fontSize: 16),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: () {
                  final selected = gyms.firstWhere((g) => g.id == _gymId, orElse: () => gyms.first);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selected.name, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      gyms.length > 1 ? '${gyms.length} gyms available · tap to switch' : selected.address,
                      style: t.miniStyle.copyWith(fontSize: 11, color: t.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]);
                }()),
                if (gyms.length > 1) Icon(LucideIcons.chevronsUpDown, size: 16, color: t.muted),
              ]),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.cardRadius),
              border: Border.all(color: t.border),
            ),
            child: Row(children: [
              Icon(LucideIcons.store, size: 18, color: t.muted),
              const SizedBox(width: 12),
              Expanded(child: Text('No gyms found', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: t.muted))),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _addingNewGym = true),
          child: Text(
            "Can't find your gym? Add it",
            style: t.miniStyle.copyWith(fontSize: 12, color: t.gi, decoration: TextDecoration.underline),
          ),
        ),
      ],
    ]);
  }

  Widget _buildNewGymFields(AppTokens t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInlineTextField(t, label: 'GYM NAME', required: true, controller: _gymNameCtrl, hint: 'e.g. Atos HQ'),
      const SizedBox(height: 10),
      _buildInlineTextField(t, label: 'ADDRESS', required: true, controller: _gymAddrCtrl, hint: '123 Main St'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _buildInlineTextField(t, label: 'CITY', required: false, controller: _gymCityCtrl, hint: 'San Diego')),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: _buildInlineTextField(t, label: 'STATE', required: false, controller: _gymStateCtrl, hint: 'CA')),
      ]),
    ]);
  }

  Widget _buildInlineTextField(AppTokens t, {required String label, required bool required, required TextEditingController controller, required String hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: t.labelStyle),
        if (required) Text(' *', style: t.labelStyle.copyWith(color: t.red)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: TextField(
          controller: controller,
          style: t.bodyStyle,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.miniStyle.copyWith(fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          ),
        ),
      ),
    ]);
  }

  Future<void> _pickGym(AppTokens t, List<Gym> gyms) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: gyms.map((g) {
          return ListTile(
            leading: Icon(LucideIcons.store, size: 18, color: g.id == _gymId ? t.gi : t.muted),
            title: Text(g.name, style: t.bodyStyle),
            subtitle: Text(g.address, style: t.miniStyle.copyWith(fontSize: 11, color: t.muted)),
            trailing: g.id == _gymId ? Icon(LucideIcons.check, size: 16, color: t.gi) : null,
            onTap: () => Navigator.of(ctx).pop(g.id),
          );
        }).toList()),
      ),
    );
    if (picked != null) setState(() => _gymId = picked);
  }

  Widget _buildQuotaWarning(AppTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: t.noGi.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.noGi.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(LucideIcons.bell, size: 16, color: t.noGi),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(
          style: t.miniStyle.copyWith(fontSize: 12, color: t.body),
          children: [
            TextSpan(text: '1 of 2', style: t.miniStyle.copyWith(fontSize: 12, color: t.noGi, fontWeight: FontWeight.w800)),
            const TextSpan(text: ' sessions used for this date.'),
          ],
        ))),
      ]),
    );
  }

  Widget _buildDateField(AppTokens t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('DATE', style: t.labelStyle),
        Text(' *', style: t.labelStyle.copyWith(color: t.red)),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Icon(LucideIcons.calendar, size: 18, color: t.muted),
            const SizedBox(width: 10),
            Text(_formatDate(_selectedDate), style: t.bodyStyle),
            const Spacer(),
            Icon(LucideIcons.chevronDown, size: 16, color: t.muted),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTimeRow(AppTokens t) {
    return Row(children: [
      Expanded(child: _buildTimePicker(t, label: 'Start', isStart: true)),
      const SizedBox(width: 12),
      Expanded(child: _buildTimePicker(t, label: 'End', isStart: false)),
    ]);
  }

  Widget _buildTimePicker(AppTokens t, {required String label, required bool isStart}) {
    final time = isStart ? _startTime : _endTime;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label.toUpperCase(), style: t.labelStyle),
        Text(' *', style: t.labelStyle.copyWith(color: t.red)),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => _pickTime(isStart),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Icon(LucideIcons.clock, size: 16, color: t.muted),
            const SizedBox(width: 8),
            Text(_formatTime(time), style: t.bodyStyle),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildRepeatCard(AppTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: t.gi.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(t.badgeRadius + 4),
          ),
          child: Icon(LucideIcons.calendar, size: 18, color: t.gi),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Repeat weekly', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(
            _isRecurring ? _recurringLabel : 'One-time session',
            style: t.miniStyle.copyWith(fontSize: 11, color: t.muted),
          ),
        ])),
        _Toggle(on: _isRecurring, onChanged: (v) => setState(() => _isRecurring = v), color: t.gi),
      ]),
    );
  }

  Widget _buildGiPills(AppTokens t) {
    const opts = [
      ('gi', 'Gi'),
      ('nogi', 'No-Gi'),
      ('both', 'Both'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('GI TYPE', style: t.labelStyle),
        Text(' *', style: t.labelStyle.copyWith(color: t.red)),
      ]),
      const SizedBox(height: 8),
      Row(children: opts.map((opt) {
        final active = _giType == opt.$1;
        final accent = t.giColor(opt.$1);
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _giType = opt.$1),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.14) : t.bg,
              borderRadius: BorderRadius.circular(t.cardRadius + 2),
              border: Border.all(color: active ? accent : t.border, width: active ? 1.5 : 1),
            ),
            child: Text(opt.$2, textAlign: TextAlign.center,
                style: t.bodyStyle.copyWith(color: active ? accent : t.body, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ));
      }).toList()),
    ]);
  }

  Widget _buildExpPills(AppTokens t) {
    const opts = [
      ('all', 'All Levels'),
      ('beg', 'Beginner'),
      ('int', 'Intermediate'),
      ('adv', 'Advanced'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('EXPERIENCE', style: t.labelStyle),
        Text(' *', style: t.labelStyle.copyWith(color: t.red)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 8, children: opts.map((opt) {
        final active = _expLevel == opt.$1;
        final accent = t.expColor(opt.$1);
        return GestureDetector(
          onTap: () => setState(() => _expLevel = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.14) : t.bg,
              borderRadius: BorderRadius.circular(t.cardRadius + 2),
              border: Border.all(color: active ? accent : t.border, width: active ? 1.5 : 1),
            ),
            child: Text(opt.$2,
                style: t.bodyStyle.copyWith(color: active ? accent : t.body, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        );
      }).toList()),
    ]);
  }

  Widget _buildFreeCard(AppTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: t.green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(t.badgeRadius + 4),
            ),
            child: Icon(LucideIcons.gift, size: 18, color: t.green),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Free Mat', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Drop-in welcome, no charge', style: t.miniStyle.copyWith(fontSize: 11, color: t.muted)),
          ])),
          _Toggle(on: _isFree, onChanged: (v) => setState(() => _isFree = v), color: t.green),
        ]),
        if (!_isFree) ...[
          Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 12), color: t.border),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MAT FEE (USD)', style: t.labelStyle),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: t.surfaceHi,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(LucideIcons.dollarSign, size: 16, color: t.muted),
                ),
                Expanded(
                  child: TextField(
                    controller: _feeCtrl,
                    style: t.bodyStyle,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '15',
                      hintStyle: t.miniStyle.copyWith(fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildCapacityField(AppTokens t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('CAPACITY', style: t.labelStyle),
        const Spacer(),
        Text('optional', style: t.miniStyle.copyWith(fontSize: 10)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(left: 14), child: Icon(LucideIcons.user, size: 18, color: t.muted)),
          Expanded(
            child: TextField(
              controller: _capCtrl,
              style: t.bodyStyle,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Leave blank for unlimited',
                hintStyle: t.miniStyle.copyWith(fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildNotesField(AppTokens t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('NOTES', style: t.labelStyle),
        const Spacer(),
        Text('optional', style: t.miniStyle.copyWith(fontSize: 10)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: TextField(
          controller: _notesCtrl,
          style: t.bodyStyle,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any notes for practitioners…',
            hintStyle: t.miniStyle.copyWith(fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSubmitButton(BuildContext context, AppTokens t) {
    final enabled = _canSubmit && !_saving;
    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          color: enabled ? t.gi : t.border,
          borderRadius: BorderRadius.circular(t.cardRadius + 2),
          boxShadow: enabled
              ? [BoxShadow(color: t.gi.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_saving)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            )
          else
            const Icon(LucideIcons.plus, size: 18, color: Colors.white),
          const SizedBox(width: 9),
          Text(_saving ? 'Posting…' : 'Post Session', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ── Section divider ───────────────────────────────────────────
class _SessionSection extends StatelessWidget {
  final AppTokens t;
  final String title;

  const _SessionSection({required this.t, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title.toUpperCase(), style: t.labelStyle.copyWith(color: t.gi)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: t.border)),
    ]);
  }
}

// ── Toggle switch ─────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool on;
  final void Function(bool) onChanged;
  final Color color;

  const _Toggle({required this.on, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50, height: 28,
        decoration: BoxDecoration(
          color: on ? color : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24, height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3, offset: const Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Success overlay ───────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  final AppTokens t;
  final String title;
  final String subtitle;
  final VoidCallback onDone;

  const _SuccessOverlay({required this.t, required this.title, required this.subtitle, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: t.bg.withValues(alpha: 0.97),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(color: t.green.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: t.green, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: t.green.withValues(alpha: 0.4), blurRadius: 22)],
                ),
                child: const Icon(LucideIcons.check, size: 30, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: t.h1Style.copyWith(fontSize: 24)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, textAlign: TextAlign.center, style: t.bodyStyle.copyWith(color: t.muted)),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              decoration: BoxDecoration(
                color: t.green,
                borderRadius: BorderRadius.circular(t.cardRadius + 2),
                boxShadow: [BoxShadow(color: t.green.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.check, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text('Done', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
