class ForumQuestion {
  final String id;
  final String gymId;
  final String authorId;
  final String category;
  final String title;
  final String body;
  final bool pinned;
  final bool locked;
  final String? acceptedAnswerId;
  final int answerCount;
  final String? createdAt;
  final String? updatedAt;

  const ForumQuestion({
    required this.id,
    required this.gymId,
    required this.authorId,
    required this.category,
    required this.title,
    required this.body,
    required this.pinned,
    required this.locked,
    this.acceptedAnswerId,
    required this.answerCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ForumQuestion.fromJson(Map<String, dynamic> json) => ForumQuestion(
        id: json['id'] as String,
        gymId: json['gymId'] as String,
        authorId: json['authorId'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        pinned: json['pinned'] as bool? ?? false,
        locked: json['locked'] as bool? ?? false,
        acceptedAnswerId: json['acceptedAnswerId'] as String?,
        answerCount: json['answerCount'] as int? ?? 0,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}
