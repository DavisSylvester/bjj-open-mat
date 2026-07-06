import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class ExpBadge extends StatelessWidget {
  final String level; // 'all', 'beg', 'int', 'adv'
  final bool small;

  /// Use a solid white pill (for colored/gradient backgrounds like the detail hero).
  final bool onDark;

  const ExpBadge({super.key, required this.level, this.small = false, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.expColor(level);
    final label = switch (level.toLowerCase()) {
      'beg' || 'beginner' => 'Beginner',
      'int' || 'intermediate' => 'Intermediate',
      'adv' || 'advanced' => 'Advanced',
      _ => 'All Levels',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : t.panel,
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
              color: t.body,
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
