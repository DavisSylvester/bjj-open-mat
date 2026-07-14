import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../checkins/data/attendance_repository.dart';
import '../../checkins/data/review_repository.dart';
import '../../checkins/models/checkin.dart';
import '../models/open_mat.dart';
import '../../../shared/widgets/gi_badge.dart';
import '../../../shared/widgets/exp_badge.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../widgets/going_section.dart';
import '../../gyms/data/directions.dart';

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
      data: (mat) => _GlassDetail(t: t, mat: mat),
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

class _GlassDetail extends ConsumerWidget {
  final AppTokens t;
  final OpenMat mat;
  const _GlassDetail({required this.t, required this.mat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: t.bg2,
          leading: GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: const Icon(LucideIcons.arrowLeft, color: Colors.white),
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
                    GiBadge(type: mat.giType, onDark: true),
                    const SizedBox(width: 6),
                    ExpBadge(level: mat.skillLevel, onDark: true),
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
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => openDirections(ref, context, gymId: mat.gymId, address: mat.address),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.navigation, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Directions', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            GoingSection(t: t, mat: mat),
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
            const SizedBox(height: 20),
            Text('Reviews', style: t.h2Style),
            const SizedBox(height: 8),
            Consumer(builder: (context, ref, _) {
              final reviewsAsync = ref.watch(openMatReviewsProvider(mat.id));
              return reviewsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text("Couldn't load reviews", style: t.miniStyle),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Text('No reviews yet', style: t.miniStyle);
                  }
                  return Column(
                    children: reviews.map((r) => _ReviewCard(t: t, checkIn: r)).toList(),
                  );
                },
              );
            }),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => context.push('/open-mat/${mat.id}/checkin'),
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

class _ReviewCard extends StatelessWidget {
  final AppTokens t;
  final CheckIn checkIn;
  const _ReviewCard({required this.t, required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final reviewerName = (checkIn.userName != null && checkIn.userName!.isNotEmpty) ? checkIn.userName! : 'Member';
    final rating = checkIn.rating ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(reviewerName, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600))),
          Text(_relativeDate(checkIn.reviewedAt ?? checkIn.createdAt), style: t.miniStyle),
        ]),
        const SizedBox(height: 4),
        Row(children: List.generate(5, (i) => Icon(
          LucideIcons.star,
          size: 14,
          color: i < rating ? t.amber : t.muted,
        ))),
        if (checkIn.review != null && checkIn.review!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(checkIn.review!, style: t.bodyStyle.copyWith(fontSize: 13)),
        ],
      ]),
    );
  }
}

String _relativeDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 7) return DateFormat.yMMMd().format(dt);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}
