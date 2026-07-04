import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../checkins/data/attendance_repository.dart';
import '../models/open_mat.dart';
import '../../../shared/widgets/gi_badge.dart';
import '../../../shared/widgets/exp_badge.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../../../shared/widgets/score_cell.dart';

class OpenMatDetailScreen extends ConsumerWidget {
  final String? sessionId;
  const OpenMatDetailScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    if (sessionId == null) {
      return _StatusScaffold(t: t, message: 'Session not found');
    }
    final async = ref.watch(sessionByIdProvider(sessionId!));
    return async.when(
      loading: () => _StatusScaffold(t: t, child: const CircularProgressIndicator()),
      error: (e, _) => _StatusScaffold(t: t, message: "Couldn't load this open mat"),
      data: (mat) => t.isSport ? _SportDetail(t: t, mat: mat) : _GlassDetail(t: t, mat: mat),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  final AppTokens t;
  final String? message;
  final Widget? child;
  const _StatusScaffold({required this.t, this.message, this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0),
      body: Center(child: child ?? Text(message ?? '', style: t.bodyStyle)),
    );
  }
}

class _SportDetail extends StatelessWidget {
  final AppTokens t;
  final OpenMat mat;
  const _SportDetail({required this.t, required this.mat});

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
                  Text(mat.gymName ?? mat.title, style: t.h1Style.copyWith(fontSize: 24)),
                  if (mat.locationLabel != null) Text(mat.locationLabel!, style: t.miniStyle),
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
              GiBadge(type: mat.giType),
              const SizedBox(width: 8),
              ExpBadge(level: mat.skillLevel),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // scoreboard
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'Day', value: mat.specificDate ?? mat.dayName),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Start', value: mat.startLabel),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'End', value: mat.endLabel),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Fee', value: mat.feeLabel, valueColor: mat.feeLabel == 'Free' ? t.green : t.text),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (mat.gymRating != null) ...[
                  Row(children: [
                    Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                    Text('Stat Sheet', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                  Divider(color: t.border),
                  StatBar(label: 'Gym Rating', value: mat.gymRating!, color: t.green),
                  const SizedBox(height: 16),
                ],
                if (mat.description != null && mat.description!.isNotEmpty) ...[
                  Row(children: [
                    Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                    Text('About', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                  Divider(color: t.border),
                  Text(mat.description!, style: t.bodyStyle.copyWith(fontSize: 13)),
                ],
              ]),
            ),
          ),
          // CTA
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: () => context.go('/open-mat/${mat.id}/checkin'),
              child: Container(
                width: double.infinity,
                height: 54,
                color: t.green,
                child: Stack(children: [
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.checkCircle, size: 18, color: t.bg),
                    const SizedBox(width: 10),
                    Text('Check In', style: t.h2Style.copyWith(color: t.bg, fontSize: 16)),
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
  final OpenMat mat;
  const _GlassDetail({required this.t, required this.mat});

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
                    colors: [t.primary, t.both],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mat.gymName ?? mat.title, style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  if (mat.locationLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(mat.locationLabel!, style: t.miniStyle.copyWith(color: Colors.white70)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    GiBadge(type: mat.giType),
                    const SizedBox(width: 6),
                    ExpBadge(level: mat.skillLevel),
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
              _InfoCard(label: 'Day', value: mat.specificDate ?? mat.dayName, icon: LucideIcons.calendar, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Time', value: mat.startLabel, icon: LucideIcons.clock, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Fee', value: mat.feeLabel, icon: LucideIcons.dollarSign, t: t, valueColor: mat.feeLabel == 'Free' ? t.green : t.text),
            ]),
            if (mat.description != null && mat.description!.isNotEmpty) ...[
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
                child: Text(mat.description!, style: t.bodyStyle),
              ),
            ],
            if (mat.gymRating != null) ...[
              const SizedBox(height: 20),
              Text('Ratings', style: t.h2Style),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: StatBar(label: 'Gym Rating', value: mat.gymRating!, color: t.green),
              ),
            ],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => context.go('/open-mat/${mat.id}/checkin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
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
