import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart' show ErrorState;
import '../../gyms/models/gym.dart';
import '../data/favorite_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myFavoritesProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(LucideIcons.heart, color: t.red, size: 20),
              const SizedBox(width: 8),
              Text('Favorite Gyms', style: t.h1Style),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load favorites",
                onRetry: () => ref.invalidate(myFavoritesProvider),
              ),
              data: (gyms) => gyms.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.heart,
                      title: 'No favorite gyms yet',
                      subtitle: 'Open a gym and tap the heart to save it here.',
                      actionLabel: 'Find gyms',
                      onAction: () => context.go('/search'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: gyms.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FavoriteRow(t: t, gym: gyms[i]),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  final AppTokens t;
  final Gym gym;
  const _FavoriteRow({required this.t, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = [gym.city, gym.state].where((s) => s != null && s.isNotEmpty).join(', ');
    return GestureDetector(
      onTap: () => context.push('/gym/${gym.id}'),
      child: Container(
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
              Text(gym.name, style: t.h2Style.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                location.isEmpty ? gym.address : location,
                style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
              ),
            ]),
          ),
          if (gym.rating != null) ...[
            Icon(LucideIcons.star, size: 14, color: t.amber),
            const SizedBox(width: 4),
            Text(gym.rating!.toStringAsFixed(1), style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
            const SizedBox(width: 12),
          ],
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(favoriteRepositoryProvider).remove(gym.id);
                ref.invalidate(myFavoritesProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Couldn't remove favorite")),
                  );
                }
              }
            },
            child: Icon(LucideIcons.heart, size: 18, color: t.red),
          ),
        ]),
      ),
    );
  }
}
