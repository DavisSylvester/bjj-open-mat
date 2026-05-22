import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/om_widgets.dart';
import '../models/gym.dart';

const _amenities = [
  _Amenity(Icons.local_parking_rounded,  'Parking'),
  _Amenity(Icons.shower_rounded,         'Showers'),
  _Amenity(Icons.wifi_rounded,           'WiFi'),
  _Amenity(Icons.door_front_door_rounded,'Changing'),
  _Amenity(Icons.storefront_rounded,     'Pro Shop'),
  _Amenity(Icons.water_drop_rounded,     'Water'),
];

const _upcoming = [
  _UpcomingSession('Tonight',  '7:00 PM',  GiType.gi),
  _UpcomingSession('Sat',      '11:00 AM', GiType.nogi),
  _UpcomingSession('Sun',      '12:00 PM', GiType.both),
];

class _Amenity {
  final IconData icon;
  final String label;
  const _Amenity(this.icon, this.label);
}

class _UpcomingSession {
  final String day;
  final String time;
  final GiType gi;
  const _UpcomingSession(this.day, this.time, this.gi);
}

class GymDetailScreen extends StatelessWidget {
  final String gymId;
  const GymDetailScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OMColors.bg,
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            // Hero banner
            SliverToBoxAdapter(
              child: _HeroBanner(onBack: () => context.pop()),
            ),

            // Directions card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on_rounded, size: 16, color: OMColors.crimson),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('9587 Distribution Ave, San Diego CA 92121', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, color: OMColors.body)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionBtn(
                              label: 'Directions',
                              icon: Icons.directions_rounded,
                              color: OMColors.crimson,
                              textColor: Colors.white,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionBtn(
                              label: 'Waze',
                              icon: Icons.route_rounded,
                              color: OMColors.surface,
                              textColor: OMColors.text,
                              bordered: true,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Amenities
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amenities', style: omH2(size: 16)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _amenities.map((a) => _AmenityChip(amenity: a)).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // This Week's Open Mats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text("This Week's Open Mats", style: omH2(size: 16)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 18,
                  child: Column(
                    children: List.generate(_upcoming.length, (i) {
                      final u = _upcoming[i];
                      final color = GiBadge.colorFor(u.gi);
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.133),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withValues(alpha: 0.333)),
                                  ),
                                  child: Icon(
                                    u.gi == GiType.gi ? Icons.sports_martial_arts
                                        : u.gi == GiType.nogi ? Icons.dry_cleaning
                                        : Icons.compare_arrows,
                                    size: 20,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(u.day, style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 15, color: OMColors.text, height: 1)),
                                          const SizedBox(width: 8),
                                          GiBadge(type: u.gi, small: true),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(u.time, style: omNum(color: OMColors.muted, size: 13)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 16, color: OMColors.muted),
                              ],
                            ),
                          ),
                          if (i < _upcoming.length - 1)
                            const Divider(height: 1, color: OMColors.borderDark, indent: 14, endIndent: 14),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

            // Mat Ratings
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('Mat Ratings', style: omH2(size: 16)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  borderRadius: 18,
                  child: const Column(
                    children: [
                      StarRow(label: 'Gym Quality',  value: 4.9),
                      Divider(height: 1, color: OMColors.borderDark),
                      StarRow(label: 'Level Match',  value: 4.6),
                      Divider(height: 1, color: OMColors.borderDark),
                      StarRow(label: 'Cleanliness',  value: 4.9),
                      Divider(height: 1, color: OMColors.borderDark),
                      StarRow(label: 'Friendliness', value: 4.8),
                    ],
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

class _HeroBanner extends StatelessWidget {
  final VoidCallback onBack;
  const _HeroBanner({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      height: 240 + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient bg
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [OMColors.crimson, OMColors.both],
              ),
            ),
          ),
          // Stripe texture
          Opacity(
            opacity: 0.18,
            child: CustomPaint(painter: _StripePainter()),
          ),
          // Darken bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD90E1326)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          // Large "A" initial
          Positioned(
            left: 18, bottom: 60,
            child: Text(
              'A',
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w900,
                fontSize: 140,
                color: Color(0x2DFFFFFF),
                height: 1,
              ),
            ),
          ),
          // Top buttons
          Positioned(
            top: topPad + 14, left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DarkIconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                _DarkIconBtn(icon: Icons.favorite_rounded, iconColor: OMColors.crimson),
              ],
            ),
          ),
          // Gym name
          Positioned(
            left: 18, right: 18, bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Established 2012 · Affiliate', style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.14, height: 1)),
                const SizedBox(height: 4),
                Text('Atos HQ', style: omH1(color: Colors.white, size: 30)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: OMColors.star),
                    const SizedBox(width: 4),
                    Text('4.8', style: omNum(color: Colors.white, size: 13)),
                    Text(' · 312 reviews · 1.2 mi', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.6;
    for (double y = -size.width; y < size.height + size.width; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DarkIconBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  const _DarkIconBtn({required this.icon, this.iconColor = Colors.white, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final _Amenity amenity;
  const _AmenityChip({super.key, required this.amenity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OMColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OMColors.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(amenity.icon, size: 14, color: OMColors.teal),
          const SizedBox(width: 6),
          Text(amenity.label, style: const TextStyle(fontFamily: 'Barlow', fontSize: 12, fontWeight: FontWeight.w500, color: OMColors.body)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool bordered;
  final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.textColor, this.bordered = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: bordered ? Border.all(color: OMColors.borderDark) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.1,
                color: textColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider stub consumed by GymAdminScreen
final gymDetailProvider = FutureProvider.family<Gym, String>((ref, id) async {
  throw UnimplementedError('gymDetailProvider not connected to API yet');
});
