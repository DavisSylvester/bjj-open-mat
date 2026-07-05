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
  final int? feeCents;
  final String? city;
  final String? state;
  final String? address;
  final double? gymRating;

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
    this.feeCents,
    this.city,
    this.state,
    this.address,
    this.gymRating,
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
      feeCents: json['feeCents'] as int?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      address: json['address'] as String?,
      gymRating: (json['gymRating'] as num?)?.toDouble(),
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

  String? get locationLabel {
    if (city != null && state != null) return '$city, $state';
    return city ?? state;
  }

  String get feeLabel {
    if (feeCents == null || feeCents == 0) return 'Free';
    final dollars = feeCents! / 100;
    return dollars == dollars.roundToDouble()
        ? '\$${dollars.toStringAsFixed(0)}'
        : '\$${dollars.toStringAsFixed(2)}';
  }

  String get startLabel => _to12h(startTime);
  String get endLabel => _to12h(endTime);

  static String _to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  /// The concrete date this session's "going" list is keyed by:
  /// one-off sessions use [specificDate]; recurring sessions use the next
  /// occurrence of [dayOfWeek] (0=Sun..6=Sat) on/after [from] (defaults now).
  String nextSessionDate({DateTime? from}) {
    if (specificDate != null && specificDate!.isNotEmpty) {
      return specificDate!.split('T').first;
    }
    final base = from ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    if (dayOfWeek == null) return _fmtDate(today);
    final targetDart = dayOfWeek == 0 ? 7 : dayOfWeek!; // Dart: Mon=1..Sun=7
    var d = today;
    for (var i = 0; i < 7; i++) {
      if (d.weekday == targetDart) return _fmtDate(d);
      d = d.add(const Duration(days: 1));
    }
    return _fmtDate(today);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
