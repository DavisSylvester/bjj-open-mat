import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/ticker_strip.dart';
import '../../open_mats/models/open_mat.dart';
import '../providers/discover_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  // The query driving the live feed. Starts location-less (plain list) and is
  // upgraded to a geo query once the device location resolves. Never null so
  // the feed always shows something while GPS is being captured.
  NearbyQuery _query = const NearbyQuery();

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    final loc = await ref.read(locationServiceProvider).current();
    if (!mounted || loc == null) return;
    setState(() {
      _query = NearbyQuery(lat: loc.latitude, lng: loc.longitude);
    });
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

  List<TickerItem> _tickerItems(List<OpenMat> mats) => mats
      .take(6)
      .map((m) => TickerItem(
            time: m.startLabel,
            gym: m.gymName ?? m.title,
            giType: m.giType,
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _buildSport(t) : _buildGlass(t);
  }

  Widget _buildSport(AppTokens t) {
    final results = ref.watch(nearbyOpenMatsProvider(_query));
    final mats = results.asData?.value ?? const <OpenMat>[];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red),
              const SizedBox(width: 8),
              Text('Open Mat', style: t.displayStyle.copyWith(fontSize: 22)),
              const Spacer(),
              Icon(LucideIcons.bell, size: 18, color: t.muted),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.go('/search'),
                child: Icon(LucideIcons.search, size: 18, color: t.muted),
              ),
            ]),
          ),
          if (mats.isNotEmpty) TickerStrip(items: _tickerItems(mats)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 10)),
              Text('Live Feed', style: t.h2Style.copyWith(fontSize: 15)),
              const Spacer(),
              Text('${mats.length} sessions', style: t.miniStyle),
            ]),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text("Couldn't load open mats", style: t.bodyStyle.copyWith(color: t.muted)),
              ),
              data: (list) => list.isEmpty
                  ? Center(child: Text('No open mats nearby', style: t.miniStyle))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: t.border),
                      itemBuilder: (_, i) => SessionRow(
                        session: _toRow(list[i]),
                        onTap: () => context.go('/open-mat/${list[i].id}'),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGlass(AppTokens t) {
    final results = ref.watch(nearbyOpenMatsProvider(_query));
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
                        Text('Good evening', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
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
                    child: Center(child: Text('MR', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
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
            // Live session cards
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text("Couldn't load open mats", style: t.bodyStyle.copyWith(color: t.muted)),
                ),
                data: (list) => list.isEmpty
                    ? Center(child: Text('No open mats nearby', style: t.miniStyle))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => SizedBox(
                          width: double.infinity,
                          child: SessionRow(
                            session: _toRow(list[i]),
                            onTap: () => context.go('/open-mat/${list[i].id}'),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
