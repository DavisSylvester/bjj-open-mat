import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';

void main() {
  test('ConversationSummary.fromJson maps conversation + unread + last message', () {
    final s = ConversationSummary.fromJson(const {
      'conversation': {'id': 'c1', 'kind': 'direct', 'pairKey': 'u1|u2', 'createdBy': 'u1', 'lastMessagePreview': 'hey'},
      'unreadCount': 3,
      'muted': false,
      'lastMessage': {'id': 'm1', 'conversationId': 'c1', 'authorId': 'u2', 'body': 'hey'},
      'otherParticipantIds': ['u2'],
    });
    expect(s.conversation.kind, 'direct');
    expect(s.unreadCount, 3);
    expect(s.lastMessage?.body, 'hey');
    expect(s.otherParticipantIds, ['u2']);
  });
}
