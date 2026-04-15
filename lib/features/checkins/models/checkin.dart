class CheckIn {
  final String id;
  final String openMatId;
  final String userId;
  final String sessionDate;
  final String checkedInAt;
  final int? rating;
  final String? review;
  final String? gymName;
  final String? openMatTitle;
  final String? userName;
  final String? beltRank;
  final String? createdAt;

  const CheckIn({
    required this.id,
    required this.openMatId,
    required this.userId,
    required this.sessionDate,
    required this.checkedInAt,
    this.rating,
    this.review,
    this.gymName,
    this.openMatTitle,
    this.userName,
    this.beltRank,
    this.createdAt,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      openMatId: json['openMatId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      sessionDate: json['sessionDate'] as String? ?? '',
      checkedInAt: json['checkedInAt'] as String? ?? '',
      rating: json['rating'] as int?,
      review: json['review'] as String?,
      gymName: json['gymName'] as String?,
      openMatTitle: json['openMatTitle'] as String?,
      userName: json['userName'] as String?,
      beltRank: json['beltRank'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  bool get canReview {
    final sessionDateTime = DateTime.tryParse(sessionDate);
    if (sessionDateTime == null) return false;
    return DateTime.now().difference(sessionDateTime).inHours <= 48;
  }
}
