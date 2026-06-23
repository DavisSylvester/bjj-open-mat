import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class ScoreCell extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String? sub;
  final Color? valueColor;
  final Color? accent;

  const ScoreCell({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.sub,
    this.valueColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (accent != null) ...[
              Container(width: 6, height: 6, color: accent),
              const SizedBox(width: 4),
            ],
            Text(label, style: t.miniStyle.copyWith(fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: t.numStyle.copyWith(fontSize: 26, color: valueColor ?? t.text),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 3),
              Text(
                suffix!,
                style: t.numStyle.copyWith(fontSize: 12, color: t.muted),
              ),
            ],
          ],
        ),
        if (sub != null)
          Text(sub!, style: t.miniStyle.copyWith(color: t.faint, fontSize: 9)),
      ],
    );
  }
}
