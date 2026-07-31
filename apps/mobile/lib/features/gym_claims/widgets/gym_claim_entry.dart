import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/gym_claim_repository.dart';

class GymClaimEntry extends ConsumerWidget {
  final String gymId;
  final String? ownerId;
  const GymClaimEntry({super.key, required this.gymId, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final myId = ref.watch(currentUserIdProvider);

    // Owner sees no entry point.
    if (myId != null && ownerId == myId) return const SizedBox.shrink();
    // Signed-out users can't claim.
    if (myId == null) return const SizedBox.shrink();

    final claimAsync = ref.watch(myGymClaimProvider(gymId));
    return claimAsync.maybeWhen(
      data: (claim) {
        if (claim != null && claim.status == 'pending') {
          return _chip(t, 'Claim pending review');
        }
        final kind = ownerId != null ? 'transfer' : 'claim';
        final label = ownerId != null ? 'Request ownership' : 'Claim this gym';
        return _button(context, t, label, kind);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _button(BuildContext context, AppTokens t, String label, String kind) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => context.push('/gym/$gymId/claim?kind=$kind'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_outlined, size: 16, color: t.text),
            const SizedBox(width: 8),
            Text(label, style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _chip(AppTokens t, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.primary.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hourglass_top, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Text(label, style: t.miniStyle.copyWith(color: t.primary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
