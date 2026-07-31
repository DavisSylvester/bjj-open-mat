import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';

class ConversationSummary {
  final Conversation conversation;
  final int unreadCount;
  final bool muted;
  final Message? lastMessage;
  final List<String> otherParticipantIds;

  const ConversationSummary({
    required this.conversation,
    required this.unreadCount,
    required this.muted,
    this.lastMessage,
    required this.otherParticipantIds,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        conversation: Conversation.fromJson(
          json['conversation'] as Map<String, dynamic>,
        ),
        unreadCount: json['unreadCount'] as int? ?? 0,
        muted: json['muted'] as bool? ?? false,
        lastMessage: json['lastMessage'] != null
            ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
            : null,
        otherParticipantIds: (json['otherParticipantIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );
}
