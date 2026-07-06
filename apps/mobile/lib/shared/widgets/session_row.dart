import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';
import 'gi_badge.dart';
import 'exp_badge.dart';

class SessionRowData {
  final String? id; // open-mat session id, used for navigation to the detail page
  final String gymName;
  final String giType; // 'gi', 'nogi', 'both'
  final String expLevel; // 'all', 'beg', 'int', 'adv'
  final String time; // '7:00 PM'
  final String day; // 'Mon'
  final String distance; // '0.8 mi'
  final double fee;
  final bool isLive;
  final bool unverified;

  const SessionRowData({
    this.id,
    required this.gymName,
    required this.giType,
    required this.expLevel,
    required this.time,
    required this.day,
    required this.distance,
    required this.fee,
    this.isLive = false,
    this.unverified = false,
  });
}

class SessionRow extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;

  const SessionRow({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _GlassCard(session: session, onTap: onTap, t: t);
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
                if (session.unverified) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Unverified',
                      style: t.miniStyle.copyWith(
                        fontSize: 10,
                        color: t.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
