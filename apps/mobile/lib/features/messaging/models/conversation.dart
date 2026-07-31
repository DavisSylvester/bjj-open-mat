class Conversation {
  final String id;
  final String kind;
  final String? gymId;
  final String? title;
  final String? pairKey;
  final String createdBy;
  final String? createdAt;
  final String? lastMessageAt;
  final String? lastMessagePreview;

  const Conversation({
    required this.id,
    required this.kind,
    this.gymId,
    this.title,
    this.pairKey,
    required this.createdBy,
    this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        kind: json['kind'] as String,
        gymId: json['gymId'] as String?,
        title: json['title'] as String?,
        pairKey: json['pairKey'] as String?,
        createdBy: json['createdBy'] as String,
        createdAt: json['createdAt'] as String?,
        lastMessageAt: json['lastMessageAt'] as String?,
        lastMessagePreview: json['lastMessagePreview'] as String?,
      );
}
