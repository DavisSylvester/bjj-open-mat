import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Maps a raw category key to a display label.
String _categoryLabel(String category) {
  const labels = <String, String>{
    'technique': 'Technique',
    'rules': 'Rules',
    'competition': 'Competition',
    'schedule': 'Schedule',
    'gear': 'Gear',
    'general': 'General',
  };
  return labels[category.toLowerCase()] ??
      category.substring(0, 1).toUpperCase() + category.substring(1);
}

/// A small themed chip that displays a forum category label.
class ForumCategoryChip extends StatelessWidget {
  final String category;

  const ForumCategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final label = _categoryLabel(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(t.badgeRadius),
        border: Border.all(color: t.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: t.miniStyle.copyWith(color: t.primary, fontSize: 10),
      ),
    );
  }
}
