import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class LiveDot extends StatefulWidget {
  final Color? color;
  final String label;
  final double size;

  const LiveDot({super.key, this.color, this.label = 'Live', this.size = 7});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final c = widget.color ?? t.green;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Opacity(
            opacity: _anim.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          widget.label,
          style: t.miniStyle.copyWith(color: c, fontSize: 9),
        ),
      ],
    );
  }
}
