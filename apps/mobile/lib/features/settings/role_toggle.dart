class RoleToggle {
  final String targetRole;
  final String label;
  final String destination;
  const RoleToggle(this.targetRole, this.label, this.destination);
}

/// Given the current role, compute what a single "switch role" tap should do.
/// Only practitioner and gym_owner participate; anything else becomes a gym owner.
RoleToggle roleToggle(String? currentRole) {
  if (currentRole == 'gym_owner') {
    return const RoleToggle('practitioner', 'Switch to Practitioner', '/');
  }
  return const RoleToggle('gym_owner', 'Switch to Gym Owner', '/owner/dashboard');
}
