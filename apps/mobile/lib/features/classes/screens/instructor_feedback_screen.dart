import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../data/class_journal_repository.dart';
import '../models/instructor_feedback_item.dart';

class InstructorFeedbackScreen extends ConsumerWidget {
  final String gymId;

  const InstructorFeedbackScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final feedbackAsync = ref.watch(gymInstructorFeedbackProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
        title: Text('Instructor Feedback', style: t.h2Style),
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load feedback",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No feedback yet.',
                style: t.bodyStyle.copyWith(color: t.muted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _FeedbackCard(item: items[index], t: t),
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final InstructorFeedbackItem item;
  final AppTokens t;

  const _FeedbackCard({required this.item, required this.t});

  @override
  Widget build(BuildContext context) {
    final author =
        item.anonymous ? 'Anonymous' : (item.ratedByName ?? 'Member');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars + author row
          Row(
            children: [
              _StarRow(stars: item.stars, t: t),
              const Spacer(),
              Text(
                author,
                style: t.miniStyle.copyWith(
                  color: t.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Comment
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.comment!, style: t.bodyStyle.copyWith(fontSize: 14)),
          ],
          // Date
          const SizedBox(height: 6),
          Text(
            item.date,
            style: t.miniStyle.copyWith(color: t.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  final AppTokens t;

  const _StarRow({required this.stars, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? LucideIcons.star : LucideIcons.star,
          size: 14,
          color: i < stars ? t.amber : t.border,
        );
      }),
    );
  }
}
