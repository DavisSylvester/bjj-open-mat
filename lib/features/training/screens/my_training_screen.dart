import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../checkins/models/checkin.dart';

final myCheckinsProvider = FutureProvider<List<CheckIn>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.myCheckins, queryParameters: {'page': 1, 'limit': 50});
  final raw = response.data['data'];
  final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
  return data.map((e) => CheckIn.fromJson(e as Map<String, dynamic>)).toList();
});

class MyTrainingScreen extends ConsumerWidget {
  const MyTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(myCheckinsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Training')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myCheckinsProvider),
        child: checkinsAsync.when(
          loading: () => const ShimmerList(itemCount: 6),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(myCheckinsProvider)),
          data: (checkins) {
            if (checkins.isEmpty) {
              return const EmptyState(title: 'No training yet', subtitle: 'Check in to your first open mat!', icon: Icons.fitness_center);
            }
            return Column(
              children: [
                // Stats header
                Padding(
                  padding: const EdgeInsets.all(StitchTokens.md),
                  child: Row(
                    children: [
                      _StatCard(label: 'Sessions', value: '${checkins.length}', icon: Icons.check_circle, color: StitchTokens.accent),
                      const SizedBox(width: StitchTokens.sm),
                      _StatCard(label: 'Avg Rating', value: _avgRating(checkins), icon: Icons.star, color: StitchTokens.warning),
                    ],
                  ),
                ),
                // History list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: StitchTokens.md),
                    itemCount: checkins.length,
                    itemBuilder: (context, i) {
                      final c = checkins[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: StitchTokens.accent.withValues(alpha: 0.15),
                          child: const Icon(Icons.sports_martial_arts, color: StitchTokens.accent, size: 20),
                        ),
                        title: Text(c.openMatTitle ?? 'Open Mat'),
                        subtitle: Text('${c.gymName ?? ""} • ${c.sessionDate}'),
                        trailing: c.rating != null
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${c.rating}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Icon(Icons.star, size: 16, color: StitchTokens.warning),
                              ])
                            : c.canReview
                                ? TextButton(onPressed: () { HapticFeedback.selectionClick(); }, child: const Text('Review'))
                                : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _avgRating(List<CheckIn> checkins) {
    final rated = checkins.where((c) => c.rating != null);
    if (rated.isEmpty) return '--';
    final avg = rated.map((c) => c.rating!).reduce((a, b) => a + b) / rated.length;
    return avg.toStringAsFixed(1);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(StitchTokens.md),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
