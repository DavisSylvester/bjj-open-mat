import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../data/membership_repository.dart';
import '../models/roster_member.dart';

class RosterScreen extends ConsumerWidget {
  final String gymId;
  const RosterScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(rosterProvider(gymId));

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
                onPressed: () => ref.invalidate(rosterProvider(gymId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) => members.isEmpty
            ? Center(child: Text('No members yet.', style: t.bodyStyle.copyWith(color: t.muted)))
            : _RosterGrid(t: t, members: members),
      ),
    );
  }
}

class _RosterGrid extends StatelessWidget {
  final AppTokens t;
  final List<RosterMember> members;
  const _RosterGrid({required this.t, required this.members});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
      children: [
        for (final m in members) _RosterCell(t: t, member: m),
      ],
    );
  }
}

class _RosterCell extends StatelessWidget {
  final AppTokens t;
  final RosterMember member;
  const _RosterCell({required this.t, required this.member});

  String get _displayRank => member.verifiedBeltRank ?? member.beltRank ?? 'white';
  int get _displayStripes => member.verifiedBeltStripes ?? member.beltStripes ?? 0;

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabel(member.gymRole);

    return InkWell(
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
        ],
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
