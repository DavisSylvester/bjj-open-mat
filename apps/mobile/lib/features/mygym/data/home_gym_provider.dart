import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/models/gym_membership.dart';

/// Decides which gym the My Gym tab shows.
///
/// Two independent notions of a home gym exist and can disagree:
/// `UserProfile.homeGymId` (set on the profile screen) and
/// `GymMembership.isHome` (set from My Gyms). The profile value wins, because a
/// user can set it without ever joining — which is the common case today.
///
/// This is deliberately a papering-over. The real fix is making a profile home
/// gym create or update a membership so the two cannot diverge; that needs a
/// backend change and a migration, and is tracked as follow-up in the spec.
String? resolveHomeGymId({
  required String? profileHomeGymId,
  required List<GymMembership> memberships,
}) {
  if (profileHomeGymId != null && profileHomeGymId.isNotEmpty) {
    return profileHomeGymId;
  }
  for (final m in memberships) {
    if (m.isHome) return m.gymId;
  }
  return null;
}

/// The resolved gym id, or null when the user has no gym yet.
///
/// A membership lookup failure resolves to null rather than an error: the tab's
/// empty state ("find your gym") is a better outcome than an error screen.
final homeGymIdProvider = FutureProvider<String?>((ref) async {
  final profileHomeGymId = ref.watch(authStateProvider).user?.homeGymId;
  List<GymMembership> memberships;
  try {
    memberships = await ref.watch(myMembershipsProvider.future);
  } catch (_) {
    memberships = const [];
  }
  return resolveHomeGymId(profileHomeGymId: profileHomeGymId, memberships: memberships);
});
