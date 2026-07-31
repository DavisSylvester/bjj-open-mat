class ConversationParticipant {
  final String id;
  final String conversationId;
  final String userId;
  final String role;
  final String? lastReadAt;
  final bool muted;
  final String? leftAt;

  const ConversationParticipant({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    this.lastReadAt,
    required this.muted,
    this.leftAt,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      ConversationParticipant(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        userId: json['userId'] as String,
        role: json['role'] as String,
        lastReadAt: json['lastReadAt'] as String?,
        muted: json['muted'] as bool? ?? false,
        leftAt: json['leftAt'] as String?,
      );
}
