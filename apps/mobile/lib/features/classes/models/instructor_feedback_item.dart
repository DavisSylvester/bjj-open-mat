class InstructorFeedbackItem {
  final String classId;
  final String date;
  final int stars;
  final String? comment;
  final String? ratedByName;
  final bool anonymous;
  final String? createdAt;

  const InstructorFeedbackItem({
    required this.classId,
    required this.date,
    required this.stars,
    this.comment,
    this.ratedByName,
    this.anonymous = false,
    this.createdAt,
  });

  factory InstructorFeedbackItem.fromJson(Map<String, dynamic> json) => InstructorFeedbackItem(
        classId: json['classId'] as String,
        date: json['date'] as String,
        stars: json['stars'] as int,
        comment: json['comment'] as String?,
        ratedByName: json['ratedByName'] as String?,
        anonymous: json['anonymous'] as bool? ?? false,
        createdAt: json['createdAt'] as String?,
      );
}
