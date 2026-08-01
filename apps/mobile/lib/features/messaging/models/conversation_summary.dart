import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';

/// A conversation participant resolved to a human-readable name, so the UI
/// never has to show a raw user id (e.g. an Auth0 subject `google-oauth2|…`).
class ParticipantRef {
  final String userId;
  final String displayName;

  const ParticipantRef({required this.userId, required this.displayName});

  factory ParticipantRef.fromJson(Map<String, dynamic> json) => ParticipantRef(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
      );
}

class ConversationSummary {
  final Conversation conversation;
  final int unreadCount;
  final bool muted;
  final Message? lastMessage;
  final List<String> otherParticipantIds;
  final List<ParticipantRef> otherParticipants;

  const ConversationSummary({
    required this.conversation,
    required this.unreadCount,
    required this.muted,
    this.lastMessage,
    required this.otherParticipantIds,
    this.otherParticipants = const [],
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
        otherParticipants: (json['otherParticipants'] as List<dynamic>?)
                ?.map((e) => ParticipantRef.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
