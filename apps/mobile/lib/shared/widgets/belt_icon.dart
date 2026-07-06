import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// A small, branded BJJ belt icon: a rounded horizontal belt bar in the rank
/// color, a knot near the center, and a darker stripe patch near the tip
/// carrying up to [stripes] white pips. Unknown ranks render as a white belt.
class BeltIcon extends StatelessWidget {
  final String rank;
  final int stripes;
  final double size;

  const BeltIcon({
    super.key,
    required this.rank,
    this.stripes = 0,
    this.size = 40,
  });

  /// Resolved fabric (background) color for [rank]; unknown ranks fall back to
  /// the white-belt background. Exposed for testing.
  @visibleForTesting
  Color get bgColor => _dataFor(rank)['bg'] ?? _dataFor('white')['bg']!;

  static Map<String, Color> _dataFor(String rank) =>
      BeltColors.beltData[rank.toLowerCase()] ?? BeltColors.beltData['white']!;

  @override
  Widget build(BuildContext context) {
    final data = _dataFor(rank);
    final bg = data['bg'] ?? BeltColors.beltData['white']!['bg']!;
    final stripe = data['stripe'] ?? BeltColors.beltData['white']!['stripe']!;
    final height = size * 0.42;
    return SizedBox(
      width: size,
      height: height,
      child: CustomPaint(
        painter: _BeltIconPainter(bg: bg, stripe: stripe, stripes: stripes),
      ),
    );
  }
}

class _BeltIconPainter extends CustomPainter {
  final Color bg;
  final Color stripe;
  final int stripes;

  _BeltIconPainter({required this.bg, required this.stripe, required this.stripes});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = Radius.circular(h * 0.28);

    // Belt bar (fabric).
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.18, w, h * 0.64),
      radius,
    );
    canvas.drawRRect(barRect, Paint()..color = bg..isAntiAlias = true);

    // Faint hairline so light belts read on light grounds.
    canvas.drawRRect(
      barRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.04
        ..color = const Color(0x1F000000),
    );

    // Knot near center.
    final knotW = w * 0.20;
    final knotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.06, knotW, h * 0.88),
      Radius.circular(h * 0.22),
    );
    canvas.drawRRect(knotRect, Paint()..color = bg);
    canvas.drawRRect(
      knotRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.05
        ..color = stripe.withValues(alpha: 0.55),
    );

    // Darker stripe patch near the tip (right side).
    final patchW = w * 0.22;
    final patchRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - patchW - w * 0.04, h * 0.20, patchW, h * 0.60),
      Radius.circular(h * 0.16),
    );
    canvas.drawRRect(patchRect, Paint()..color = stripe);

    // White pips on the patch, up to [stripes].
    final pips = stripes.clamp(0, 4);
    if (pips > 0) {
      final pipPaint = Paint()..color = Colors.white;
      final patchLeft = w - patchW - w * 0.04;
      final gap = patchW / (pips + 1);
      final pipW = (patchW * 0.14).clamp(0.5, patchW * 0.2);
      for (var i = 1; i <= pips; i++) {
        final cx = patchLeft + gap * i;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, h * 0.5), width: pipW, height: h * 0.36),
            Radius.circular(pipW * 0.4),
          ),
          pipPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeltIconPainter old) =>
      old.bg != bg || old.stripe != stripe || old.stripes != stripes;
}
