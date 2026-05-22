import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/om_widgets.dart';

// Mock sessions for design-match display
const _mockSessions = [
  SessionData(id: '1', gym: 'Atos HQ',              time: '7:00 – 9:00 PM',   day: 'Today', dist: '1.2 mi', gi: GiType.gi,   exp: ExpLevel.all,          fee: 0),
  SessionData(id: '2', gym: 'Gracie Barra DTLA',    time: '10:00 – 12:00 PM', day: 'Sat',   dist: '2.4 mi', gi: GiType.nogi, exp: ExpLevel.intermediate, fee: 15),
  SessionData(id: '3', gym: '10th Planet Rosemead', time: '12:00 – 2:00 PM',  day: 'Sun',   dist: '4.1 mi', gi: GiType.both, exp: ExpLevel.all,          fee: 10),
  SessionData(id: '4', gym: 'CheckMat South Bay',   time: '6:00 – 8:00 PM',   day: 'Mon',   dist: '3.8 mi', gi: GiType.gi,   exp: ExpLevel.beginner,    fee: 0),
];

const _mapPins = [
  _MapPin(x: 0.22, y: 0.35, gi: GiType.gi,   active: false),
  _MapPin(x: 0.55, y: 0.30, gi: GiType.both, active: true),
  _MapPin(x: 0.78, y: 0.50, gi: GiType.nogi, active: false),
  _MapPin(x: 0.35, y: 0.65, gi: GiType.gi,   active: false),
  _MapPin(x: 0.68, y: 0.78, gi: GiType.nogi, active: false),
  _MapPin(x: 0.15, y: 0.80, gi: GiType.both, active: false),
];

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OMColors.bg,
      body: Stack(
        children: [
          // Full-screen map placeholder
          Positioned.fill(child: _MapBackdrop(pins: _mapPins)),

          // Status bar gradient overlay
          Positioned(
            top: 0, left: 0, right: 0, height: 80,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3141826), Colors.transparent],
                ),
              ),
            ),
          ),

          // Floating search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16, right: 16,
            child: _FloatingSearchBar(),
          ),

          // GPS button
          Positioned(
            right: 16, bottom: 440,
            child: DarkPillButton(
              onTap: () => HapticFeedback.lightImpact(),
              child: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                child: const Icon(Icons.gps_fixed_rounded, size: 20, color: OMColors.crimson),
              ),
            ),
          ),

          // Count chip
          Positioned(
            left: 16, bottom: 440,
            child: DarkPillButton(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: OMColors.teal, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: OMColors.teal.withValues(alpha: 0.6), blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      '18 MATS OPEN NEAR YOU',
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.1,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomSheet(),
          ),
        ],
      ),
    );
  }
}

class _FloatingSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xD914182E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OMColors.borderHi),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, size: 18, color: Color(0xA0FFFFFF)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Search gyms or area',
                      style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white, height: 1),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Los Angeles, CA · 10mi',
                      style: TextStyle(fontFamily: 'Barlow', fontSize: 11, color: Color(0x99FFFFFF), height: 1),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 22, color: const Color(0x33FFFFFF)),
              const SizedBox(width: 10),
              const Icon(Icons.tune_rounded, size: 18, color: OMColors.crimson),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: OMColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, -20)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: OMColors.faint,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TONIGHT & TOMORROW', style: omEyebrow(color: OMColors.crimson)),
                    const SizedBox(height: 4),
                    Text('Open Mats', style: omH1(size: 28)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text('See all', style: omEyebrow()),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: OMColors.muted),
                  ],
                ),
              ],
            ),
          ),
          // Horizontal cards
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              itemCount: _mockSessions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => OMSessionCard(session: _mockSessions[i], width: 266),
            ),
          ),
          SizedBox(height: 12 + bottomPad),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Backdrop — dark navy with street grid & pins
// ─────────────────────────────────────────────────────────────────────────────

class _MapPin {
  final double x;
  final double y;
  final GiType gi;
  final bool active;
  const _MapPin({required this.x, required this.y, required this.gi, required this.active});
}

class _MapBackdrop extends StatelessWidget {
  final List<_MapPin> pins;
  const _MapBackdrop({super.key, required this.pins});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark navy base
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.6),
                  radius: 1.2,
                  colors: [Color(0xFF1A2348), Color(0xFF0E1326)],
                ),
              ),
            ),
            // Street grid + water
            CustomPaint(painter: _MapGridPainter()),
            // Map pins — positioned at fractional coordinates
            ...pins.map((p) {
              final color = GiBadge.colorFor(p.gi);
              final size = p.active ? 44.0 : 36.0;
              final iconSize = p.active ? 22.0 : 18.0;
              final cx = w * p.x;
              final cy = h * p.y;
              return Positioned(
                left: cx - size / 2,
                top: cy - size - 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size, height: size,
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: Icon(
                        p.gi == GiType.gi   ? Icons.sports_martial_arts
                            : p.gi == GiType.nogi ? Icons.dry_cleaning
                            : Icons.compare_arrows,
                        size: iconSize, color: Colors.white,
                      ),
                    ),
                    CustomPaint(
                      size: const Size(12, 8),
                      painter: _PinArrowPainter(color: color),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    // Grid
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final roadPaint = Paint()..strokeWidth = 6;
    roadPaint.color = Colors.white.withValues(alpha: 0.08);
    canvas.drawLine(Offset(-20, size.height * 0.24), Offset(size.width + 20, size.height * 0.34), roadPaint);
    canvas.drawLine(Offset(-20, size.height * 0.63), Offset(size.width + 20, size.height * 0.53), roadPaint);
    roadPaint.color = Colors.white.withValues(alpha: 0.07);
    roadPaint
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawLine(Offset(size.width * 0.30, -20), Offset(size.width * 0.25, size.height + 20), roadPaint);
    canvas.drawLine(Offset(size.width * 0.65, -20), Offset(size.width * 0.75, size.height + 20), roadPaint);

    // Water
    final waterPaint = Paint()..color = const Color(0x122196F3);
    final waterPath = Path()
      ..moveTo(-20, size.height * 0.74)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.68, size.width * 0.80, size.height * 0.73)
      ..lineTo(size.width + 20, size.height * 0.79)
      ..lineTo(size.width + 20, size.height + 20)
      ..lineTo(-20, size.height + 20)
      ..close();
    canvas.drawPath(waterPath, waterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _PinArrowPainter extends CustomPainter {
  final Color color;
  const _PinArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
