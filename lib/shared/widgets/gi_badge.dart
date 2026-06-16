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
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.badgeRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
      ),
    );
  }
}
