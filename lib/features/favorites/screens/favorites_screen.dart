import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class _FavoriteGym {
  final String id;
  final String name;
  final String giType;
  final String distance;

  const _FavoriteGym({
    required this.id,
    required this.name,
    required this.giType,
    required this.distance,
  });
}

const _stubFavorites = [
  _FavoriteGym(id: '1', name: 'Atos HQ', giType: 'Gi & No-Gi', distance: '1.2 mi'),
  _FavoriteGym(id: '2', name: 'Renzo Gracie Westwood', giType: 'No-Gi', distance: '2.4 mi'),
  _FavoriteGym(id: '3', name: 'Gracie Barra Pasadena', giType: 'Gi', distance: '4.5 mi'),
  _FavoriteGym(id: '4', name: 'Alliance Jiu-Jitsu', giType: 'Both', distance: '3.1 mi'),
];

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport
        ? _SportFavorites(t: t)
        : _GlassFavorites(t: t);
  }
}

class _SportFavorites extends StatelessWidget {
  final AppTokens t;
  const _SportFavorites({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Masthead
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Container(width: 4, height: 28, color: t.red),
              const SizedBox(width: 10),
              Text('Favorites', style: t.h1Style.copyWith(fontSize: 22)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ListView.separated(
              itemCount: _stubFavorites.length,
              separatorBuilder: (context2, index) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) {
                final gym = _stubFavorites[i];
                return GestureDetector(
                  onTap: () => context.go('/gym/${gym.id}'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(left: BorderSide(color: t.red, width: 3)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gym.name,
                              style: t.h2Style.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gym.giType,
                              style: t.bodyStyle.copyWith(
                                color: t.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            gym.distance,
                            style: t.miniStyle.copyWith(fontSize: 11, color: t.body),
                          ),
                          const SizedBox(height: 4),
                          Icon(LucideIcons.heart, size: 16, color: t.red),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassFavorites extends StatelessWidget {
  final AppTokens t;
  const _GlassFavorites({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(LucideIcons.heart, color: t.red, size: 20),
              const SizedBox(width: 8),
              Text('Favorite Gyms', style: t.h1Style),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _stubFavorites.length,
              itemBuilder: (_, i) {
                final gym = _stubFavorites[i];
                return GestureDetector(
                  onTap: () => context.go('/gym/${gym.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.cardRadius),
                      border: Border.all(color: t.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: t.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(LucideIcons.building2, size: 20, color: t.red),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gym.name,
                              style: t.h2Style.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gym.giType,
                              style: t.bodyStyle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(LucideIcons.heart, size: 16, color: t.red),
                          const SizedBox(height: 4),
                          Text(
                            gym.distance,
                            style: t.miniStyle.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
