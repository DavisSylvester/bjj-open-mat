import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/gi_badge.dart';
import '../../../shared/widgets/exp_badge.dart';
import '../../../shared/widgets/belt_badge.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../../../shared/widgets/score_cell.dart';

class OpenMatDetailScreen extends ConsumerWidget {
  final String? sessionId;
  const OpenMatDetailScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _SportDetail(t: t) : _GlassDetail(t: t);
  }
}

class _SportDetail extends StatelessWidget {
  final AppTokens t;
  const _SportDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ATOS HQ', style: t.h1Style.copyWith(fontSize: 24)),
                  Text('Los Angeles, CA', style: t.miniStyle),
                ],
              )),
              Icon(LucideIcons.share2, size: 18, color: t.muted),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // Gi + Exp badges row
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              const GiBadge(type: 'gi'),
              const SizedBox(width: 8),
              const ExpBadge(level: 'all'),
              const Spacer(),
              const BeltBadge(belt: 'blue', stripes: 2),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // 4-cell scoreboard
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'Date', value: 'Jun 2', sub: 'Monday'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Start', value: '7:00', suffix: 'PM'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'End', value: '9:00', suffix: 'PM'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Fee', value: 'FREE', valueColor: t.green),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Stat sheet
                Row(children: [
                  Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                  Text('Stat Sheet', style: t.h2Style.copyWith(fontSize: 14)),
                ]),
                Divider(color: t.border),
                StatBar(label: 'Experience Mix', value: 4.2, color: t.gi),
                StatBar(label: 'Avg Attendance', value: 3.8, color: t.amber),
                StatBar(label: 'Instructor Rating', value: 4.7, color: t.green),
                StatBar(label: 'Mat Quality', value: 4.5, color: t.noGi),
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                  Text('About', style: t.h2Style.copyWith(fontSize: 14)),
                ]),
                Divider(color: t.border),
                Text(
                  'World-class facility with multiple mat rooms. Open mat runs Saturday & Sunday. All skill levels welcome. Instructors on the mat.',
                  style: t.bodyStyle.copyWith(fontSize: 13),
                ),
              ]),
            ),
          ),
          // CTA
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: 54,
                color: t.green,
                child: Stack(children: [
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.checkCircle, size: 18, color: t.bg),
                    const SizedBox(width: 10),
                    Text('Check In — Free', style: t.h2Style.copyWith(color: t.bg, fontSize: 16)),
                  ])),
                  // Corner ticks
                  Positioned(top: 0, left: 0, child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white30, width: 2), left: BorderSide(color: Colors.white30, width: 2))))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white30, width: 2), right: BorderSide(color: Colors.white30, width: 2))))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassDetail extends StatelessWidget {
  final AppTokens t;
  const _GlassDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: t.bg2,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(LucideIcons.arrowLeft, color: t.text),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.gi.withValues(alpha: 0.6), t.both.withValues(alpha: 0.4)],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ATOS HQ', style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Row(children: [
                    GiBadge(type: 'gi'),
                    SizedBox(width: 6),
                    ExpBadge(level: 'all'),
                  ]),
                ],
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Info cards row
            Row(children: [
              _InfoCard(label: 'Date', value: 'Jun 2', icon: LucideIcons.calendar, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Time', value: '7:00 PM', icon: LucideIcons.clock, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Fee', value: 'Free', icon: LucideIcons.dollarSign, t: t, valueColor: t.green),
            ]),
            const SizedBox(height: 20),
            Text('About', style: t.h2Style),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'World-class facility with multiple mat rooms. Open mat runs Saturday & Sunday. All skill levels welcome.',
                style: t.bodyStyle,
              ),
            ),
            const SizedBox(height: 20),
            Text('Ratings', style: t.h2Style),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Column(children: [
                StatBar(label: 'Experience Mix', value: 4.2, color: t.gi),
                StatBar(label: 'Instructor Rating', value: 4.7, color: t.green),
                StatBar(label: 'Mat Quality', value: 4.5, color: t.noGi),
              ]),
            ),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: t.red,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
            ),
            child: Text('Check In', style: t.h2Style.copyWith(color: Colors.white, fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppTokens t;
  final Color? valueColor;
  const _InfoCard({required this.label, required this.value, required this.icon, required this.t, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: t.muted),
        const SizedBox(height: 6),
        Text(value, style: t.numStyle.copyWith(fontSize: 16, color: valueColor ?? t.text)),
        Text(label, style: t.miniStyle),
      ]),
    ));
  }
}
