import 'package:flutter/material.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.giColor(session.giType).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  session.time.split(':').first,
                  style: t.numStyle.copyWith(
                    fontSize: 18,
                    color: t.giColor(session.giType),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.gymName, style: t.h2Style.copyWith(fontSize: 15)),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(session.distance, style: t.miniStyle),
                const SizedBox(height: 4),
                Text(
                  session.fee == 0 ? 'Free' : '\$${session.fee.toStringAsFixed(0)}',
                  style: t.numStyle.copyWith(
                    fontSize: 18,
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
