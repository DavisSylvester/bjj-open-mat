import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/score_cell.dart';

const _stubSessions = [
  SessionRowData(
    gymName: 'Atos HQ',
    giType: 'gi',
    expLevel: 'all',
    time: '7:00 PM',
    day: 'Mon',
    distance: '1.2 mi',
    fee: 0,
  ),
  SessionRowData(
    gymName: 'Renzo Westwood',
    giType: 'nogi',
    expLevel: 'int',
    time: '8:00 PM',
    day: 'Sat',
    distance: '2.4 mi',
    fee: 15,
  ),
  SessionRowData(
    gymName: 'Gracie Barra Pasadena',
    giType: 'gi',
    expLevel: 'beg',
    time: '9:00 AM',
    day: 'Sun',
    distance: '4.5 mi',
    fee: 0,
  ),
  SessionRowData(
    gymName: 'Alliance Jiu-Jitsu',
    giType: 'both',
    expLevel: 'adv',
    time: '6:30 PM',
    day: 'Fri',
    distance: '3.1 mi',
    fee: 20,
  ),
];

class MyTrainingScreen extends ConsumerWidget {
  const MyTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport
        ? _SportTraining(t: t)
        : _GlassTraining(t: t);
  }
}

class _SportTraining extends StatelessWidget {
  final AppTokens t;
  const _SportTraining({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Masthead
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Container(width: 4, height: 28, color: t.red),
              const SizedBox(width: 10),
              Text('My Training', style: t.h1Style.copyWith(fontSize: 22)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // 4-stat strip
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'TOTAL MATS', value: '47'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'HRS', value: '94'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'STREAK', value: '7', suffix: 'wk'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'GYMS', value: '8'),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(children: [
              Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Text('Session History', style: t.h2Style.copyWith(fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ListView.separated(
              itemCount: _stubSessions.length,
              separatorBuilder: (context2, index) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(session: _stubSessions[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassTraining extends StatelessWidget {
  final AppTokens t;
  const _GlassTraining({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Icon(LucideIcons.calendar, color: t.muted, size: 20),
              const SizedBox(width: 8),
              Text('My Training', style: t.h1Style),
            ]),
          ),
          // Stat pills
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              _GlassStatPill(label: '47 Mats', t: t),
              const SizedBox(width: 8),
              _GlassStatPill(label: '94 Hours', t: t),
              const SizedBox(width: 8),
              _GlassStatPill(label: '7 wk Streak', t: t),
              const SizedBox(width: 8),
              _GlassStatPill(label: '8 Gyms', t: t),
            ]),
          ),
          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              Text('My Sessions', style: t.h2Style),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _stubSessions.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SessionRow(session: _stubSessions[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassStatPill extends StatelessWidget {
  final String label;
  final AppTokens t;
  const _GlassStatPill({required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Text(label, style: t.miniStyle.copyWith(fontSize: 11)),
    );
  }
}
