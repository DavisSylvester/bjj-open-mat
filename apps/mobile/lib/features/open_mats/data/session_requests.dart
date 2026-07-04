class NewGymInput {
  final String name;
  final String address;
  final String? city;
  final String? state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  const NewGymInput({
    required this.name,
    required this.address,
    this.city,
    this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class CreateSessionRequest {
  final String? gymId;
  final NewGymInput? newGym;
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
    this.gymId,
    this.newGym,
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
        if (gymId != null) 'gymId': gymId,
        if (newGym != null) 'newGym': newGym!.toJson(),
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
