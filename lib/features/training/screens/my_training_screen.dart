import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR PROGRESS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                const SizedBox(height: 3),
                Text('My Training', style: t.h1Style),
              ],
            ),
          ),
          // Stat strip card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.border),
                boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                _TrainingStatCell(label: 'Mats', value: '47', t: t, borderRight: true),
                _TrainingStatCell(label: 'Hours', value: '94', t: t, borderRight: true),
                _TrainingStatCell(label: 'Streak', value: '7', t: t, borderRight: true),
                _TrainingStatCell(label: 'Gyms', value: '8', t: t, borderRight: false),
              ]),
            ),
          ),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Session History', style: t.h2Style),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _stubSessions.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionRow(session: _stubSessions[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TrainingStatCell extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;
  final bool borderRight;
  const _TrainingStatCell({required this.label, required this.value, required this.t, required this.borderRight});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: borderRight ? Border(right: BorderSide(color: t.border)) : null,
        ),
        child: Column(children: [
          Text(value, style: t.numStyle.copyWith(fontSize: 20, color: t.text)),
          const SizedBox(height: 3),
          Text(label, style: t.miniStyle.copyWith(fontSize: 9, color: t.muted)),
        ]),
      ),
    );
  }
}
