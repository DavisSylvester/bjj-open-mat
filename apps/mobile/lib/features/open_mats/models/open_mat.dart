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
  final String giType; // gi | nogi | both
  final bool isCancelled;
  final int? attendeeCount;
  final String? gymName;
  final double? distanceKm;
  final String? createdAt;
  final bool verified;
  final String status;

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
    this.giType = 'both',
    this.isCancelled = false,
    this.attendeeCount,
    this.gymName,
    this.distanceKm,
    this.createdAt,
    this.verified = false,
    this.status = 'live',
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
      giType: json['giType'] as String? ?? 'both',
      isCancelled: json['isCancelled'] as bool? ?? false,
      attendeeCount: json['attendeeCount'] as int?,
      gymName: json['gymName'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String?,
      verified: json['verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'live',
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

  String get giBadge {
    switch (giType) {
      case 'gi': return 'Gi';
      case 'nogi': return 'No-Gi';
      default: return 'Gi & No-Gi';
    }
  }

  String get dayName {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7 ? days[dayOfWeek!] : '';
  }
}
