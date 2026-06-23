import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class StatBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color? color;
  final String? suffix;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 5,
    this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final c = color ?? t.red;
    final pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: t.miniStyle.copyWith(fontSize: 10)),
              ),
              Text(
                value.toStringAsFixed(1),
                style: t.numStyle.copyWith(fontSize: 14),
              ),
              if (suffix != null) Text(' $suffix', style: t.miniStyle),
            ],
          ),
          const SizedBox(height: 5),
          ClipRect(
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(
                    color: t.isSport ? const Color(0xFF080F26) : Colors.black12,
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: c),
                  ),
                  Row(
                    children: List.generate(
                      max.toInt() - 1,
                      (i) => Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 1,
                            height: 5,
                            color: t.bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
