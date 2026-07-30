class Message {
  final String id;
  final String conversationId;
  final String authorId;
  final String body;
  final String? createdAt;
  final String? editedAt;
  final String? deletedAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.body,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        authorId: json['authorId'] as String,
        body: json['body'] as String,
        createdAt: json['createdAt'] as String?,
        editedAt: json['editedAt'] as String?,
        deletedAt: json['deletedAt'] as String?,
      );
}
