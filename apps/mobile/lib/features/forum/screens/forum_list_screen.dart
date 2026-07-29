import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../data/forum_repository.dart';
import '../models/forum_question.dart';
import '../widgets/forum_category_chip.dart';

const List<String> _kCategories = [
  'technique',
  'rules',
  'competition',
  'schedule',
  'gear',
  'general',
];

class ForumListScreen extends ConsumerStatefulWidget {
  final String gymId;

  const ForumListScreen({super.key, required this.gymId});

  @override
  ConsumerState<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends ConsumerState<ForumListScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final questionsAsync = ref.watch(
      forumQuestionsProvider((gymId: widget.gymId, category: _category)),
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Forum', style: t.h2Style),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/gym/${widget.gymId}/forum/ask'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryFilterRow(
            selected: _category,
            onSelect: (cat) => setState(() => _category = cat),
            t: t,
          ),
          Expanded(
            child: questionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  "Couldn't load questions",
                  style: t.bodyStyle.copyWith(color: t.muted),
                ),
              ),
              data: (questions) => questions.isEmpty
                  ? Center(
                      child: Text(
                        'No questions yet. Be the first to ask!',
                        style: t.bodyStyle.copyWith(color: t.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: questions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => context.push(
                          '/gym/${widget.gymId}/forum/${questions[index].id}',
                        ),
                        child: _QuestionTile(question: questions[index], t: t),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category filter row ────────────────────────────────────────────────────────

class _CategoryFilterRow extends StatelessWidget {
  final String? selected;
  final void Function(String?) onSelect;
  final AppTokens t;

  const _CategoryFilterRow({
    required this.selected,
    required this.onSelect,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
            t: t,
          ),
          for (final cat in _kCategories)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: _categoryDisplayLabel(cat),
                selected: selected == cat,
                onTap: () => onSelect(cat),
                t: t,
              ),
            ),
        ],
      ),
    );
  }

  String _categoryDisplayLabel(String cat) {
    const labels = <String, String>{
      'technique': 'Technique',
      'rules': 'Rules',
      'competition': 'Competition',
      'schedule': 'Schedule',
      'gear': 'Gear',
      'general': 'General',
    };
    return labels[cat] ?? cat;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens t;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? t.primary : t.surface,
          borderRadius: BorderRadius.circular(t.badgeRadius),
          border: Border.all(
            color: selected ? t.primary : t.border,
          ),
        ),
        child: Text(
          label,
          style: t.miniStyle.copyWith(
            color: selected ? Colors.white : t.muted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Question tile ─────────────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  final ForumQuestion question;
  final AppTokens t;

  const _QuestionTile({required this.question, required this.t});

  @override
  Widget build(BuildContext context) {
    final answerLabel = question.answerCount == 1 ? '1 answer' : '${question.answerCount} answers';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (question.pinned) ...[
                Icon(Icons.push_pin, size: 14, color: t.amber),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  question.title,
                  style: t.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              if (question.acceptedAnswerId != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 16, color: t.green),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ForumCategoryChip(category: question.category),
              const SizedBox(width: 8),
              Text(
                answerLabel,
                style: t.miniStyle.copyWith(color: t.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
