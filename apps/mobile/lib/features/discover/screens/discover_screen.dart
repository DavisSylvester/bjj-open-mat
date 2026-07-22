import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/nearby_gym_card.dart';
import '../../../shared/widgets/session_row.dart';
import '../../open_mats/models/open_mat.dart';
import '../providers/discover_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch GPS once via the shared controller (cached + reused by the Find
    // screen). Deferred to post-frame so we don't mutate providers during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(locationControllerProvider.notifier).ensure());
  }

  /// Map an [OpenMat] to the presentational [SessionRowData] used by rows.
  SessionRowData _toRow(OpenMat mat) {
    return SessionRowData(
      id: mat.id,
      gymName: mat.gymName ?? mat.title,
      giType: mat.giType,
      expLevel: _expLevel(mat.skillLevel),
      time: mat.startLabel,
      day: mat.dayName,
      distance: mat.distanceKm != null
          ? '${(mat.distanceKm! / 1.60934).toStringAsFixed(1)} mi'
          : '',
      fee: (mat.feeCents ?? 0) / 100,
      isLive: mat.status == 'live',
      unverified: !mat.verified,
    );
  }

  /// Up-to-two-letter initials from the signed-in user's name (avatar chip).
  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'ME';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _expLevel(String skillLevel) {
    switch (skillLevel) {
      case 'beginner':
        return 'beg';
      case 'intermediate':
        return 'int';
      case 'advanced':
        return 'adv';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _buildGlass(t);
  }

  Widget _buildGlass(AppTokens t) {
    final locState = ref.watch(locationControllerProvider);
    final query = locState.hasCoords ? NearbyQuery(lat: locState.lat, lng: locState.lng) : const NearbyQuery();
    final results = ref.watch(nearbyOpenMatsProvider(query));
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Greeting header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (locState.status == LocationStatus.loading)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text('Locating…', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
                            ],
                          )
                        else
                          Text(locState.label ?? 'Near you', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Find your roll', style: t.h1Style.copyWith(fontSize: 26)),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.primary, t.both],
                      ),
                    ),
                    child: Center(child: Text(_initials(ref.watch(authStateProvider).user?.displayName), style: t.miniStyle.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                  ),
                ],
              ),
            ),
            // Search bar row (taps through to the search tab)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: GestureDetector(
                onTap: () => context.go('/search'),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Icon(LucideIcons.search, size: 18, color: t.muted),
                        const SizedBox(width: 10),
                        Text('Search gyms or area', style: t.bodyStyle.copyWith(color: t.muted, fontSize: 14)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: t.primary.withValues(alpha: 0.27), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Icon(LucideIcons.sliders, size: 20, color: Colors.white),
                  ),
                ]),
              ),
            ),
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEAR YOU', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text('Open Mats', style: t.h2Style),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/search'),
                    child: Text('See all', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
            // Feed: open mats, then an always-on "Gyms near you" section.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    results.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text("Couldn't load open mats", style: t.bodyStyle.copyWith(color: t.muted)),
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            icon: LucideIcons.mapPin,
                            title: locState.label != null ? 'No open mats found in ${locState.label}' : 'No open mats found nearby',
                            subtitle: 'Try widening your search or check back soon.',
                            actionLabel: 'Search',
                            onAction: () => context.go('/search'),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final mat in list) ...[
                              SizedBox(
                                width: double.infinity,
                                child: SessionRow(
                                  session: _toRow(mat),
                                  onTap: () => context.push('/open-mat/${mat.id}'),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        );
                      },
                    ),
                    if (locState.hasCoords) _NearbyGymsSection(lat: locState.lat!, lng: locState.lng!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-on "Gyms near you" section: every gym within 50 miles (80 km) of the
/// device, sourced from [nearbyGymsProvider]. Hidden while empty/erroring.
class _NearbyGymsSection extends ConsumerWidget {
  final double lat;
  final double lng;

  const _NearbyGymsSection({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymsAsync = ref.watch(nearbyGymsProvider(NearbyQuery(lat: lat, lng: lng, radiusKm: 80)));

    return gymsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text("Couldn't load nearby gyms", style: t.miniStyle.copyWith(color: t.muted)),
      ),
      data: (gyms) {
        if (gyms.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('GYMS NEAR YOU', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
            const SizedBox(height: 3),
            Text('Within 50 miles', style: t.h2Style),
            const SizedBox(height: 14),
            for (final gym in gyms) ...[
              NearbyGymCard(gym: gym),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}
