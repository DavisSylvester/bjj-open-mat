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

/// True when the current user can manage [gymId] — i.e. the gym's owner, an
/// admin, or has `owner`/`coach` role on its roster.
bool deriveCanManageGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId && myId != null;
  final rosterAsync = ref.watch(rosterProvider(gymId));
  final myGymRole = rosterAsync.maybeWhen(
    data: (members) => myId != null
        ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
        : null,
    orElse: () => null,
  );
  return isAdmin || isOwner || myGymRole == 'owner' || myGymRole == 'coach';
}

/// True when the current user can access [gymId]'s forum — i.e. an active
/// member, the gym's owner, or an admin.
bool deriveCanAccessForumGym(WidgetRef ref, {required String gymId, required String? ownerId}) {
  final myId = ref.watch(currentUserIdProvider);
  if (myId == null) return false;
  final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
  final isOwner = ownerId == myId;
  final rosterAsync = ref.watch(rosterProvider(gymId));
  final isMember = rosterAsync.maybeWhen(
    data: (members) => members.any((m) => m.userId == myId),
    orElse: () => false,
  );
  return isAdmin || isOwner || isMember;
}
