import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';
import 'gi_badge.dart';
import 'exp_badge.dart';
import 'live_dot.dart';

class SessionRowData {
  final String gymName;
  final String giType; // 'gi', 'nogi', 'both'
  final String expLevel; // 'all', 'beg', 'int', 'adv'
  final String time; // '7:00 PM'
  final String day; // 'Mon'
  final String distance; // '0.8 mi'
  final double fee;
  final bool isLive;

  const SessionRowData({
    required this.gymName,
    required this.giType,
    required this.expLevel,
    required this.time,
    required this.day,
    required this.distance,
    required this.fee,
    this.isLive = false,
  });
}

class SessionRow extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;

  const SessionRow({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport
        ? _SportRow(session: session, onTap: onTap, t: t)
        : _GlassCard(session: session, onTap: onTap, t: t);
  }
}

class _SportRow extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;
  final AppTokens t;

  const _SportRow({required this.session, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    final accent = t.giColor(session.giType);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Time column
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.day, style: t.miniStyle.copyWith(fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(
                    session.time.split(' ').first,
                    style: t.numStyle.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: t.border,
              margin: const EdgeInsets.only(right: 10),
            ),
            // Main column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (session.isLive) ...[
                        const LiveDot(),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        session.distance,
                        style: t.miniStyle.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.gymName,
                    style: t.h2Style.copyWith(fontSize: 14, letterSpacing: 0.03),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GiBadge(type: session.giType, small: true),
                      const SizedBox(width: 4),
                      ExpBadge(level: session.expLevel, small: true),
                    ],
                  ),
                ],
              ),
            ),
            // Fee column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Mat Fee', style: t.miniStyle.copyWith(fontSize: 9)),
                const SizedBox(height: 2),
                Text(
                  session.fee == 0 ? 'FREE' : '\$${session.fee.toStringAsFixed(0)}',
                  style: t.numStyle.copyWith(
                    fontSize: 22,
                    color: session.fee == 0 ? t.green : t.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;
  final AppTokens t;

  const _GlassCard({required this.session, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    final accent = t.giColor(session.giType);
    final isFree = session.fee == 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(LucideIcons.clock, size: 17, color: accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.time, style: t.numStyle.copyWith(fontSize: 15, color: t.text)),
                    Text(session.day, style: t.miniStyle.copyWith(fontSize: 11, color: t.muted)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFree ? t.green.withValues(alpha: 0.09) : t.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isFree ? 'Free' : '\$${session.fee.toStringAsFixed(0)}',
                    style: t.miniStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isFree ? t.green : t.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(session.gymName, style: t.h2Style.copyWith(fontSize: 18)),
            const SizedBox(height: 10),
            Row(
              children: [
                GiBadge(type: session.giType, small: true),
                const SizedBox(width: 4),
                ExpBadge(level: session.expLevel, small: true),
                const Spacer(),
                Text(session.distance, style: t.miniStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
