import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/om_widgets.dart';

const _mockSessions = [
  SessionData(id: '1', gym: 'Atos HQ',              time: '7:00 – 9:00 PM',   day: 'Today', dist: '1.2 mi', gi: GiType.gi,   exp: ExpLevel.all,          fee: 0),
  SessionData(id: '2', gym: 'Gracie Barra DTLA',    time: '10:00 – 12:00 PM', day: 'Sat',   dist: '2.4 mi', gi: GiType.nogi, exp: ExpLevel.intermediate, fee: 15),
  SessionData(id: '3', gym: '10th Planet Rosemead', time: '12:00 – 2:00 PM',  day: 'Sun',   dist: '4.1 mi', gi: GiType.both, exp: ExpLevel.all,          fee: 10),
  SessionData(id: '4', gym: 'CheckMat South Bay',   time: '6:00 – 8:00 PM',   day: 'Mon',   dist: '3.8 mi', gi: GiType.gi,   exp: ExpLevel.beginner,    fee: 0),
];

class _FilterChipData {
  final String label;
  final bool active;
  final Color? color;
  const _FilterChipData({required this.label, required this.active, this.color});
}

const _filters = [
  _FilterChipData(label: 'Gi',        active: true,  color: OMColors.gi),
  _FilterChipData(label: 'No-Gi',     active: false, color: OMColors.noGi),
  _FilterChipData(label: 'Both',      active: true,  color: OMColors.both),
  _FilterChipData(label: 'Free',      active: true,  color: OMColors.teal),
  _FilterChipData(label: 'All Levels',active: false),
  _FilterChipData(label: 'Beginner',  active: false),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: OMColors.bg,
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPad + 8)),

            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Row(
                  children: [
                    Text('Find a Mat', style: omH1()),
                    const Spacer(),
                    GlassCard(
                      padding: const EdgeInsets.all(9),
                      borderRadius: 12,
                      child: const Icon(Icons.location_on_rounded, size: 18, color: OMColors.crimson),
                    ),
                  ],
                ),
              ),
            ),

            // Location input
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  borderRadius: 16,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 18, color: OMColors.muted),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Los Angeles, CA',
                            style: TextStyle(fontFamily: 'Barlow', fontSize: 15, fontWeight: FontWeight.w500, color: OMColors.text),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: OMColors.crimson.withValues(alpha: 0.133),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.gps_fixed_rounded, size: 14, color: OMColors.crimson),
                              const SizedBox(width: 4),
                              Text('GPS', style: omEyebrow(color: OMColors.crimson, size: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final accent = f.color ?? OMColors.crimson;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: f.active ? accent.withValues(alpha: 0.165) : OMColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: f.active ? accent.withValues(alpha: 0.533) : OMColors.borderDark,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (f.active) ...[
                            Icon(Icons.check_rounded, size: 12, color: accent),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            f.label,
                            style: TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.1,
                              color: f.active ? accent : OMColors.body,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Date + distance row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WHEN', style: omEyebrow(size: 10)),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(Icons.calendar_today_rounded, size: 14, color: OMColors.crimson),
                                SizedBox(width: 6),
                                Text('This Weekend', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, fontWeight: FontWeight.w600, color: OMColors.text)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('WITHIN', style: omEyebrow(size: 10)),
                                const Spacer(),
                                Text('8 mi', style: omNum(size: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LayoutBuilder(builder: (ctx, c) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: OMColors.faint,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                Container(
                                  height: 4,
                                  width: c.maxWidth * 0.4,
                                  decoration: BoxDecoration(
                                    color: OMColors.crimson,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                Positioned(
                                  left: c.maxWidth * 0.4 - 7,
                                  top: -5,
                                  child: Container(
                                    width: 14, height: 14,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
                                    ),
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Results header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '12', style: omH2(color: OMColors.crimson, size: 16)),
                          TextSpan(text: ' Sessions', style: omH2(size: 16)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      borderRadius: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: OMColors.crimson),
                          const SizedBox(width: 4),
                          Text('Map View', style: omEyebrow(color: OMColors.text, size: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Session list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: OMSessionCard(session: _mockSessions[i]),
                ),
                childCount: _mockSessions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}
