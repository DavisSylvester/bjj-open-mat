class RosterMember {
  final String userId;
  final String name;
  final String? beltRank;
  final int? beltStripes;
  final String? verifiedBeltRank;
  final int? verifiedBeltStripes;
  final String? avatarUrl;
  final String gymRole;
  final bool verifiedMember;
  final bool hasProfile;
  final String status;
  final bool? visibleInRoster;

  const RosterMember({
    required this.userId,
    required this.name,
    this.beltRank,
    this.beltStripes,
    this.verifiedBeltRank,
    this.verifiedBeltStripes,
    this.avatarUrl,
    required this.gymRole,
    required this.verifiedMember,
    required this.hasProfile,
    this.status = 'active',
    this.visibleInRoster,
  });

  factory RosterMember.fromJson(Map<String, dynamic> json) => RosterMember(
        userId: json['userId'] as String,
        name: json['name'] as String,
        beltRank: json['beltRank'] as String?,
        beltStripes: json['beltStripes'] as int?,
        verifiedBeltRank: json['verifiedBeltRank'] as String?,
        verifiedBeltStripes: json['verifiedBeltStripes'] as int?,
        avatarUrl: json['avatarUrl'] as String?,
        gymRole: json['gymRole'] as String,
        verifiedMember: json['verifiedMember'] as bool,
        hasProfile: json['hasProfile'] as bool,
        status: json['status'] as String? ?? 'active',
        // Only present on manager rosters (?includeHidden=true); absent on
        // the public payload, which must not throw.
        visibleInRoster: json['visibleInRoster'] as bool?,
      );

  bool get isHidden => status == 'hidden';
  bool get isInactive => status == 'inactive';

  /// True when an otherwise-active member has toggled themselves off the
  /// public roster (the self-service flag), as distinct from an owner/coach
  /// hiding them via [status].
  bool get isSelfHidden => status == 'active' && visibleInRoster == false;

  /// True when the member is off the public roster for any reason — owner
  /// hidden, self-hidden, or inactive. Drives both the dimmed-cell styling
  /// and the "hidden" badge in the manager roster view.
  bool get isOffRoster => isHidden || isInactive || isSelfHidden;
}
