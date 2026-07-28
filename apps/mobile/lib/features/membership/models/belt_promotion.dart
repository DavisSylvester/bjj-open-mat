class BeltPromotion {
  final String id;
  final String userId;
  final String gymId;
  final String beltRank;
  final int beltStripes;
  final String promotedByUserId;
  final String promotedAt;
  final String? note;

  const BeltPromotion({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.beltRank,
    required this.beltStripes,
    required this.promotedByUserId,
    required this.promotedAt,
    this.note,
  });

  factory BeltPromotion.fromJson(Map<String, dynamic> json) => BeltPromotion(
        id: json['id'] as String,
        userId: json['userId'] as String,
        gymId: json['gymId'] as String,
        beltRank: json['beltRank'] as String,
        beltStripes: json['beltStripes'] as int,
        promotedByUserId: json['promotedByUserId'] as String,
        promotedAt: json['promotedAt'] as String,
        note: json['note'] as String?,
      );
}
