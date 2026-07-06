import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class GiBadge extends StatelessWidget {
  final String type; // 'gi', 'nogi', 'both'
  final bool small;

  /// Use a solid white pill (for colored/gradient backgrounds like the detail hero).
  final bool onDark;

  const GiBadge({super.key, required this.type, this.small = false, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.giColor(type);
    final label = switch (type.toLowerCase()) {
      'nogi' || 'no-gi' => 'No-Gi',
      'both' => 'Gi+No-Gi',
      _ => 'Gi',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: t.miniStyle.copyWith(
              // On the white (onDark) pill, use ink so the label matches the
              // sibling level badge; on the pale tinted pill, use a darkened
              // tint of the semantic color for a monochrome chip.
              color: onDark ? t.text : Color.lerp(color, const Color(0xFF14151A), 0.34),
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.01,
            ),
          ),
        ],
      ),
    );
  }
}
