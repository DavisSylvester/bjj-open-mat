import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import 'gi_badge.dart';
import 'live_dot.dart';

class TickerItem {
  final String time;
  final String gym;
  final String giType;
  const TickerItem({required this.time, required this.gym, required this.giType});
}

class TickerStrip extends StatelessWidget {
  final List<TickerItem> items;
  const TickerStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Row(
              children: [
                const SizedBox(width: 14),
                const LiveDot(size: 6),
                const SizedBox(width: 8),
                Text(item.time, style: t.miniStyle.copyWith(fontSize: 9)),
                const SizedBox(width: 6),
                Text(item.gym, style: t.h2Style.copyWith(fontSize: 12)),
                const SizedBox(width: 6),
                GiBadge(type: item.giType, small: true),
                if (i < items.length - 1) ...[
                  const SizedBox(width: 16),
                  Text('·', style: TextStyle(color: t.borderHi, fontSize: 14)),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
