import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/report_repository.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Report')),
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
          Text('WHAT KIND OF REPORT', style: t.labelStyle),
          const SizedBox(height: 8),
          Row(children: [
            _typeChip(t, 'bug', 'Bug', LucideIcons.bug),
            const SizedBox(width: 10),
            _typeChip(t, 'feature', 'Feature', LucideIcons.lightbulb),
          ]),
          const SizedBox(height: 20),
          Text('TITLE', style: t.labelStyle),
          const SizedBox(height: 8),
          _fieldBox(
            t,
            child: TextField(
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
          Text('DESCRIPTION', style: t.labelStyle),
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
            color: selected ? t.primary.withValues(alpha: 0.12) : t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: selected ? t.primary : t.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? t.primary : t.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: t.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? t.primary : t.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldBox(AppTokens t, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: child,
    );
  }
}
