import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class ExpBadge extends StatelessWidget {
  final String level; // 'all', 'beg', 'int', 'adv'
  final bool small;

  const ExpBadge({super.key, required this.level, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.expColor(level);
    final label = switch (level.toLowerCase()) {
      'beg' || 'beginner' => t.isSport ? 'Begin' : 'Beginner',
      'int' || 'intermediate' => t.isSport ? 'Inter' : 'Intermediate',
      'adv' || 'advanced' => t.isSport ? 'Adv' : 'Advanced',
      _ => t.isSport ? 'All Lv' : 'All Levels',
    };
    final fontSize = small ? 9.0 : 11.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 9, vertical: 4);

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
