import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/gym_claim_repository.dart';
import '../models/admin_gym_claim.dart';

class AdminGymClaimsScreen extends ConsumerWidget {
  const AdminGymClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0, title: Text('Gym Claims', style: t.h2Style)),
        body: Center(child: Text("You don't have access to this page.", style: t.bodyStyle.copyWith(color: t.muted))),
      );
    }

    final claimsAsync = ref.watch(adminGymClaimsProvider('pending'));
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0, title: Text('Gym Claims', style: t.h2Style)),
      body: claimsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load claims", style: t.bodyStyle.copyWith(color: t.muted))),
        data: (claims) => claims.isEmpty
            ? Center(child: Text('No pending claims', style: t.bodyStyle.copyWith(color: t.muted)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: claims.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ClaimTile(view: claims[i], t: t),
              ),
      ),
    );
  }
}

class _ClaimTile extends ConsumerWidget {
  final AdminGymClaim view;
  final AppTokens t;
  const _ClaimTile({required this.view, required this.t});

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(adminGymClaimsProvider('pending'));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't update the claim. Try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = view.claim;
    final repo = ref.read(gymClaimRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(t.cardRadius), border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(view.gymName, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${c.kind} • ${c.relationship}', style: t.miniStyle.copyWith(color: t.muted)),
          const SizedBox(height: 6),
          Text('Claimant: ${view.claimantEmail ?? c.claimantId}', style: t.miniStyle.copyWith(color: t.faint)),
          Text('Stated contact: ${c.contact}', style: t.miniStyle.copyWith(color: t.faint)),
          if (view.gymPhone != null) Text('Gym phone (listed): ${view.gymPhone}', style: t.miniStyle.copyWith(color: t.faint)),
          if (view.gymWebsite != null) Text('Gym website (listed): ${view.gymWebsite}', style: t.miniStyle.copyWith(color: t.faint)),
          const SizedBox(height: 6),
          Text(c.message, style: t.bodyStyle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _act(context, ref, () => repo.reject(c.id)),
                child: Text('Reject', style: t.miniStyle.copyWith(color: t.muted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _act(context, ref, () => repo.approve(c.id)),
                child: Text('Approve', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
