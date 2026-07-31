import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';
import 'package:bjj_open_mat/features/messaging/models/message_report.dart';
import 'package:bjj_open_mat/features/messaging/screens/blocked_users_screen.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeMessagingRepo implements MessagingRepository {
  final List<String> unblockCalls = [];

  @override
  Future<List<String>> listBlocks() async => ['u2'];

  @override
  Future<void> unblockUser(String blockedId) async {
    unblockCalls.add(blockedId);
  }

  @override
  Future<List<ConversationSummary>> listConversations({int page = 1, int limit = 20}) async => [];
  @override
  Future<List<Message>> listMessages(String conversationId, {String? before, int limit = 50}) async => [];
  @override
  Future<Message> sendMessage(String conversationId, String body) => throw UnimplementedError();
  @override
  Future<Conversation> startDirect(String recipientId) => throw UnimplementedError();
  @override
  Future<Conversation> createGroup(String gymId, String title, List<String> participantIds) => throw UnimplementedError();
  @override
  Future<List<Conversation>> listChannels(String gymId) async => [];
  @override
  Future<Conversation> createChannel(String gymId, String title) => throw UnimplementedError();
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<void> setMuted(String conversationId, bool muted) async {}
  @override
  Future<void> leave(String conversationId) async {}
  @override
  Future<void> addParticipants(String conversationId, List<String> userIds) async {}
  @override
  Future<Message> editMessage(String messageId, String body) => throw UnimplementedError();
  @override
  Future<void> deleteMessage(String messageId) async {}
  @override
  Future<void> reportMessage({String? messageId, required String reportedUserId, required String reason, String? note}) async {}
  @override
  Future<List<MessageReport>> listGymReports(String gymId, {String? status}) async => [];
  @override
  Future<void> resolveReport(String reportId, String status) async {}
  @override
  Future<void> blockUser(String userId) async {}
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('BlockedUsersScreen shows blocked user id and Unblock button', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeRepo = _FakeMessagingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blocksProvider.overrideWith((_) async => ['u2']),
          messagingRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const BlockedUsersScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('u2'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('Tapping Unblock calls unblockUser and invalidates blocksProvider', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeRepo = _FakeMessagingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blocksProvider.overrideWith((_) async => ['u2']),
          messagingRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const BlockedUsersScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Unblock'));
    await tester.pump();

    expect(fakeRepo.unblockCalls, contains('u2'));
  });
}
