class CreateSessionRequest {
  final String gymId;
  final String title;
  final String startTime; // HH:mm 24h
  final String endTime;   // HH:mm 24h
  final int? dayOfWeek;   // 0=Sun..6=Sat (recurring)
  final String? specificDate; // YYYY-MM-DD (one-off)
  final bool isRecurring;
  final String giType;    // gi|nogi|both
  final String skillLevel; // all|beginner|intermediate|advanced
  final int? feeCents;
  final int? maxParticipants;
  final String? description;

  const CreateSessionRequest({
    required this.gymId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.dayOfWeek,
    this.specificDate,
    this.isRecurring = true,
    this.giType = 'both',
    this.skillLevel = 'all',
    this.feeCents,
    this.maxParticipants,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'gymId': gymId,
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (specificDate != null) 'specificDate': specificDate,
        'isRecurring': isRecurring,
        'giType': giType,
        'skillLevel': skillLevel,
        if (feeCents != null) 'feeCents': feeCents,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

class UpdateSessionRequest {
  final Map<String, dynamic> _fields;
  const UpdateSessionRequest(this._fields);
  Map<String, dynamic> toJson() => _fields;
}
