import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../classes/data/class_repository.dart';
import '../../forum/data/forum_repository.dart';
import '../../forum/models/forum_question.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/models/gym.dart';
import '../data/home_gym_provider.dart';
import '../data/next_up.dart';

/// Hub screen for the "My Gym" tab.
///
/// Surfaces the resolved home gym's schedule, roster, forum and instructor
/// feedback from endpoints that already exist elsewhere in the app. Every
/// section watches its own provider and handles its own loading/error state
/// locally — one failing section renders nothing rather than taking the
/// whole hub down.
class MyGymScreen extends ConsumerWidget {
  const MyGymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final homeGymIdAsync = ref.watch(homeGymIdProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('My Gym', style: t.h2Style),
      ),
      body: homeGymIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EmptyState(t: t),
        data: (gymId) {
          if (gymId == null) return _EmptyState(t: t);
          return _Hub(t: t, gymId: gymId);
        },
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppTokens t;
  const _EmptyState({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mapPin, size: 40, color: t.muted),
            const SizedBox(height: 16),
            Text('Find your gym', style: t.h1Style.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'My Gym gives you quick access to your schedule, roster and forum '
              'once you have a home gym set.',
              textAlign: TextAlign.center,
              style: t.bodyStyle.copyWith(color: t.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('mygym-find-gym-button'),
              onPressed: () => context.go('/search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Find a gym'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hub ──────────────────────────────────────────────────────────────────────

class _Hub extends StatelessWidget {
  final AppTokens t;
  final String gymId;
  const _Hub({required this.t, required this.gymId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(t: t, gymId: gymId),
        const SizedBox(height: 16),
        _NextUp(t: t, gymId: gymId),
        const SizedBox(height: 16),
        _QuickActions(t: t, gymId: gymId),
        const SizedBox(height: 16),
        _RecentForum(t: t, gymId: gymId),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final AppTokens t;
  final String gymId;
  const _Header({required this.t, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymByIdProvider(gymId));
    return gymAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (Gym gym) => InkWell(
        onTap: () => context.push('/gym/$gymId'),
        borderRadius: BorderRadius.circular(t.cardRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        gym.name,
                        style: t.h2Style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (gym.isVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.green.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: t.green.withValues(alpha: 0.33)),
                        ),
                        child: Text(
                          'Verified',
                          style: t.miniStyle.copyWith(color: t.green, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Next up ──────────────────────────────────────────────────────────────────

class _NextUp extends ConsumerWidget {
  final AppTokens t;
  final String gymId;
  const _NextUp({required this.t, required this.gymId});

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final from = _isoDate(now);
    final to = _isoDate(now.add(const Duration(days: 7)));
    final schedAsync = ref.watch(scheduleProvider((gymId: gymId, from: from, to: to)));

    return schedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (classes) {
        final cls = nextUpcoming(classes, DateTime.now());
        if (cls == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next up', style: t.labelStyle.copyWith(color: t.muted, fontSize: 12)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.push(
                '/gym/$gymId/schedule/occurrence?classId=${cls.classId}&date=${cls.date}',
                extra: cls,
              ),
              borderRadius: BorderRadius.circular(t.cardRadius),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.title,
                      style: t.labelStyle.copyWith(fontWeight: FontWeight.w700, color: t.text),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 13, color: t.muted),
                        const SizedBox(width: 4),
                        Text(cls.startTime, style: t.miniStyle.copyWith(color: t.muted)),
                        if (cls.instructorName != null) ...[
                          const SizedBox(width: 12),
                          Icon(LucideIcons.user, size: 13, color: t.muted),
                          const SizedBox(width: 4),
                          Text(cls.instructorName!, style: t.miniStyle.copyWith(color: t.muted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Quick actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final AppTokens t;
  final String gymId;
  const _QuickActions({required this.t, required this.gymId});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        key: 'mygym-action-schedule',
        icon: LucideIcons.calendar,
        label: 'Schedule',
        path: '/gym/$gymId/schedule',
      ),
      _QuickAction(
        key: 'mygym-action-roster',
        icon: LucideIcons.users,
        label: 'Roster',
        path: '/gym/$gymId/roster',
      ),
      _QuickAction(
        key: 'mygym-action-forum',
        icon: LucideIcons.messageSquare,
        label: 'Forum',
        path: '/gym/$gymId/forum',
      ),
      _QuickAction(
        key: 'mygym-action-instructor-feedback',
        icon: LucideIcons.star,
        label: 'Feedback',
        path: '/gym/$gymId/instructor-feedback',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        for (final a in actions)
          InkWell(
            key: Key(a.key),
            onTap: () => context.push(a.path),
            borderRadius: BorderRadius.circular(t.cardRadius),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Icon(a.icon, size: 18, color: t.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.label,
                      style: t.labelStyle.copyWith(color: t.text, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickAction {
  final String key;
  final IconData icon;
  final String label;
  final String path;
  const _QuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.path,
  });
}

// ── Recent forum activity ────────────────────────────────────────────────────

class _RecentForum extends ConsumerWidget {
  final AppTokens t;
  final String gymId;
  const _RecentForum({required this.t, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(forumQuestionsProvider((gymId: gymId, category: null)));

    return questionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (List<ForumQuestion> questions) {
        if (questions.isEmpty) return const SizedBox.shrink();
        final recent = questions.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From the forum', style: t.labelStyle.copyWith(color: t.muted, fontSize: 12)),
            const SizedBox(height: 8),
            for (final q in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/gym/$gymId/forum'),
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.cardRadius),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.title,
                            style: t.labelStyle.copyWith(color: t.text, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.messageCircle, size: 13, color: t.muted),
                        const SizedBox(width: 4),
                        Text('${q.answerCount}', style: t.miniStyle.copyWith(color: t.muted)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
