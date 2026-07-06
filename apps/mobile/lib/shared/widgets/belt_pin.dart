import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The "Belt Pin" brand mark (Logo v3): a location pin whose ring is a BJJ
/// belt — solid rank color, three stitched rows, and a rank bar with stripes
/// at the lower-left. Ported 1:1 from the brand's SVG (64×64 viewBox).
class BeltPin extends StatelessWidget {
  final double size;

  /// Belt fabric (rank) color.
  final Color belt;

  /// Rank bar color (black on colored belts; red on a black belt).
  final Color bar;

  /// Stripe color on the rank bar.
  final Color stripeColor;

  /// Pin body color.
  final Color fg;

  /// Center dot color (defaults to [fg]).
  final Color? dot;

  /// Faint outline around the belt (helps light belts read on light grounds).
  final Color edge;

  /// Stitch-row color.
  final Color stitch;

  /// Number of stripes on the rank bar (drop to 0 below ~32px).
  final int stripes;

  const BeltPin({
    super.key,
    this.size = 64,
    this.belt = const Color(0xFFEDEDF2),
    this.bar = const Color(0xFF14151A),
    this.stripeColor = const Color(0xFFFFFFFF),
    this.fg = const Color(0xFF14151A),
    this.dot,
    this.edge = const Color(0x1F000000),
    this.stitch = const Color(0x24000000),
    this.stripes = 4,
  });

  /// App-icon variant: a white pin body with an ink center dot, for use on a
  /// colored (gradient) tile.
  const BeltPin.onColor({
    Key? key,
    double size = 64,
    int stripes = 4,
  }) : this(
          key: key,
          size: size,
          fg: const Color(0xFFFFFFFF),
          dot: const Color(0xFF14151A),
          stripes: stripes,
        );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BeltPinPainter(
          belt: belt,
          bar: bar,
          stripeColor: stripeColor,
          fg: fg,
          dot: dot ?? fg,
          edge: edge,
          stitch: stitch,
          stripes: stripes,
        ),
      ),
    );
  }
}

class _BeltPinPainter extends CustomPainter {
  final Color belt;
  final Color bar;
  final Color stripeColor;
  final Color fg;
  final Color dot;
  final Color edge;
  final Color stitch;
  final int stripes;

  _BeltPinPainter({
    required this.belt,
    required this.bar,
    required this.stripeColor,
    required this.fg,
    required this.dot,
    required this.edge,
    required this.stitch,
    required this.stripes,
  });

  static const double _cx = 32;
  static const double _cy = 24;
  static const double _r = 15;
  static const double _sw = 8.4;

  double _deg(double d) => d * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64.0);

    // Pin body (teardrop) — ported from the SVG path.
    final body = Path()
      ..moveTo(32, 60)
      ..cubicTo(31, 60, 30, 59.6, 29.3, 58.8)
      ..cubicTo(26, 55, 17, 44, 17, 28.5)
      ..arcToPoint(const Offset(47, 28.5),
          radius: const Radius.circular(15), largeArc: true, clockwise: true)
      ..cubicTo(47, 44, 38, 55, 34.7, 58.8)
      ..cubicTo(34, 59.6, 33, 60, 32, 60)
      ..close();
    canvas.drawPath(body, Paint()..color = fg..isAntiAlias = true);

    const center = Offset(_cx, _cy);

    // White disc behind the belt ring.
    canvas.drawCircle(center, 20, Paint()..color = const Color(0xFFFFFFFF));

    // Belt fabric: faint edge, then the rank color.
    canvas.drawCircle(center, _r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw + 1.1
      ..color = edge);
    canvas.drawCircle(center, _r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw
      ..color = belt);

    // Three stitched rows.
    for (final off in const [-2.6, 0.0, 2.6]) {
      _dashedCircle(canvas, center, _r + off);
    }

    // Rank bar: arc from 112° to 182° (lower-left).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: _r),
      _deg(112),
      _deg(70),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _sw
        ..strokeCap = StrokeCap.butt
        ..color = bar,
    );

    // Degree stripes across the rank bar.
    if (stripes > 0) {
      const span = 70.0, pad = 12.0;
      final step = (span - 2 * pad) / ((stripes - 1) == 0 ? 1 : (stripes - 1));
      final r1 = _r - _sw / 2 + 1.1;
      final r2 = _r + _sw / 2 - 1.1;
      final sp = Paint()
        ..color = stripeColor
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.butt;
      for (var i = 0; i < stripes; i++) {
        final a = _deg(112 + pad + i * step);
        canvas.drawLine(
          Offset(_cx + math.cos(a) * r1, _cy + math.sin(a) * r1),
          Offset(_cx + math.cos(a) * r2, _cy + math.sin(a) * r2),
          sp,
        );
      }
    }

    // Center dot.
    canvas.drawCircle(center, 5, Paint()..color = dot);

    canvas.restore();
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius) {
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..color = stitch;
    const dash = 1.15, gap = 1.05;
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        canvas.drawPath(
          m.extractPath(dist, math.min(dist + dash, m.length)),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeltPinPainter old) =>
      old.belt != belt ||
      old.bar != bar ||
      old.fg != fg ||
      old.dot != dot ||
      old.stripes != stripes;
}
