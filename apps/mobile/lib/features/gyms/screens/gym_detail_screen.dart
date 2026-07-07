import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
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
    return _GlassGymDetail(t: t);
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
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
