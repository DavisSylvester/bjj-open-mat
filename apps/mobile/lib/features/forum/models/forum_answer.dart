class ForumAnswer {
  final String id;
  final String questionId;
  final String gymId;
  final String authorId;
  final String body;
  final bool accepted;
  final String? createdAt;
  final String? updatedAt;

  const ForumAnswer({
    required this.id,
    required this.questionId,
    required this.gymId,
    required this.authorId,
    required this.body,
    required this.accepted,
    this.createdAt,
    this.updatedAt,
  });

  factory ForumAnswer.fromJson(Map<String, dynamic> json) => ForumAnswer(
        id: json['id'] as String,
        questionId: json['questionId'] as String,
        gymId: json['gymId'] as String,
        authorId: json['authorId'] as String,
        body: json['body'] as String,
        accepted: json['accepted'] as bool? ?? false,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}
