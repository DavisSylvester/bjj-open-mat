class ClassAttendee {
  final String userId;
  final String name;
  final bool isMember;
  final String? beltRank;
  final String? avatarUrl;
  final bool hasProfile;

  const ClassAttendee({
    required this.userId,
    required this.name,
    required this.isMember,
    this.beltRank,
    this.avatarUrl,
    required this.hasProfile,
  });

  factory ClassAttendee.fromJson(Map<String, dynamic> json) => ClassAttendee(
        userId: json['userId'] as String,
        name: json['name'] as String,
        isMember: json['isMember'] as bool,
        beltRank: json['beltRank'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        hasProfile: json['hasProfile'] as bool,
      );
}
