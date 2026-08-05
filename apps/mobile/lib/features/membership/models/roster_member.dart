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
      );

  bool get isHidden => status == 'hidden';
  bool get isInactive => status == 'inactive';
}
