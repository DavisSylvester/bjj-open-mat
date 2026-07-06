class Attendee {
  final String userId;
  final String name;
  final String beltRank;
  final int beltStripes;
  final String? avatarUrl;

  const Attendee({
    required this.userId,
    required this.name,
    this.beltRank = 'white',
    this.beltStripes = 0,
    this.avatarUrl,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        beltRank: json['beltRank'] as String? ?? 'white',
        beltStripes: json['beltStripes'] as int? ?? 0,
        avatarUrl: json['avatarUrl'] as String?,
      );
}
