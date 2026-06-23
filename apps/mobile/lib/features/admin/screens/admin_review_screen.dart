import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../open_mats/data/session_repository.dart';
import '../../open_mats/models/open_mat.dart';

final adminUnverifiedProvider = FutureProvider<List<OpenMat>>((ref) async {
  return ref.read(sessionRepositoryProvider).listUnverified();
});

class AdminReviewScreen extends ConsumerWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(adminUnverifiedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review submissions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminUnverifiedProvider),
        child: sessionsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(adminUnverifiedProvider)),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyState(
                title: 'Nothing to review',
                subtitle: 'No unverified sessions',
                icon: Icons.check_circle_outline,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(StitchTokens.md),
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: StitchTokens.accent.withValues(alpha: 0.15),
                      child: Icon(Icons.event, color: StitchTokens.accent),
                    ),
                    title: Text(s.title),
                    subtitle: Text('${s.dayName} ${s.startTime}–${s.endTime} • ${s.skillBadge}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final repo = ref.read(sessionRepositoryProvider);
                        if (v == 'verify') {
                          await repo.verify(s.id);
                        } else if (v == 'hide') {
                          await repo.hide(s.id);
                        }
                        ref.invalidate(adminUnverifiedProvider);
                      },
                      itemBuilder: (_) => [
                        if (!s.verified) const PopupMenuItem(value: 'verify', child: Text('Verify')),
                        const PopupMenuItem(value: 'hide', child: Text('Hide')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
