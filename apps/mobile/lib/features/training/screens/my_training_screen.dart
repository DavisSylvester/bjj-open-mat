import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart' show ErrorState;
import '../../checkins/models/checkin.dart';
import '../../classes/data/class_journal_repository.dart';
import '../../classes/models/class_journal_entry.dart';
import '../data/training_provider.dart';
import '../data/training_stats.dart';

class MyTrainingScreen extends ConsumerWidget {
  const MyTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myTrainingProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR PROGRESS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text('My Training', style: t.h1Style),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load your training log",
                onRetry: () => ref.invalidate(myTrainingProvider),
              ),
              data: (history) => _TrainingBody(t: t, history: history),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TrainingBody extends ConsumerWidget {
  final AppTokens t;
  final TrainingHistory history;
  const _TrainingBody({required this.t, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 90)).toIso8601String().substring(0, 10);
    final to = now.toIso8601String().substring(0, 10);
    final journalAsync = ref.watch(myJournalProvider((from: from, to: to)));

    final stats = computeTrainingStats(history.items, totalMats: history.total);
    if (history.items.isEmpty) {
      return SingleChildScrollView(
        child: Column(children: [
          const EmptyState(
            icon: LucideIcons.calendarCheck,
            title: 'No sessions yet',
            subtitle: 'Check in at an open mat to start your training log.',
          ),
          _JournalSection(t: t, journalAsync: journalAsync),
        ]),
      );
    }
    return SingleChildScrollView(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.border),
              boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              _TrainingStatCell(label: 'Mats', value: '${stats.mats}', t: t, borderRight: true),
              _TrainingStatCell(label: 'Gyms', value: '${stats.gyms}', t: t, borderRight: true),
              _TrainingStatCell(label: 'Rounds', value: '${stats.rounds}', t: t, borderRight: true),
              _TrainingStatCell(label: 'Streak', value: '${stats.streakWeeks}w', t: t, borderRight: false),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Session History', style: t.h2Style),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: history.items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CheckInRow(t: t, c: history.items[i]),
          ),
        ),
        _JournalSection(t: t, journalAsync: journalAsync),
      ]),
    );
  }
}

class _JournalSection extends StatelessWidget {
  final AppTokens t;
  final AsyncValue<List<ClassJournalEntry>> journalAsync;

  const _JournalSection({required this.t, required this.journalAsync});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text('Class journal', style: t.h2Style),
        ),
        journalAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Failed to load class journal', style: TextStyle(color: t.muted)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'No class journal entries yet',
                  style: t.miniStyle.copyWith(color: t.muted),
                ),
              );
            }
            final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: sorted.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JournalEntryRow(t: t, entry: sorted[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JournalEntryRow extends StatelessWidget {
  final AppTokens t;
  final ClassJournalEntry entry;

  const _JournalEntryRow({required this.t, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatSessionDate(entry.date),
            style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            entry.whatWasTaught ?? '—',
            style: t.h2Style.copyWith(fontSize: 15),
          ),
          if (entry.techniqueTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.techniqueTags
                  .map((tag) => _TechniqueChip(t: t, tag: tag))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TechniqueChip extends StatelessWidget {
  final AppTokens t;
  final String tag;

  const _TechniqueChip({required this.t, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.faint,
        borderRadius: BorderRadius.circular(t.badgeRadius),
        border: Border.all(color: t.border),
      ),
      child: Text(
        tag,
        style: t.miniStyle.copyWith(fontSize: 11, color: t.body),
      ),
    );
  }
}

class _CheckInRow extends StatelessWidget {
  final AppTokens t;
  final CheckIn c;
  const _CheckInRow({required this.t, required this.c});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (c.rounds != null) '${c.rounds} rounds',
      if (c.partners != null) '${c.partners} partners',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.gymName ?? c.openMatTitle ?? 'Open mat', style: t.h2Style.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              details.isEmpty ? formatSessionDate(c.sessionDate) : '${formatSessionDate(c.sessionDate)} · ${details.join(' · ')}',
              style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
            ),
          ]),
        ),
        if (c.rating != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.star, size: 14, color: t.amber),
            const SizedBox(width: 4),
            Text('${c.rating}', style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
          ]),
      ]),
    );
  }
}

class _TrainingStatCell extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;
  final bool borderRight;
  const _TrainingStatCell({required this.label, required this.value, required this.t, required this.borderRight});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: borderRight ? Border(right: BorderSide(color: t.border)) : null,
        ),
        child: Column(children: [
          Text(value, style: t.numStyle.copyWith(fontSize: 20, color: t.text)),
          const SizedBox(height: 3),
          Text(label, style: t.miniStyle.copyWith(fontSize: 9, color: t.muted)),
        ]),
      ),
    );
  }
}
