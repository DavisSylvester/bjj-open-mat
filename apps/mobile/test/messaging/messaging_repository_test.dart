import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';

// ---------------------------------------------------------------------------
// Fake adapter — routes by URL path segment
// ---------------------------------------------------------------------------
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    // GET /api/v1/messaging/conversations
    if (path.contains('/messaging/conversations') &&
        !path.contains('/messages') &&
        !path.contains('/read') &&
        !path.contains('/mute') &&
        !path.contains('/leave') &&
        !path.contains('/participants') &&
        options.method == 'GET') {
      return _json({
        'data': [
          {
            'conversation': {
              'id': 'c1',
              'kind': 'direct',
              'pairKey': 'u1|u2',
              'createdBy': 'u1',
            },
            'unreadCount': 2,
            'muted': false,
            'lastMessage': null,
            'otherParticipantIds': ['u2'],
          }
        ],
        'meta': {'page': 1, 'limit': 20, 'total': 1},
      });
    }

    // GET /api/v1/messaging/conversations/:id/messages
    if (path.contains('/messages') && options.method == 'GET') {
      return _json({
        'data': [
          {
            'id': 'm1',
            'conversationId': 'c1',
            'authorId': 'u1',
            'body': 'Hello!',
            'createdAt': '2026-07-29T00:00:00.000Z',
          }
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      });
    }

    // POST /api/v1/messaging/conversations/:id/messages
    if (path.contains('/messages') && options.method == 'POST') {
      return _json({
        'data': {
          'id': 'm2',
          'conversationId': 'c1',
          'authorId': 'u1',
          'body': 'World',
          'createdAt': '2026-07-29T01:00:00.000Z',
        },
      });
    }

    // POST /api/v1/messaging/direct
    if (path.endsWith('/messaging/direct')) {
      return _json({
        'data': {
          'id': 'c2',
          'kind': 'direct',
          'pairKey': 'u1|u3',
          'createdBy': 'u1',
        },
      });
    }

    // POST /api/v1/messaging/groups
    if (path.endsWith('/messaging/groups')) {
      return _json({
        'data': {
          'id': 'c3',
          'kind': 'group',
          'gymId': 'g1',
          'title': 'Team Alpha',
          'createdBy': 'u1',
        },
      });
    }

    // GET /api/v1/gyms/:id/channels
    if (path.contains('/channels') && options.method == 'GET') {
      return _json({
        'data': [
          {
            'id': 'ch1',
            'kind': 'channel',
            'gymId': 'g1',
            'title': 'General',
            'createdBy': 'u1',
          }
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      });
    }

    // POST /api/v1/gyms/:id/channels
    if (path.contains('/channels') && options.method == 'POST') {
      return _json({
        'data': {
          'id': 'ch2',
          'kind': 'channel',
          'gymId': 'g1',
          'title': 'Announcements',
          'createdBy': 'u1',
        },
      });
    }

    // POST .../read
    if (path.contains('/read')) {
      return _noContent();
    }

    // POST .../mute
    if (path.contains('/mute')) {
      return _noContent();
    }

    // POST .../leave
    if (path.contains('/leave')) {
      return _noContent();
    }

    // POST .../participants
    if (path.contains('/participants')) {
      return _noContent();
    }

    // PATCH /api/v1/messaging/messages/:id (editMessage)
    if (path.contains('/messaging/messages/') &&
        !path.contains('/report') &&
        options.method == 'PATCH') {
      return _json({
        'data': {
          'id': 'msg1',
          'conversationId': 'c1',
          'authorId': 'u1',
          'body': 'Edited body',
          'createdAt': '2026-07-29T00:00:00.000Z',
          'editedAt': '2026-07-29T02:00:00.000Z',
        },
      });
    }

    // DELETE /api/v1/messaging/messages/:id
    if (path.contains('/messaging/messages/') &&
        !path.contains('/report') &&
        options.method == 'DELETE') {
      return _noContent();
    }

    // POST .../report
    if (path.contains('/report')) {
      return _noContent();
    }

    // POST /api/v1/messaging/reports (no messageId)
    if (path.endsWith('/messaging/reports') && options.method == 'POST') {
      return _noContent();
    }

    // GET /api/v1/gyms/:id/message-reports
    if (path.contains('/message-reports') && options.method == 'GET') {
      return _json({
        'data': [
          {
            'id': 'r1',
            'messageId': 'm1',
            'reportedUserId': 'u2',
            'reporterId': 'u1',
            'gymId': 'g1',
            'reason': 'spam',
            'status': 'open',
          }
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      });
    }

    // POST /api/v1/messaging/reports/:id/resolve
    if (path.contains('/resolve')) {
      return _noContent();
    }

    // GET /api/v1/messaging/blocks
    if (path.endsWith('/messaging/blocks') && options.method == 'GET') {
      return _json({
        'data': [
          {
            'id': 'bl1',
            'blockerId': 'u1',
            'blockedId': 'u99',
            'createdAt': '2026-07-29T00:00:00.000Z',
          }
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      });
    }

    // POST /api/v1/messaging/blocks
    if (path.endsWith('/messaging/blocks') && options.method == 'POST') {
      return _noContent();
    }

    // DELETE /api/v1/messaging/blocks/:id
    if (path.contains('/messaging/blocks/') && options.method == 'DELETE') {
      return _noContent();
    }

    // Fallback
    return _noContent();
  }

  ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  ResponseBody _noContent() => ResponseBody.fromString('', 204, headers: {});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late Dio dio;
  late ApiMessagingRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _FakeAdapter();
    repo = ApiMessagingRepository(dio);
  });

  test('listConversations() parses list envelope with ConversationSummary', () async {
    final result = await repo.listConversations();
    expect(result, hasLength(1));
    expect(result.first.conversation.id, 'c1');
    expect(result.first.conversation.kind, 'direct');
    expect(result.first.unreadCount, 2);
    expect(result.first.otherParticipantIds, ['u2']);
  });

  test('listMessages() parses list envelope with Message items', () async {
    final result = await repo.listMessages('c1');
    expect(result, hasLength(1));
    expect(result.first.id, 'm1');
    expect(result.first.body, 'Hello!');
  });

  test('sendMessage() parses Message from data envelope', () async {
    final msg = await repo.sendMessage('c1', 'World');
    expect(msg.id, 'm2');
    expect(msg.body, 'World');
  });

  test('startDirect() parses Conversation from data envelope', () async {
    final conv = await repo.startDirect('u3');
    expect(conv.id, 'c2');
    expect(conv.kind, 'direct');
  });

  test('createGroup() parses Conversation from data envelope', () async {
    final conv = await repo.createGroup('g1', 'Team Alpha', ['u2', 'u3']);
    expect(conv.id, 'c3');
    expect(conv.title, 'Team Alpha');
  });

  test('listChannels() parses list of Conversation items', () async {
    final channels = await repo.listChannels('g1');
    expect(channels, hasLength(1));
    expect(channels.first.id, 'ch1');
    expect(channels.first.kind, 'channel');
    expect(channels.first.title, 'General');
  });

  test('createChannel() parses Conversation from data envelope', () async {
    final ch = await repo.createChannel('g1', 'Announcements');
    expect(ch.id, 'ch2');
    expect(ch.title, 'Announcements');
  });

  test('markRead() completes without error', () async {
    await expectLater(repo.markRead('c1'), completes);
  });

  test('setMuted() completes without error', () async {
    await expectLater(repo.setMuted('c1', true), completes);
  });

  test('leave() completes without error', () async {
    await expectLater(repo.leave('c1'), completes);
  });

  test('addParticipants() completes without error', () async {
    await expectLater(repo.addParticipants('c1', ['u4']), completes);
  });

  test('editMessage() parses Message from data envelope', () async {
    final msg = await repo.editMessage('msg1', 'Edited body');
    expect(msg.id, 'msg1');
    expect(msg.body, 'Edited body');
    expect(msg.editedAt, isNotNull);
  });

  test('deleteMessage() completes without error', () async {
    await expectLater(repo.deleteMessage('msg1'), completes);
  });

  test('reportMessage() with messageId completes without error', () async {
    await expectLater(
      repo.reportMessage(
        messageId: 'm1',
        reportedUserId: 'u2',
        reason: 'spam',
      ),
      completes,
    );
  });

  test('reportMessage() without messageId completes without error', () async {
    await expectLater(
      repo.reportMessage(
        reportedUserId: 'u2',
        reason: 'harassment',
      ),
      completes,
    );
  });

  test('listGymReports() parses list of MessageReport items', () async {
    final reports = await repo.listGymReports('g1');
    expect(reports, hasLength(1));
    expect(reports.first.id, 'r1');
    expect(reports.first.reason, 'spam');
    expect(reports.first.status, 'open');
  });

  test('resolveReport() completes without error', () async {
    await expectLater(repo.resolveReport('r1', 'resolved'), completes);
  });

  test('listBlocks() maps blockedId strings from items', () async {
    final blocks = await repo.listBlocks();
    expect(blocks, hasLength(1));
    expect(blocks.first, 'u99');
  });

  test('blockUser() completes without error', () async {
    await expectLater(repo.blockUser('u99'), completes);
  });

  test('unblockUser() completes without error', () async {
    await expectLater(repo.unblockUser('bl1'), completes);
  });
}
