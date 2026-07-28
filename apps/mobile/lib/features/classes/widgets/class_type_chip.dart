import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// A small chip that labels a BJJ class type.
///
/// Maps [classType] values to display names. When the type is `other`,
/// [label] is used if provided, otherwise "Other" is shown.
class ClassTypeChip extends StatelessWidget {
  final String classType;
  final String? label;

  const ClassTypeChip({super.key, required this.classType, this.label});

  String get _displayName {
    switch (classType) {
      case 'fundamentals':
        return 'Fundamentals';
      case 'all_levels':
        return 'All Levels';
      case 'advanced':
        return 'Advanced';
      case 'gi':
        return 'Gi';
      case 'nogi':
        return 'No-Gi';
      case 'kids':
        return 'Kids';
      case 'womens':
        return "Women's";
      case 'competition':
        return 'Competition';
      case 'private':
        return 'Private';
      case 'other':
        return label ?? 'Other';
      default:
        return label ?? classType;
    }
  }

  Color _chipColor(AppTokens t) {
    switch (classType) {
      case 'gi':
        return t.gi;
      case 'nogi':
        return t.noGi;
      case 'both':
        return t.both;
      case 'advanced':
        return t.advanced;
      case 'all_levels':
        return t.allLevels;
      case 'kids':
        return t.amber;
      case 'competition':
        return t.red;
      default:
        return t.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = _chipColor(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _displayName,
        style: t.miniStyle.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
