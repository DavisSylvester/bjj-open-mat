import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../../gyms/data/gym_permissions.dart';
import '../../gyms/data/gym_repository.dart';
import '../data/membership_repository.dart';
import '../models/roster_member.dart';
import '../widgets/promote_belt_sheet.dart';

class RosterScreen extends ConsumerWidget {
  final String gymId;
  const RosterScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymOwnerId = ref
        .watch(gymByIdProvider(gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);

    // canManage must be derived WITHOUT the roster: a manager needs it to
    // decide which roster to request in the first place. Own membership comes
    // from myMembershipsProvider, which is not visibility-filtered.
    final canManage = deriveCanManageGym(ref, gymId: gymId, ownerId: gymOwnerId);
    final async = canManage
        ? ref.watch(manageRosterProvider(gymId))
        : ref.watch(rosterProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
        title: Text('Members', style: t.h2Style),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load roster", style: t.bodyStyle.copyWith(color: t.muted)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.invalidate(rosterProvider(gymId));
                  ref.invalidate(manageRosterProvider(gymId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) => members.isEmpty
            ? Center(child: Text('No members yet.', style: t.bodyStyle.copyWith(color: t.muted)))
            : _RosterGrid(t: t, members: members, gymId: gymId, canManage: canManage),
      ),
    );
  }
}

class _RosterGrid extends StatelessWidget {
  final AppTokens t;
  final List<RosterMember> members;
  final String gymId;
  final bool canManage;

  const _RosterGrid({
    required this.t,
    required this.members,
    required this.gymId,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: canManage ? 0.60 : 0.72,
      children: [
        for (final m in members)
          _RosterCell(t: t, member: m, gymId: gymId, canManage: canManage),
      ],
    );
  }
}

class _RosterCell extends ConsumerWidget {
  final AppTokens t;
  final RosterMember member;
  final String gymId;
  final bool canManage;

  const _RosterCell({
    required this.t,
    required this.member,
    required this.gymId,
    required this.canManage,
  });

  String get _displayRank => member.verifiedBeltRank ?? member.beltRank ?? 'white';
  int get _displayStripes => member.verifiedBeltStripes ?? member.beltStripes ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleLabel = _roleLabel(member.gymRole);

    return Opacity(
      opacity: member.status == 'active' ? 1.0 : 0.55,
      child: InkWell(
      onTap: member.hasProfile ? () => context.push('/user/${member.userId}') : null,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              BeltIcon(rank: _displayRank, stripes: _displayStripes, size: 44),
              if (member.verifiedBeltRank != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: t.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '✓',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (roleLabel != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.primary.withValues(alpha: 0.30)),
              ),
              child: Text(
                roleLabel,
                style: t.miniStyle.copyWith(
                  fontSize: 9,
                  color: t.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (member.isHidden || member.isInactive) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (member.isInactive ? t.red : t.muted).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: (member.isInactive ? t.red : t.muted).withValues(alpha: 0.35)),
              ),
              child: Text(
                member.isInactive ? 'Inactive' : 'Hidden',
                style: t.miniStyle.copyWith(
                  fontSize: 9,
                  color: member.isInactive ? t.red : t.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          // Manage affordance — only visible to owners/coaches.
          if (canManage) ...[
            const SizedBox(height: 6),
            _ManageRow(t: t, member: member, gymId: gymId),
          ],
        ],
      ),
      ),
    );
  }

  String? _roleLabel(String gymRole) {
    switch (gymRole) {
      case 'owner':
        return 'Owner';
      case 'coach':
        return 'Coach';
      default:
        return null;
    }
  }
}

/// Row of small action buttons shown under each member cell when the viewer
/// has manage rights (owner or coach gymRole, or global admin).
class _ManageRow extends ConsumerStatefulWidget {
  final AppTokens t;
  final RosterMember member;
  final String gymId;

  const _ManageRow({
    required this.t,
    required this.member,
    required this.gymId,
  });

  @override
  ConsumerState<_ManageRow> createState() => _ManageRowState();
}

class _ManageRowState extends ConsumerState<_ManageRow> {
  bool _busy = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(rosterProvider(widget.gymId));
      ref.invalidate(manageRosterProvider(widget.gymId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmMember() => _runAction(() async {
        await ref.read(membershipRepositoryProvider).manageMember(
              widget.gymId,
              widget.member.userId,
              verifiedMember: true,
            );
      });

  Future<void> _makeCoach() => _runAction(() async {
        await ref.read(membershipRepositoryProvider).manageMember(
              widget.gymId,
              widget.member.userId,
              gymRole: 'coach',
            );
      });

  Future<void> _setStatus(String status) => _runAction(() async {
        await ref.read(membershipRepositoryProvider).manageMember(
              widget.gymId,
              widget.member.userId,
              status: status,
            );
      });

  void _promoteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PromoteBeltSheet(
        gymId: widget.gymId,
        targetUserId: widget.member.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: widget.t.primary),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      children: [
        _SmallIconBtn(
          icon: Icons.military_tech,
          tooltip: 'Promote belt',
          color: widget.t.gold,
          onTap: _promoteSheet,
        ),
        if (!widget.member.verifiedMember)
          _SmallIconBtn(
            icon: Icons.verified_user,
            tooltip: 'Confirm member',
            color: widget.t.green,
            onTap: _confirmMember,
          ),
        if (widget.member.gymRole == 'member')
          _SmallIconBtn(
            icon: Icons.sports_martial_arts,
            tooltip: 'Make coach',
            color: widget.t.primary,
            onTap: _makeCoach,
          ),
        if (widget.member.status == 'active')
          _SmallIconBtn(
            icon: Icons.visibility_off,
            tooltip: 'Hide from roster',
            color: widget.t.muted,
            onTap: () => _setStatus('hidden'),
          ),
        if (widget.member.status != 'inactive')
          _SmallIconBtn(
            icon: Icons.person_off,
            tooltip: 'Mark inactive',
            color: widget.t.red,
            onTap: () => _setStatus('inactive'),
          ),
        if (widget.member.isHidden || widget.member.isInactive)
          _SmallIconBtn(
            icon: Icons.restart_alt,
            tooltip: 'Reactivate',
            color: widget.t.green,
            onTap: () => _setStatus('active'),
          ),
      ],
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _SmallIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
