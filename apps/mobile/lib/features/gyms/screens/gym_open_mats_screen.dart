import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api/friendly_error.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/session_row.dart';
import '../data/gym_sessions_provider.dart';

/// Every open mat posted by one gym.
///
/// Previously an inline section on the gym detail screen. Open mats are the
/// app's core concept, so they get their own screen rather than sitting at the
/// bottom of a long scroll.
class GymOpenMatsScreen extends ConsumerWidget {
  final String gymId;

  const GymOpenMatsScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final sessionsAsync = ref.watch(gymSessionsProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        // Guarded: this screen is reachable from the gym page and from the My
        // Gym hub, so a bare pop() would dead-end when there is no history.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/gym/$gymId'),
        ),
        title: Text('Open Mats', style: t.h2Style),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(gymSessionsProvider(gymId)),
          child: sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: friendlyErrorMessage(e),
              onRetry: () => ref.invalidate(gymSessionsProvider(gymId)),
            ),
            data: (mats) => mats.isEmpty
                ? _EmptyState(
                    t: t,
                    onPost: () async {
                      await context.push('/add-session', extra: gymId);
                      ref.invalidate(gymSessionsProvider(gymId));
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: mats.length,
                    itemBuilder: (context, i) {
                      final m = mats[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SessionRow(
                          session: sessionRowFromOpenMat(m),
                          onTap: () => context.push('/open-mat/${m.id}'),
                          showGymName: false,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppTokens t;
  final VoidCallback onPost;
  const _EmptyState({required this.t, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('gym-open-mats-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarOff, size: 40, color: t.faint),
            const SizedBox(height: 16),
            Text(
              'No open mats posted yet.',
              textAlign: TextAlign.center,
              style: t.bodyStyle.copyWith(color: t.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('gym-open-mats-post-button'),
              onPressed: onPost,
              child: const Text('Post an open mat'),
            ),
          ],
        ),
      ),
    );
  }
}
