import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class BeltBadge extends StatelessWidget {
  final String belt; // 'white','blue','purple','brown','black'
  final int stripes;
  final bool small;

  const BeltBadge({super.key, required this.belt, this.stripes = 0, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final bg = t.beltBg[belt] ?? t.beltBg['white']!;
    final fg = t.beltFg[belt] ?? t.beltFg['white']!;
    final height = small ? 14.0 : 18.0;
    final fontSize = small ? 8.0 : 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: bg,
          alignment: Alignment.center,
          child: Text(
            belt.toUpperCase(),
            style: t.miniStyle.copyWith(color: fg, fontSize: fontSize),
          ),
        ),
        Container(
          height: height,
          width: 14,
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              stripes,
              (_) => Container(
                width: 2,
                height: height - 4,
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
