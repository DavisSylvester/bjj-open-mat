class OpenMat {
  final String id;
  final String gymId;
  final String? hostId;
  final String title;
  final String? description;
  final int? dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isRecurring;
  final String? specificDate;
  final int? maxParticipants;
  final String skillLevel;
  final bool isGiSession;
  final bool isCancelled;
  final int? checkinCount;
  final String? gymName;
  final double? distanceKm;
  final String? createdAt;

  const OpenMat({
    required this.id,
    required this.gymId,
    this.hostId,
    required this.title,
    this.description,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isRecurring = true,
    this.specificDate,
    this.maxParticipants,
    this.skillLevel = 'all',
    this.isGiSession = false,
    this.isCancelled = false,
    this.checkinCount,
    this.gymName,
    this.distanceKm,
    this.createdAt,
  });

  factory OpenMat.fromJson(Map<String, dynamic> json) {
    return OpenMat(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      gymId: json['gymId'] as String? ?? '',
      hostId: json['hostId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dayOfWeek: json['dayOfWeek'] as int?,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      isRecurring: json['isRecurring'] as bool? ?? true,
      specificDate: json['specificDate'] as String?,
      maxParticipants: json['maxParticipants'] as int?,
      skillLevel: json['skillLevel'] as String? ?? 'all',
      isGiSession: json['isGiSession'] as bool? ?? false,
      isCancelled: json['isCancelled'] as bool? ?? false,
      checkinCount: json['checkinCount'] as int?,
      gymName: json['gymName'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String?,
    );
  }

  String get skillBadge {
    switch (skillLevel) {
      case 'beginner': return 'Beginner';
      case 'intermediate': return 'Intermediate';
      case 'advanced': return 'Advanced';
      default: return 'All Levels';
    }
  }

  String get giBadge => isGiSession ? 'Gi' : 'No-Gi';

  String get dayName {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7 ? days[dayOfWeek!] : '';
  }
}
