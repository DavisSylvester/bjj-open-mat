class CheckIn {
  final String id;
  final String openMatId;
  final String userId;
  final String sessionDate;
  final String checkedInAt;
  final int? rating;
  final String? review;
  final String? reviewedAt;
  final String? gymName;
  final String? openMatTitle;
  final String? userName;
  final String? beltRank;
  final String? createdAt;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final String locationStatus;
  final double? distanceM;
  final String? gymId;
  final String? gymCity;
  final String? gymState;
  final String? note;
  final int? rounds;
  final int? intensity;
  final int? partners;

  const CheckIn({
    required this.id,
    required this.openMatId,
    required this.userId,
    required this.sessionDate,
    required this.checkedInAt,
    this.rating,
    this.review,
    this.reviewedAt,
    this.gymName,
    this.openMatTitle,
    this.userName,
    this.beltRank,
    this.createdAt,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.locationStatus = 'no_location',
    this.distanceM,
    this.gymId,
    this.gymCity,
    this.gymState,
    this.note,
    this.rounds,
    this.intensity,
    this.partners,
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
      reviewedAt: json['reviewedAt'] as String?,
      gymName: json['gymName'] as String?,
      openMatTitle: json['openMatTitle'] as String?,
      userName: json['userName'] as String?,
      beltRank: json['beltRank'] as String?,
      createdAt: json['createdAt'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsAccuracyM: (json['gpsAccuracyM'] as num?)?.toDouble(),
      locationStatus: json['locationStatus'] as String? ?? 'no_location',
      distanceM: (json['distanceM'] as num?)?.toDouble(),
      gymId: json['gymId'] as String?,
      gymCity: json['gymCity'] as String?,
      gymState: json['gymState'] as String?,
      note: json['note'] as String?,
      rounds: json['rounds'] as int?,
      intensity: json['intensity'] as int?,
      partners: json['partners'] as int?,
    );
  }

  bool get canReview {
    final sessionDateTime = DateTime.tryParse(sessionDate);
    if (sessionDateTime == null) return false;
    return DateTime.now().difference(sessionDateTime).inHours <= 48;
  }
}
