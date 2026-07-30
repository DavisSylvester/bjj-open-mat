import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/messaging_repository.dart';
import '../models/message_report.dart';

class GymReportsScreen extends ConsumerWidget {
  final String gymId;

  const GymReportsScreen({super.key, required this.gymId});

  // ── Manager gate (mirrors ConversationScreen._deriveCanManage) ───────────
  bool _deriveCanManage(WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
    final gymOwnerId = ref
        .watch(gymByIdProvider(gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);
    final isOwner = gymOwnerId != null && gymOwnerId == myId;
    final rosterAsync = ref.watch(rosterProvider(gymId));
    final myGymRole = rosterAsync.maybeWhen(
      data: (members) => myId != null
          ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
          : null,
      orElse: () => null,
    );
    return isAdmin || isOwner || myGymRole == 'owner' || myGymRole == 'coach';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final canManage = _deriveCanManage(ref);

    if (!canManage) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.bg,
          foregroundColor: t.text,
          elevation: 0,
          title: Text('Message Reports', style: t.h2Style),
        ),
        body: Center(
          child: Text(
            "You don't have access to this page.",
            style: t.bodyStyle.copyWith(color: t.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final reportsAsync = ref.watch(gymMessageReportsProvider((gymId: gymId, status: 'open')));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Message Reports', style: t.h2Style),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load reports",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (reports) => reports.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck, color: t.faint, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'No open reports',
                      style: t.bodyStyle.copyWith(color: t.muted),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: reports.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _ReportTile(
                  report: reports[index],
                  gymId: gymId,
                  t: t,
                ),
              ),
      ),
    );
  }
}

class _ReportTile extends ConsumerWidget {
  final MessageReport report;
  final String gymId;
  final AppTokens t;

  const _ReportTile({required this.report, required this.gymId, required this.t});

  Future<void> _resolve(BuildContext context, WidgetRef ref, String status) async {
    final repo = ref.read(messagingRepositoryProvider);
    try {
      await repo.resolveReport(report.id, status);
      ref.invalidate(gymMessageReportsProvider((gymId: gymId, status: 'open')));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update report. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.flag, color: t.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.reason,
                  style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (report.note != null && report.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.note!, style: t.miniStyle.copyWith(color: t.muted)),
          ],
          const SizedBox(height: 4),
          Text(
            'Reporter: ${report.reporterId}  •  Reported: ${report.reportedUserId}',
            style: t.miniStyle.copyWith(color: t.faint, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resolve(context, ref, 'dismissed'),
                child: Text(
                  'Dismiss',
                  style: t.miniStyle.copyWith(color: t.muted, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _resolve(context, ref, 'reviewed'),
                child: Text(
                  'Mark reviewed',
                  style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
