import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../open_mats/data/session_repository.dart';
import '../../open_mats/models/open_mat.dart';

final mySessionsProvider = FutureProvider<List<OpenMat>>((ref) async {
  return ref.read(sessionRepositoryProvider).listMine();
});

class SessionMgmtScreen extends ConsumerWidget {
  const SessionMgmtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(mySessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySessionsProvider),
        child: sessionsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(mySessionsProvider)),
          data: (sessions) {
            if (sessions.isEmpty) return const EmptyState(title: 'No sessions', subtitle: 'Create your first open mat', icon: Icons.event);
            return ListView.builder(
              padding: const EdgeInsets.all(StitchTokens.md),
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: s.isCancelled ? StitchTokens.error.withValues(alpha: 0.15) : StitchTokens.accent.withValues(alpha: 0.15),
                    child: Icon(s.isCancelled ? Icons.cancel : Icons.event, color: s.isCancelled ? StitchTokens.error : StitchTokens.accent),
                  ),
                  title: Text(s.title, style: TextStyle(decoration: s.isCancelled ? TextDecoration.lineThrough : null)),
                  subtitle: Text('${s.dayName} ${s.startTime}–${s.endTime} • ${s.skillBadge}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { HapticFeedback.selectionClick(); context.go('/owner/sessions/${s.id}'); },
                ));
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StitchTokens.accent,
        onPressed: () => context.go('/owner/sessions/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
