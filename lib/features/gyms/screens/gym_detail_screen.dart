import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/score_cell.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../../../shared/widgets/gi_badge.dart';

final _gymSessions = [
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '0.0 mi', fee: 0, isLive: true),
  SessionRowData(gymName: 'Atos HQ', giType: 'both', expLevel: 'int', time: '10:00 AM', day: 'Sat', distance: '0.0 mi', fee: 0),
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'adv', time: '2:00 PM', day: 'Sun', distance: '0.0 mi', fee: 0),
  SessionRowData(gymName: 'Atos HQ', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Wed', distance: '0.0 mi', fee: 10),
];

class GymDetailScreen extends ConsumerWidget {

  final String? gymId;
  const GymDetailScreen({super.key, this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _SportGymDetail(t: t) : _GlassGymDetail(t: t);
  }
}

class _SportGymDetail extends StatelessWidget {

  final AppTokens t;
  const _SportGymDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
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
          // Player card
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'Rating', value: '4.8', suffix: '★', valueColor: t.amber),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Reviews', value: '124'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Mats/Wk', value: '6'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Dist', value: '1.2', suffix: 'mi'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(children: [
                    Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                    Text('Upcoming Mats', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                ),
                Divider(height: 1, color: t.border),
                ..._gymSessions.map((s) => Column(children: [
                  SessionRow(session: s),
                  Divider(height: 1, color: t.border),
                ])),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(children: [
                    Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                    Text('Stat Sheet', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                ),
                Divider(height: 1, color: t.border),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(children: [
                    StatBar(label: 'Facilities', value: 4.8, color: t.gi),
                    StatBar(label: 'Instruction', value: 4.9, color: t.green),
                    StatBar(label: 'Mat Space', value: 4.5, color: t.amber),
                    StatBar(label: 'Community', value: 4.7, color: t.noGi),
                  ]),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassGymDetail extends StatelessWidget {

  final AppTokens t;
  const _GlassGymDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
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
                    colors: [t.primary, t.both],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ATOS HQ', style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Los Angeles, CA', style: t.bodyStyle.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const GiBadge(type: 'both'),
                ],
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Stat pills
            Row(children: [
              _Pill(label: '4.8 ★', color: t.amber, t: t),
              const SizedBox(width: 8),
              _Pill(label: '1.2 mi', color: t.gi, t: t),
              const SizedBox(width: 8),
              _Pill(label: '6 mats/wk', color: t.green, t: t),
            ]),
            const SizedBox(height: 20),
            Text('Upcoming Sessions', style: t.h2Style),
            const SizedBox(height: 8),
            ..._gymSessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionRow(session: s),
            )),
            const SizedBox(height: 20),
            Text('About', style: t.h2Style),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
                boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Text(
                'World-class BJJ facility with 4 mat rooms, strength & conditioning area, and pro shop. Home to multiple world champions.',
                style: t.bodyStyle,
              ),
            ),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {

  final String label;
  final Color color;
  final AppTokens t;
  const _Pill({required this.label, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.33)),
      ),
      child: Text(label, style: t.miniStyle.copyWith(color: color, fontSize: 11)),
    );
  }
}
