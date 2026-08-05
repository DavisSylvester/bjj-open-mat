class GymMembership {
  final String id;
  final String gymId;
  final String userId;
  final String status;
  final bool verifiedMember;
  final String gymRole;
  final bool isHome;
  final bool visibleInRoster;
  final String joinMethod;
  final String joinedAt;
  final String? createdAt;
  final String? statusUpdatedAt;
  final String? statusUpdatedBy;

  const GymMembership({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.status,
    required this.verifiedMember,
    required this.gymRole,
    required this.isHome,
    required this.visibleInRoster,
    required this.joinMethod,
    required this.joinedAt,
    this.createdAt,
    this.statusUpdatedAt,
    this.statusUpdatedBy,
  });

  factory GymMembership.fromJson(Map<String, dynamic> json) => GymMembership(
    id: json['id'] as String,
    gymId: json['gymId'] as String,
    userId: json['userId'] as String,
    status: json['status'] as String,
    verifiedMember: json['verifiedMember'] as bool,
    gymRole: json['gymRole'] as String,
    isHome: json['isHome'] as bool,
    visibleInRoster: json['visibleInRoster'] as bool,
    joinMethod: json['joinMethod'] as String,
    joinedAt: json['joinedAt'] as String,
    createdAt: json['createdAt'] as String?,
    statusUpdatedAt: json['statusUpdatedAt'] as String?,
    statusUpdatedBy: json['statusUpdatedBy'] as String?,
  );
}
