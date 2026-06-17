import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class GiBadge extends StatelessWidget {
  final String type; // 'gi', 'nogi', 'both'
  final bool small;

  const GiBadge({super.key, required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.giColor(type);
    final label = switch (type.toLowerCase()) {
      'nogi' || 'no-gi' => 'No-Gi',
      'both' => 'Gi+No-Gi',
      _ => 'Gi',
    };
    final fontSize = small ? 9.0 : 11.0;
    final padding = small
        ? const EdgeInsets.fromLTRB(5, 3, 7, 3)
        : const EdgeInsets.fromLTRB(6, 4, 9, 4);

    if (t.isSport) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Text(
          label.toUpperCase(),
          style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
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
              color: color,
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
