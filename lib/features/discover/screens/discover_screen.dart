import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../open_mats/models/open_mat.dart';
import '../providers/discover_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  // Default to NYC for demo — in production, use Geolocator
  final double _lat = 40.7128;
  final double _lng = -74.0060;
  bool _showToday = true;

  NearbyQuery get _query => NearbyQuery(
    lat: _lat,
    lng: _lng,
    date: DateTime.now().toIso8601String().split('T').first,
  );

  @override
  Widget build(BuildContext context) {
    final openMatsAsync = ref.watch(nearbyOpenMatsProvider(_query));

    return Scaffold(
      body: Stack(
        children: [
          // Map placeholder
          Container(
            color: StitchTokens.primary.withValues(alpha: 0.1),
            child: const Center(
              child: Icon(Icons.map, size: 120, color: StitchTokens.textSecondary),
            ),
          ),

          // Bottom sheet with nearby open mats
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(StitchTokens.radiusXl)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: StitchTokens.textSecondary, borderRadius: BorderRadius.circular(2)),
                    ),
                    // Toggle
                    Padding(
                      padding: const EdgeInsets.all(StitchTokens.md),
                      child: Row(
                        children: [
                          Text('Nearby Open Mats', style: Theme.of(context).textTheme.headlineMedium),
                          const Spacer(),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Today')),
                              ButtonSegment(value: false, label: Text('Week')),
                            ],
                            selected: {_showToday},
                            onSelectionChanged: (v) => setState(() => _showToday = v.first),
                          ),
                        ],
                      ),
                    ),
                    // List
                    Expanded(
                      child: openMatsAsync.when(
                        loading: () => const ShimmerList(),
                        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(nearbyOpenMatsProvider(_query))),
                        data: (mats) {
                          if (mats.isEmpty) {
                            return const EmptyState(
                              title: 'No open mats nearby',
                              subtitle: 'Try expanding your search radius',
                              icon: Icons.sports_martial_arts,
                            );
                          }
                          return ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(horizontal: StitchTokens.md),
                            itemCount: mats.length,
                            itemBuilder: (context, index) => _OpenMatCard(mat: mats[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StitchTokens.secondary,
        onPressed: () {
          HapticFeedback.lightImpact();
          // Re-center on current location
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

class _OpenMatCard extends StatelessWidget {
  final OpenMat mat;
  const _OpenMatCard({required this.mat});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: StitchTokens.sm),
      onTap: () {
        HapticFeedback.selectionClick();
        context.go('/open-mat/${mat.id}');
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: StitchTokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
            ),
            child: const Icon(Icons.sports_martial_arts, color: StitchTokens.accent),
          ),
          const SizedBox(width: StitchTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mat.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${mat.gymName ?? "Unknown gym"} • ${mat.startTime}–${mat.endTime}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(label: mat.skillBadge, color: StitchTokens.accent),
                    const SizedBox(width: 6),
                    _Badge(label: mat.giBadge, color: StitchTokens.secondary),
                    if (mat.distanceKm != null) ...[
                      const SizedBox(width: 6),
                      Text('${mat.distanceKm!.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: StitchTokens.textSecondary),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(StitchTokens.radiusPill),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
