class CreateCheckInRequest {
  final String sessionDate;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final String? note;
  final String? beltRank;
  final int? rounds;
  final int? intensity;
  final int? partners;

  const CreateCheckInRequest({
    required this.sessionDate,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.note,
    this.beltRank,
    this.rounds,
    this.intensity,
    this.partners,
  });

  Map<String, dynamic> toJson() => {
        'sessionDate': sessionDate,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (gpsAccuracyM != null) 'gpsAccuracyM': gpsAccuracyM,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (beltRank != null) 'beltRank': beltRank,
        if (rounds != null) 'rounds': rounds,
        if (intensity != null) 'intensity': intensity,
        if (partners != null) 'partners': partners,
      };
}
