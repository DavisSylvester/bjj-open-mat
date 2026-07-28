class InstructorRatingSummary {
  final String instructorUserId;
  final double avg;
  final int count;

  const InstructorRatingSummary({
    required this.instructorUserId,
    required this.avg,
    required this.count,
  });

  factory InstructorRatingSummary.fromJson(Map<String, dynamic> json) => InstructorRatingSummary(
        instructorUserId: json['instructorUserId'] as String,
        avg: (json['avg'] as num).toDouble(),
        count: json['count'] as int,
      );
}
