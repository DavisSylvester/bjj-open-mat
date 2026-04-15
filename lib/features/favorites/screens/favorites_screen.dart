import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../gyms/models/gym.dart';

final favoritesProvider = FutureProvider<List<Gym>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.myFavorites);
  final raw = response.data['data'];
  final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
  return data.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favsAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Gyms')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(favoritesProvider),
        child: favsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(favoritesProvider)),
          data: (gyms) {
            if (gyms.isEmpty) return const EmptyState(title: 'No favorites yet', subtitle: 'Heart a gym to save it here', icon: Icons.favorite_border);
            return ListView.builder(
              padding: const EdgeInsets.all(StitchTokens.md),
              itemCount: gyms.length,
              itemBuilder: (context, i) {
                final gym = gyms[i];
                return Dismissible(
                  key: Key(gym.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: StitchTokens.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    HapticFeedback.mediumImpact();
                    final api = ref.read(apiClientProvider);
                    await api.delete(Endpoints.gymFavorite(gym.id));
                    ref.invalidate(favoritesProvider);
                  },
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: StitchTokens.secondary.withValues(alpha: 0.15), child: const Icon(Icons.store, color: StitchTokens.secondary)),
                    title: Text(gym.name),
                    subtitle: Text(gym.address),
                    trailing: gym.distanceKm != null ? Text('${gym.distanceKm!.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodySmall) : null,
                    onTap: () { HapticFeedback.selectionClick(); context.go('/gym/${gym.id}'); },
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
