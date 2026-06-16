import 'package:flutter/material.dart';
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
  final _dateCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  String _giType = 'gi';
  String _expLevel = 'all';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _feeCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
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
                Container(
                  width: 4,
                  height: 22,
                  color: t.red,
                  margin: const EdgeInsets.only(right: 8),
                ),
              Expanded(
                child: Text(
                  'Create Open Mat',
                  style: t.h1Style.copyWith(fontSize: 20),
                ),
              ),
            ]),
          ),
          if (t.isSport) Divider(height: 1, color: t.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    t: t,
                    label: 'Session Name',
                    ctrl: _nameCtrl,
                    hint: 'e.g. Saturday Open Mat',
                  ),
                  const SizedBox(height: 16),
                  // Gi type selector
                  Text('Gi Type'.toUpperCase(), style: t.labelStyle),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final opt in [
                      ('gi', 'Gi'),
                      ('nogi', 'No-Gi'),
                      ('both', 'Both'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _giType = opt.$1),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _giType == opt.$1
                                  ? t.giColor(opt.$1).withValues(alpha: 0.15)
                                  : t.surface,
                              border: Border.all(
                                color: _giType == opt.$1
                                    ? t.giColor(opt.$1)
                                    : t.border,
                                width: _giType == opt.$1 ? 2 : 1,
                              ),
                              borderRadius:
                                  BorderRadius.circular(t.cardRadius),
                            ),
                            child: Text(
                              opt.$2,
                              textAlign: TextAlign.center,
                              style: t.miniStyle.copyWith(
                                color: _giType == opt.$1
                                    ? t.giColor(opt.$1)
                                    : t.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  // Exp level selector
                  Text('Experience Level'.toUpperCase(), style: t.labelStyle),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final opt in [
                      ('all', 'All'),
                      ('beg', 'Beg'),
                      ('int', 'Inter'),
                      ('adv', 'Adv'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _expLevel = opt.$1),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _expLevel == opt.$1
                                  ? t.expColor(opt.$1).withValues(alpha: 0.15)
                                  : t.surface,
                              border: Border.all(
                                color: _expLevel == opt.$1
                                    ? t.expColor(opt.$1)
                                    : t.border,
                                width: _expLevel == opt.$1 ? 2 : 1,
                              ),
                              borderRadius:
                                  BorderRadius.circular(t.cardRadius),
                            ),
                            child: Text(
                              opt.$2,
                              textAlign: TextAlign.center,
                              style: t.miniStyle.copyWith(
                                color: _expLevel == opt.$1
                                    ? t.expColor(opt.$1)
                                    : t.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _Field(
                    t: t,
                    label: 'Date',
                    ctrl: _dateCtrl,
                    hint: 'YYYY-MM-DD',
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _Field(
                        t: t,
                        label: 'Start Time',
                        ctrl: _startCtrl,
                        hint: '7:00 PM',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        t: t,
                        label: 'End Time',
                        ctrl: _endCtrl,
                        hint: '9:00 PM',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _Field(
                    t: t,
                    label: r'Mat Fee ($)',
                    ctrl: _feeCtrl,
                    hint: '0 for free',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    t: t,
                    label: 'Description',
                    ctrl: _descCtrl,
                    hint: 'Details about the session…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    t: t,
                    label: 'Max Participants',
                    ctrl: _maxCtrl,
                    hint: '20',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Submit
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: t.isSport
                ? GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      color: t.red,
                      child: Center(
                        child: Text(
                          'Create Session',
                          style: t.h2Style.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.cardRadius),
                      ),
                    ),
                    child: Text(
                      'Create Session',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
