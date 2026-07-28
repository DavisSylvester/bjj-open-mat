import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../data/membership_repository.dart';
import '../models/gym_membership.dart';

class MyMembershipsScreen extends ConsumerWidget {
  const MyMembershipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final membershipsAsync = ref.watch(myMembershipsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('My Gyms', style: t.h2Style),
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: t.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: membershipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load memberships.', style: TextStyle(color: Colors.red[400])),
          ),
        ),
        data: (memberships) {
          if (memberships.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.dumbbell, size: 48, color: t.faint),
                    const SizedBox(height: 16),
                    Text('No gym memberships yet.', style: t.bodyStyle.copyWith(color: t.muted)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: memberships.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _MembershipCard(
              membership: memberships[index],
              onSetHome: () async {
                await ref.read(membershipRepositoryProvider).updateMine(
                  memberships[index].gymId,
                  isHome: true,
                );
                ref.invalidate(myMembershipsProvider);
              },
              onToggleRoster: (value) async {
                await ref.read(membershipRepositoryProvider).updateMine(
                  memberships[index].gymId,
                  visibleInRoster: value,
                );
                ref.invalidate(myMembershipsProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MembershipCard extends ConsumerWidget {
  final GymMembership membership;
  final VoidCallback onSetHome;
  final ValueChanged<bool> onToggleRoster;

  const _MembershipCard({
    required this.membership,
    required this.onSetHome,
    required this.onToggleRoster,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymAsync = ref.watch(gymByIdProvider(membership.gymId));
    final gymName = gymAsync.maybeWhen(data: (g) => g.name, orElse: () => '…');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14151A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gym name + home badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(LucideIcons.dumbbell, size: 16, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gymName,
                    style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700, color: t.text),
                  ),
                ),
                if (membership.verifiedMember)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Verified',
                      style: t.miniStyle.copyWith(color: t.green, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 20, indent: 16, endIndent: 16, color: t.border),
          // Set as home gym
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Icon(
                  membership.isHome ? LucideIcons.home : LucideIcons.home,
                  size: 16,
                  color: membership.isHome ? t.primary : t.faint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    membership.isHome ? 'Home gym' : 'Set as home gym',
                    style: t.bodyStyle.copyWith(
                      color: membership.isHome ? t.primary : t.text,
                      fontWeight: membership.isHome ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (!membership.isHome)
                  TextButton(
                    key: Key('set-home-${membership.gymId}'),
                    onPressed: onSetHome,
                    child: Text('Set home', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700)),
                  )
                else
                  Icon(LucideIcons.check, size: 16, color: t.primary),
              ],
            ),
          ),
          Divider(height: 16, indent: 16, endIndent: 16, color: t.border),
          // Show me on roster switch
          SwitchListTile(
            key: Key('roster-switch-${membership.gymId}'),
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            title: Text(
              'Show me on roster',
              style: t.bodyStyle.copyWith(color: t.text),
            ),
            subtitle: Text(
              'Lets others see you at this gym',
              style: t.miniStyle.copyWith(color: t.muted),
            ),
            value: membership.visibleInRoster,
            activeThumbColor: t.primary,
            onChanged: onToggleRoster,
          ),
        ],
      ),
    );
  }
}
