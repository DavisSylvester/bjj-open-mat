import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/friendly_error.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/gym_claim_repository.dart';

class ClaimGymScreen extends ConsumerStatefulWidget {
  final String gymId;
  final String kind; // 'claim' | 'transfer'
  const ClaimGymScreen({super.key, required this.gymId, required this.kind});

  @override
  ConsumerState<ClaimGymScreen> createState() => _ClaimGymScreenState();
}

class _ClaimGymScreenState extends ConsumerState<ClaimGymScreen> {
  String _relationship = 'owner';
  final _contactCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _contactCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving && _contactCtrl.text.trim().isNotEmpty && _messageCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(gymClaimRepositoryProvider).submit(
            widget.gymId,
            relationship: _relationship,
            contact: _contactCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
          );
      ref.invalidate(myGymClaimProvider(widget.gymId));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyErrorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final title = widget.kind == 'transfer' ? 'Request ownership' : 'Claim this gym';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text(title, style: t.h2Style),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your role at this gym', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('claim-relationship'),
                initialValue: _relationship,
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'head_coach', child: Text('Head coach')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setState(() => _relationship = v ?? 'owner'),
              ),
              const SizedBox(height: 16),
              Text('Gym contact (email or phone)', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('claim-contact'),
                controller: _contactCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'owner@yourgym.com'),
              ),
              const SizedBox(height: 16),
              Text('Message', style: t.miniStyle.copyWith(color: t.muted)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('claim-message'),
                controller: _messageCtrl,
                onChanged: (_) => setState(() {}),
                maxLines: 4,
                decoration: const InputDecoration(hintText: "Tell us how you're connected to this gym"),
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
                key: const Key('claim-submit'),
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
        ),
      ),
    );
  }
}
