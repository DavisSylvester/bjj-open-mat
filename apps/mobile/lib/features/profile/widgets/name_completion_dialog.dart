import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/glass_form.dart';

/// Shows a modal dialog prompting the user to enter their first and last name.
/// On Save, calls [AuthStateNotifier.updateProfile] with the entered values.
/// On Skip (or dismiss), does nothing. Non-blocking — the caller should not
/// await meaningful state from the return value.
Future<void> showNameCompletionDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NameCompletionDialog(ref: ref),
  );
}

class _NameCompletionDialog extends StatefulWidget {
  final WidgetRef ref;

  const _NameCompletionDialog({required this.ref});

  @override
  State<_NameCompletionDialog> createState() => _NameCompletionDialogState();
}

class _NameCompletionDialogState extends State<_NameCompletionDialog> {
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _lastController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final first = _firstController.text.trim();
    final last = _lastController.text.trim();
    if (first.isEmpty && last.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref.read(authStateProvider.notifier).updateProfile({
        if (first.isNotEmpty) 'firstName': first,
        if (last.isNotEmpty) 'lastName': last,
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.cardRadius),
        side: BorderSide(color: t.border),
      ),
      title: Text('Complete your profile', style: t.h2Style),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add your name so other grapplers can find you.',
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _firstController,
            style: t.bodyStyle,
            textCapitalization: TextCapitalization.words,
            decoration: glassInput(t, 'First name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastController,
            style: t.bodyStyle,
            textCapitalization: TextCapitalization.words,
            decoration: glassInput(t, 'Last name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Skip', style: t.bodyStyle.copyWith(color: t.muted)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: t.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
