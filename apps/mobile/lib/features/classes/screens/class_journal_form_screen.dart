import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/class_journal_repository.dart';

/// Form screen for creating or updating a class journal entry.
///
/// Accepts [classId], [gymId], and [date] as required parameters.
/// Allows the user to fill in training details, add technique tags,
/// share notes with the gym, and optionally rate the instructor.
class ClassJournalFormScreen extends ConsumerStatefulWidget {
  final String classId;
  final String gymId;
  final String date;

  const ClassJournalFormScreen({
    super.key,
    required this.classId,
    required this.gymId,
    required this.date,
  });

  @override
  ConsumerState<ClassJournalFormScreen> createState() =>
      _ClassJournalFormScreenState();
}

class _ClassJournalFormScreenState
    extends ConsumerState<ClassJournalFormScreen> {

  final _whatWasTaughtCtrl = TextEditingController();
  final _tagInputCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _ratingCommentCtrl = TextEditingController();

  final List<String> _techniqueTags = [];

  int? _rounds;
  int? _intensity;
  int? _partners;
  bool _shared = false;

  // Instructor rating block
  int _stars = 0; // 0 = not rating
  bool _ratingAnonymous = false;

  bool _saving = false;

  @override
  void dispose() {
    _whatWasTaughtCtrl.dispose();
    _tagInputCtrl.dispose();
    _noteCtrl.dispose();
    _ratingCommentCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInputCtrl.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      _techniqueTags.add(tag);
      _tagInputCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final repo = ref.read(classJournalRepositoryProvider);

    // Build journal body — only include set fields.
    final body = <String, dynamic>{};
    final whatWasTaught = _whatWasTaughtCtrl.text.trim();
    if (whatWasTaught.isNotEmpty) body['whatWasTaught'] = whatWasTaught;
    if (_techniqueTags.isNotEmpty) body['techniqueTags'] = List<String>.from(_techniqueTags);
    if (_rounds != null) body['rounds'] = _rounds;
    if (_intensity != null) body['intensity'] = _intensity;
    if (_partners != null) body['partners'] = _partners;
    final note = _noteCtrl.text.trim();
    if (note.isNotEmpty) body['note'] = note;
    body['shared'] = _shared;

    try {
      await repo.upsertJournal(widget.classId, body);

      if (_stars >= 1) {
        final ratingBody = <String, dynamic>{
          'date': widget.date,
          'stars': _stars,
          'anonymous': _ratingAnonymous,
        };
        final comment = _ratingCommentCtrl.text.trim();
        if (comment.isNotEmpty) ratingBody['comment'] = comment;
        await repo.rateInstructor(widget.classId, ratingBody);
      }

      // Invalidate dependent providers.
      ref.invalidate(myJournalProvider);
      ref.invalidate(
        sharedNotesProvider((classId: widget.classId, date: widget.date)),
      );

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.status == 403
            ? 'You must be a member to journal this class'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving journal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Class Journal', style: t.h2Style),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── What was taught ────────────────────────────────────────
                  _SectionLabel(label: 'What was taught?', t: t),
                  const SizedBox(height: 8),
                  _GlassField(
                    t: t,
                    child: TextField(
                      key: const Key('whatWasTaught'),
                      controller: _whatWasTaughtCtrl,
                      style: t.bodyStyle,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Techniques, concepts, drills…',
                        hintStyle: t.miniStyle.copyWith(fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Technique tags ─────────────────────────────────────────
                  _SectionLabel(label: 'Technique tags', t: t),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassField(
                          t: t,
                          child: TextField(
                            key: const Key('tagInput'),
                            controller: _tagInputCtrl,
                            style: t.bodyStyle,
                            decoration: InputDecoration(
                              hintText: 'e.g. armbar, triangle…',
                              hintStyle:
                                  t.miniStyle.copyWith(fontSize: 13),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const Key('addTagButton'),
                        onPressed: _addTag,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.cardRadius),
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_techniqueTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _techniqueTags
                          .map(
                            (tag) => Chip(
                              label: Text(
                                tag,
                                style:
                                    t.miniStyle.copyWith(fontSize: 12),
                              ),
                              onDeleted: () =>
                                  setState(() => _techniqueTags.remove(tag)),
                              deleteIconColor: t.muted,
                              backgroundColor: t.surface,
                              side: BorderSide(color: t.border),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Training log fields ────────────────────────────────────
                  _SectionLabel(label: 'Training log', t: t),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _IntField(
                          label: 'Rounds',
                          value: _rounds,
                          t: t,
                          onChanged: (v) => setState(() => _rounds = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IntField(
                          label: 'Partners',
                          value: _partners,
                          t: t,
                          onChanged: (v) => setState(() => _partners = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SectionLabel(label: 'Intensity (1–5)', t: t),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) {
                      final val = i + 1;
                      final selected = _intensity != null && val <= _intensity!;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _intensity =
                              (_intensity == val && val == 1) ? null : val,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: 6),
                          child: Icon(
                            LucideIcons.zap,
                            size: 26,
                            color: selected ? t.amber : t.muted,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // ── Personal note ──────────────────────────────────────────
                  _SectionLabel(label: 'Personal note', t: t),
                  const SizedBox(height: 8),
                  _GlassField(
                    t: t,
                    child: TextField(
                      controller: _noteCtrl,
                      style: t.bodyStyle,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Notes to yourself…',
                        hintStyle: t.miniStyle.copyWith(fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Share with gym switch ──────────────────────────────────
                  _GlassField(
                    t: t,
                    child: SwitchListTile(
                      key: const Key('shareSwitch'),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text('Share with gym', style: t.bodyStyle),
                      subtitle: Text(
                        'Classmates can see your notes for this session',
                        style: t.miniStyle.copyWith(
                          color: t.muted,
                          fontSize: 11,
                        ),
                      ),
                      value: _shared,
                      activeThumbColor: t.primary,
                      onChanged: (v) => setState(() => _shared = v),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Instructor rating block ────────────────────────────────
                  _SectionLabel(label: 'Rate the instructor', t: t),
                  const SizedBox(height: 8),
                  _GlassField(
                    t: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Row(
                            children: List.generate(5, (i) {
                              final val = i + 1;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _stars = val),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    key: Key('star_$val'),
                                    LucideIcons.star,
                                    size: 26,
                                    color: val <= _stars
                                        ? t.amber
                                        : t.muted,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        if (_stars >= 1) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: TextField(
                              controller: _ratingCommentCtrl,
                              style: t.bodyStyle,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Comment (optional)…',
                                hintStyle:
                                    t.miniStyle.copyWith(fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: Text(
                              'Rate anonymously',
                              style: t.bodyStyle,
                            ),
                            value: _ratingAnonymous,
                            activeThumbColor: t.primary,
                            onChanged: (v) =>
                                setState(() => _ratingAnonymous = v),
                          ),
                        ],
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Save button ────────────────────────────────────────────────────
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              key: const Key('saveButton'),
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.cardRadius),
                ),
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
                  : Text(
                      'Save Journal',
                      style: t.h2Style.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppTokens t;

  const _SectionLabel({required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: t.labelStyle.copyWith(
        color: t.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final AppTokens t;
  final Widget child;

  const _GlassField({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

class _IntField extends StatelessWidget {
  final String label;
  final int? value;
  final AppTokens t;
  final ValueChanged<int?> onChanged;

  const _IntField({
    required this.label,
    required this.value,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        keyboardType: TextInputType.number,
        style: t.bodyStyle,
        controller: TextEditingController(text: value?.toString() ?? ''),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: t.miniStyle.copyWith(fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          onChanged(parsed);
        },
      ),
    );
  }
}
