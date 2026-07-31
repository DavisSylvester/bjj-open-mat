import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';
import 'package:bjj_open_mat/features/messaging/models/message_report.dart';
import 'package:bjj_open_mat/features/messaging/screens/conversation_screen.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeMessagingRepo implements MessagingRepository {
  final List<Map<String, String>> sendMessageCalls = [];
  final List<String> deleteMessageCalls = [];
  final List<Map<String, String>> blockUserCalls = [];
  final List<Map<String, String?>> reportMessageCalls = [];
  final List<Map<String, String>> editMessageCalls = [];

  @override
  Future<Message> sendMessage(String conversationId, String body) async {
    sendMessageCalls.add({'conversationId': conversationId, 'body': body});
    return Message(
      id: 'new-msg',
      conversationId: conversationId,
      authorId: 'user1',
      body: body,
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    deleteMessageCalls.add(messageId);
  }

  @override
  Future<void> blockUser(String userId) async {
    blockUserCalls.add({'userId': userId});
  }

  @override
  Future<void> reportMessage({
    String? messageId,
    required String reportedUserId,
    required String reason,
    String? note,
  }) async {
    reportMessageCalls.add({
      'messageId': messageId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'note': note,
    });
  }

  @override
  Future<Message> editMessage(String messageId, String body) async {
    editMessageCalls.add({'messageId': messageId, 'body': body});
    return Message(
      id: messageId,
      conversationId: 'c1',
      authorId: _kCurrentUserId,
      body: body,
    );
  }

  @override
  Future<List<ConversationSummary>> listConversations({
    int page = 1,
    int limit = 20,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Conversation> startDirect(String recipientId) async =>
      throw UnimplementedError();

  @override
  Future<Conversation> createGroup(
    String gymId,
    String title,
    List<String> participantIds,
  ) async =>
      throw UnimplementedError();

  @override
  Future<List<Conversation>> listChannels(String gymId) async =>
      throw UnimplementedError();

  @override
  Future<Conversation> createChannel(String gymId, String title) async =>
      throw UnimplementedError();

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<void> setMuted(String conversationId, bool muted) async =>
      throw UnimplementedError();

  @override
  Future<void> leave(String conversationId) async =>
      throw UnimplementedError();

  @override
  Future<void> addParticipants(
    String conversationId,
    List<String> userIds,
  ) async =>
      throw UnimplementedError();

  @override
  Future<List<MessageReport>> listGymReports(
    String gymId, {
    String? status,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> resolveReport(String reportId, String status) async =>
      throw UnimplementedError();

  @override
  Future<List<String>> listBlocks() async => throw UnimplementedError();

  @override
  Future<void> unblockUser(String blockId) async =>
      throw UnimplementedError();
}

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kCurrentUserId = 'user1';

final _messages = [
  Message(
    id: 'msg1',
    conversationId: 'c1',
    authorId: _kCurrentUserId,
    body: 'Hello from user1',
  ),
  Message(
    id: 'msg2',
    conversationId: 'c1',
    authorId: 'user2',
    body: 'deleted body',
    deletedAt: '2024-01-01T00:00:00Z',
  ),
];

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeMessagingRepo> _pump(
  WidgetTester tester, {
  List<Message>? messages,
  String kind = 'direct',
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeMessagingRepo();
  final resolvedMessages = messages ?? _messages;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messagingRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => _kCurrentUserId),
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        messagesProvider('c1').overrideWith(
          (_) async => resolvedMessages,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: ConversationScreen(
          conversationId: 'c1',
          kind: kind,
        ),
      ),
    ),
  );
  // Allow FutureProviders to resolve.
  await tester.pump();
  await tester.pump();
  return repo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders messages: deleted shows "message removed", normal shows body',
      (tester) async {
    await _pump(tester);

    expect(find.text('Hello from user1'), findsOneWidget);
    expect(find.text('message removed'), findsOneWidget);
    // The raw body of the deleted message must NOT appear.
    expect(find.text('deleted body'), findsNothing);
  });

  testWidgets('send message: type text and tap Send calls sendMessage',
      (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'A new message');
    await tester.pump();

    final sendButton = find.widgetWithIcon(IconButton, Icons.send);
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pump();

    expect(repo.sendMessageCalls, hasLength(1));
    expect(repo.sendMessageCalls.first['conversationId'], equals('c1'));
    expect(repo.sendMessageCalls.first['body'], equals('A new message'));
  });

  testWidgets('delete own message: long-press then tap Delete calls deleteMessage',
      (tester) async {
    final repo = await _pump(tester);

    // Long-press own message text.
    await tester.longPress(find.text('Hello from user1'));
    await tester.pumpAndSettle();

    // Tap the Delete option.
    final deleteOption = find.text('Delete');
    expect(deleteOption, findsOneWidget);
    await tester.tap(deleteOption);
    await tester.pump();

    expect(repo.deleteMessageCalls, hasLength(1));
    expect(repo.deleteMessageCalls.first, equals('msg1'));
  });

  testWidgets('empty state: when messages list is empty shows empty text',
      (tester) async {
    await _pump(tester, messages: []);

    expect(find.text('No messages yet. Say hello!'), findsOneWidget);
  });

  testWidgets(
      'block: tapping Block action calls blockUser(otherUserId) and pops screen',
      (tester) async {
    // Messages: one from u2 (the other user), one from u1 (current user).
    final directMessages = [
      Message(
        id: 'msg-a',
        conversationId: 'c1',
        authorId: 'u2',
        body: 'Hey there',
      ),
      Message(
        id: 'msg-b',
        conversationId: 'c1',
        authorId: 'u1',
        body: 'Hi u2',
      ),
    ];

    final repo = _FakeMessagingRepo();

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Use a NavigatorObserver to detect pop.
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWith((ref) => 'u1'),
          authStateProvider.overrideWith(() => _FakeAuthNotifier()),
          messagesProvider('c1').overrideWith((_) async => directMessages),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          navigatorObservers: [observer],
          home: ConversationScreen(
            conversationId: 'c1',
            gymId: null,
            kind: 'direct',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Tap the Block icon in the AppBar.
    final blockButton = find.widgetWithIcon(IconButton, Icons.block);
    expect(blockButton, findsOneWidget);
    await tester.tap(blockButton);
    await tester.pumpAndSettle();

    // Confirm dialog should appear — tap the Block confirm button.
    final confirmBlock = find.widgetWithText(TextButton, 'Block');
    expect(confirmBlock, findsOneWidget);
    await tester.tap(confirmBlock);
    await tester.pumpAndSettle();

    // blockUser('u2') must have been called.
    expect(repo.blockUserCalls, hasLength(1));
    expect(repo.blockUserCalls.first['userId'], equals('u2'));

    // Screen must have popped.
    expect(observer.didPopCount, greaterThan(0));
  });
}

// ── NavigatorObserver for pop detection ──────────────────────────────────────

class _TestNavigatorObserver extends NavigatorObserver {
  int didPopCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopCount++;
  }
}
