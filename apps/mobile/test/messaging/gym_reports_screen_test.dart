import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';
import 'package:bjj_open_mat/features/messaging/models/message_report.dart';
import 'package:bjj_open_mat/features/messaging/screens/gym_reports_screen.dart';

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeMessagingRepo implements MessagingRepository {
  final List<(String, String)> resolveCalls = [];

  @override
  Future<List<MessageReport>> listGymReports(String gymId, {String? status}) async => [
        const MessageReport(
          id: 'r1',
          reportedUserId: 'u2',
          reporterId: 'u1',
          gymId: 'g1',
          reason: 'spam',
          status: 'open',
        ),
      ];

  @override
  Future<void> resolveReport(String reportId, String status) async {
    resolveCalls.add((reportId, status));
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
  Future<List<String>> listBlocks() async => [];
  @override
  Future<void> blockUser(String userId) async {}
  @override
  Future<void> unblockUser(String blockedId) async {}
}

// ── Fixture: one open report ──────────────────────────────────────────────────

const _openReport = MessageReport(
  id: 'r1',
  reportedUserId: 'u2',
  reporterId: 'u1',
  gymId: 'g1',
  reason: 'spam',
  status: 'open',
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Helper: pump screen as a MANAGER (roster owner, user u1) ──────────────
  Future<void> pumpAsManager(
    WidgetTester tester,
    _FakeMessagingRepo repo, {
    String reason = 'spam',
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gymMessageReportsProvider((gymId: 'g1', status: 'open'))
              .overrideWith((_) async => [
                    MessageReport(
                      id: 'r1',
                      reportedUserId: 'u2',
                      reporterId: 'u1',
                      gymId: 'g1',
                      reason: reason,
                      status: 'open',
                    ),
                  ]),
          messagingRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(() => _FakeAuthNotifier()),
          gymByIdProvider('g1')
              .overrideWith((_) async => const Gym(id: 'g1', name: 'Test Gym', address: '123 Main St')),
          rosterProvider('g1').overrideWith((_) async => [
                const RosterMember(
                  userId: 'u1',
                  name: 'Alice',
                  gymRole: 'owner',
                  verifiedMember: true,
                  hasProfile: true,
                ),
              ]),
          currentUserIdProvider.overrideWith((ref) => 'u1'),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const GymReportsScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // ── Helper: pump screen as a NON-MANAGER (not in roster, not admin) ────────
  Future<void> pumpAsNonManager(
    WidgetTester tester,
    _FakeMessagingRepo repo,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(() => _FakeAuthNotifier()),
          gymByIdProvider('g1')
              .overrideWith((_) async => const Gym(id: 'g1', name: 'Test Gym', address: '123 Main St')),
          rosterProvider('g1').overrideWith((_) async => <RosterMember>[]),
          currentUserIdProvider.overrideWith((ref) => 'u99'),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const GymReportsScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // ── Manager-guard tests ───────────────────────────────────────────────────

  testWidgets('non-manager sees access-denied message and no report rows', (tester) async {
    final fakeRepo = _FakeMessagingRepo();
    await pumpAsNonManager(tester, fakeRepo);

    expect(find.text("You don't have access to this page."), findsOneWidget);
    expect(find.text('spam'), findsNothing);
    expect(find.text('Mark reviewed'), findsNothing);
  });

  testWidgets('manager (owner roster role) sees report rows and action buttons', (tester) async {
    final fakeRepo = _FakeMessagingRepo();
    await pumpAsManager(tester, fakeRepo);

    expect(find.text('spam'), findsOneWidget);
    expect(find.text('Mark reviewed'), findsOneWidget);
    expect(find.text("You don't have access to this page."), findsNothing);
  });

  // ── Existing functional tests (now guarded by manager context) ────────────

  testWidgets('GymReportsScreen shows report reason and Mark-reviewed button', (tester) async {
    final fakeRepo = _FakeMessagingRepo();
    await pumpAsManager(tester, fakeRepo);

    expect(find.text('spam'), findsOneWidget);
    expect(find.text('Mark reviewed'), findsOneWidget);
  });

  testWidgets('Tapping Mark-reviewed calls resolveReport with reviewed status', (tester) async {
    final fakeRepo = _FakeMessagingRepo();
    await pumpAsManager(tester, fakeRepo);

    await tester.tap(find.text('Mark reviewed'));
    await tester.pump();

    expect(fakeRepo.resolveCalls, contains(('r1', 'reviewed')));
  });

  testWidgets('Tapping Dismiss calls resolveReport with dismissed status', (tester) async {
    final fakeRepo = _FakeMessagingRepo();
    await pumpAsManager(tester, fakeRepo);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(fakeRepo.resolveCalls, contains(('r1', 'dismissed')));
  });
}
