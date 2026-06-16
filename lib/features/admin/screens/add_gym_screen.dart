import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class AddGymScreen extends ConsumerStatefulWidget {
  const AddGymScreen({super.key});

  @override
  ConsumerState<AddGymScreen> createState() => _AddGymScreenState();
}

class _AddGymScreenState extends ConsumerState<AddGymScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _gymType = 'gi';

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
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
              GestureDetector(onTap: _back, child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text)),
              const SizedBox(width: 12),
              Expanded(child: Text('Register Gym', style: t.h1Style.copyWith(fontSize: 20))),
            ]),
          ),
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: t.isSport
                ? Row(children: List.generate(3, (i) => Expanded(
                    child: Container(
                      height: 28,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      color: i == _step ? t.amber : i < _step ? t.green : t.surface,
                      child: Center(child: Text(
                        i < _step ? '✓' : '${i + 1}',
                        style: t.miniStyle.copyWith(color: i == _step ? t.bg : i < _step ? t.bg : t.muted),
                      )),
                    ),
                  )))
                : Row(children: List.generate(3, (i) {
                    final labels = ['Basic Info', 'Location', 'Confirm'];
                    return Expanded(child: Column(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: i <= _step ? t.red : t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: i == _step ? t.red : t.border),
                        ),
                        child: Center(child: Text(
                          i < _step ? '✓' : '${i + 1}',
                          style: t.miniStyle.copyWith(color: i <= _step ? Colors.white : t.muted),
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[i], style: t.miniStyle.copyWith(fontSize: 9, color: i <= _step ? t.text : t.muted)),
                    ]));
                  })),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(t: t, nameCtrl: _nameCtrl, websiteCtrl: _websiteCtrl, gymType: _gymType, onTypeChange: (v) => setState(() => _gymType = v)),
                _Step2(t: t, addressCtrl: _addressCtrl, cityCtrl: _cityCtrl),
                _Step3(t: t, name: _nameCtrl.text, address: _addressCtrl.text, gymType: _gymType),
              ],
            ),
          ),
          // Next button
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: t.isSport
                ? GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity, height: 54,
                      color: t.red,
                      child: Center(child: Text(
                        _step < 2 ? 'Next Step' : 'Register Gym',
                        style: t.h2Style.copyWith(color: Colors.white, fontSize: 16),
                      )),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
                    ),
                    child: Text(_step < 2 ? 'Continue' : 'Register Gym',
                        style: t.h2Style.copyWith(color: Colors.white)),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final AppTokens t;
  final TextEditingController nameCtrl;
  final TextEditingController websiteCtrl;
  final String gymType;
  final void Function(String) onTypeChange;

  const _Step1({required this.t, required this.nameCtrl, required this.websiteCtrl, required this.gymType, required this.onTypeChange});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Basic Info', style: t.h2Style),
        const SizedBox(height: 16),
        _Field(t: t, label: 'Gym Name', ctrl: nameCtrl, hint: 'e.g. Atos HQ'),
        const SizedBox(height: 12),
        _Field(t: t, label: 'Website', ctrl: websiteCtrl, hint: 'https://…'),
        const SizedBox(height: 16),
        Text('Gi Type', style: t.labelStyle),
        const SizedBox(height: 8),
        Row(children: [
          for (final opt in [('gi', 'Gi'), ('nogi', 'No-Gi'), ('both', 'Both')])
            Expanded(child: GestureDetector(
              onTap: () => onTypeChange(opt.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: gymType == opt.$1 ? t.giColor(opt.$1).withValues(alpha: 0.15) : t.surface,
                  border: Border.all(color: gymType == opt.$1 ? t.giColor(opt.$1) : t.border, width: gymType == opt.$1 ? 2 : 1),
                  borderRadius: BorderRadius.circular(t.cardRadius),
                ),
                child: Text(opt.$2, textAlign: TextAlign.center,
                    style: t.miniStyle.copyWith(color: gymType == opt.$1 ? t.giColor(opt.$1) : t.muted)),
              ),
            )),
        ]),
      ]),
    );
  }
}

class _Step2 extends StatelessWidget {
  final AppTokens t;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;

  const _Step2({required this.t, required this.addressCtrl, required this.cityCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Location', style: t.h2Style),
        const SizedBox(height: 16),
        _Field(t: t, label: 'Street Address', ctrl: addressCtrl, hint: '123 Main St'),
        const SizedBox(height: 12),
        _Field(t: t, label: 'City / State', ctrl: cityCtrl, hint: 'Los Angeles, CA'),
      ]),
    );
  }
}

class _Step3 extends StatelessWidget {
  final AppTokens t;
  final String name;
  final String address;
  final String gymType;

  const _Step3({required this.t, required this.name, required this.address, required this.gymType});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm', style: t.h2Style),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Gym Name' : name, style: t.h1Style.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(address.isEmpty ? 'Address' : address, style: t.bodyStyle),
          ]),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final AppTokens t;
  final String label;
  final TextEditingController ctrl;
  final String hint;

  const _Field({required this.t, required this.label, required this.ctrl, required this.hint});

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
