import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/widgets/join_gym_button.dart';

/// Shared gym-permission derivations.
///
/// Both the gym detail screen and the My Gym tab need to know whether the
/// current user can manage a gym (owner/coach/admin) or access its forum
/// (member/owner/admin). These mirror the server-side checks
/// (`assertCanManageGym`, `assertActiveMember`) so a gated UI action never
/// points at an endpoint that will reject it. Kept in one place so the two
/// call sites can't drift.
///
/// The caller's own membership comes from [myMembershipsProvider], never from
/// [rosterProvider]: a hidden member is absent from the roster but still holds
/// their privileges server-side, so deriving from the roster would revoke
/// access the API would have granted.

/// True when a membership status grants gym-member privileges. Mirrors
/// `hasMemberPrivileges` in @bjj/contract.
bool _hasPrivileges(String status) => status == 'active' || status == 'hidden';

/// True when the current user can manage [gymId] — i.e. the gym's owner, an
/// admin, or holds `owner`/`coach` role on an active or hidden membership.
bool deriveCanManageGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId && myId != null;
  final mine = ref.watch(myMembershipsProvider).maybeWhen(
        data: (rows) => rows.where((m) => m.gymId == gymId).firstOrNull,
        orElse: () => null,
      );
  final canManageViaRole =
      mine != null && _hasPrivileges(mine.status) && (mine.gymRole == 'owner' || mine.gymRole == 'coach');
  return isAdmin || isOwner || canManageViaRole;
}

/// True when the current user can access [gymId]'s forum — i.e. holds member
/// privileges there, owns the gym, or is an admin.
bool deriveCanAccessForumGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  if (myId == null) return false;
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId;
  final mine = ref.watch(myMembershipsProvider).maybeWhen(
        data: (rows) => rows.where((m) => m.gymId == gymId).firstOrNull,
        orElse: () => null,
      );
  return isAdmin || isOwner || (mine != null && _hasPrivileges(mine.status));
}
