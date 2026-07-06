class Attendee {
  final String userId;
  final String name;
  final String beltRank;
  final int beltStripes;
  final String? avatarUrl;

  /// Whether a public profile exists for this attendee. Placeholder attendees
  /// (RSVP with no resolvable user document) are false and must not be linked
  /// to /user/:id — that endpoint 404s for them. Defaults false when the field
  /// is absent, which is the safe direction (not tappable).
  final bool hasProfile;

  const Attendee({
    required this.userId,
    required this.name,
    this.beltRank = 'white',
    this.beltStripes = 0,
    this.avatarUrl,
    this.hasProfile = false,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        beltRank: json['beltRank'] as String? ?? 'white',
        beltStripes: json['beltStripes'] as int? ?? 0,
        avatarUrl: json['avatarUrl'] as String?,
        hasProfile: json['hasProfile'] as bool? ?? false,
      );
}
