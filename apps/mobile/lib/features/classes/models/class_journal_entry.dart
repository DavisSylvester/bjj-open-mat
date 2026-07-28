class ClassJournalEntry {
  final String id;
  final String classId;
  final String gymId;
  final String userId;
  final String date;
  final String? whatWasTaught;
  final List<String> techniqueTags;
  final int? rounds;
  final int? intensity;
  final int? partners;
  final String? note;
  final bool shared;

  const ClassJournalEntry({
    required this.id,
    required this.classId,
    required this.gymId,
    required this.userId,
    required this.date,
    this.whatWasTaught,
    this.techniqueTags = const [],
    this.rounds,
    this.intensity,
    this.partners,
    this.note,
    this.shared = false,
  });

  factory ClassJournalEntry.fromJson(Map<String, dynamic> json) => ClassJournalEntry(
        id: json['id'] as String,
        classId: json['classId'] as String,
        gymId: json['gymId'] as String,
        userId: json['userId'] as String,
        date: json['date'] as String,
        whatWasTaught: json['whatWasTaught'] as String?,
        techniqueTags: (json['techniqueTags'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        rounds: json['rounds'] as int?,
        intensity: json['intensity'] as int?,
        partners: json['partners'] as int?,
        note: json['note'] as String?,
        shared: json['shared'] as bool? ?? false,
      );
}
