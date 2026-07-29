import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../data/forum_repository.dart';

const List<String> _kCategories = [
  'technique',
  'rules',
  'competition',
  'schedule',
  'gear',
  'general',
];

class AskQuestionScreen extends ConsumerStatefulWidget {
  final String gymId;

  const AskQuestionScreen({super.key, required this.gymId});

  @override
  ConsumerState<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends ConsumerState<AskQuestionScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  String _category = 'general';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _titleCtrl.text.trim().isNotEmpty &&
      _bodyCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await ref.read(forumRepositoryProvider).createQuestion(
        widget.gymId,
        {
          'category': _category,
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
        },
      );
      ref.invalidate(
        forumQuestionsProvider((gymId: widget.gymId, category: null)),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post question: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Ask a Question', style: t.h2Style),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Category', style: t.labelStyle.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          Container(
            key: const Key('ask_category'),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.cardRadius),
              border: Border.all(color: t.border),
            ),
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: t.surface,
              style: t.bodyStyle.copyWith(color: t.text),
              items: _kCategories
                  .map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Title', style: t.labelStyle.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('ask_title'),
            controller: _titleCtrl,
            style: t.bodyStyle.copyWith(color: t.text),
            decoration: InputDecoration(
              hintText: 'Enter your question title',
              hintStyle: t.bodyStyle.copyWith(color: t.muted),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text('Details', style: t.labelStyle.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('ask_body'),
            controller: _bodyCtrl,
            style: t.bodyStyle.copyWith(color: t.text),
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe your question in detail…',
              hintStyle: t.bodyStyle.copyWith(color: t.muted),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            key: const Key('ask_save'),
            onPressed: _canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: t.border,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Save', style: t.bodyStyle.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
