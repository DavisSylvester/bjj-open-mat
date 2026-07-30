import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/features/messaging/models/message.dart';
import 'package:bjj_open_mat/features/messaging/models/message_report.dart';
import 'package:bjj_open_mat/features/messaging/screens/new_message_screen.dart';

// ── Fake MessagingRepository ──────────────────────────────────────────────────

class _FakeMessagingRepository implements MessagingRepository {
  final List<String> startDirectCalls = [];
  final List<({String gymId, String title, List<String> participantIds})> createGroupCalls = [];
  final List<({String gymId, String title})> createChannelCalls = [];

  Conversation _makeConversation(String kind) => Conversation(
        id: 'conv-123',
        kind: kind,
        gymId: 'g1',
        createdBy: 'u1',
      );

  @override
  Future<Conversation> startDirect(String recipientId) async {
    startDirectCalls.add(recipientId);
    return _makeConversation('direct');
  }

  @override
  Future<Conversation> createGroup(
    String gymId,
    String title,
    List<String> participantIds,
  ) async {
    createGroupCalls.add((gymId: gymId, title: title, participantIds: participantIds));
    return _makeConversation('group');
  }

  @override
  Future<Conversation> createChannel(String gymId, String title) async {
    createChannelCalls.add((gymId: gymId, title: title));
    return _makeConversation('channel');
  }

  @override
  Future<List<ConversationSummary>> listConversations({int page = 1, int limit = 20}) async => [];

  @override
  Future<List<Message>> listMessages(String conversationId, {String? before, int limit = 50}) async => [];

  @override
  Future<Message> sendMessage(String conversationId, String body) async => throw UnimplementedError();

  @override
  Future<List<Conversation>> listChannels(String gymId) async => [];

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<void> setMuted(String conversationId, bool muted) async {}

  @override
  Future<void> leave(String conversationId) async {}

  @override
  Future<void> addParticipants(String conversationId, List<String> userIds) async {}

  @override
  Future<Message> editMessage(String messageId, String body) async => throw UnimplementedError();

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<void> reportMessage({
    String? messageId,
    required String reportedUserId,
    required String reason,
    String? note,
  }) async {}

  @override
  Future<List<MessageReport>> listGymReports(String gymId, {String? status}) async => [];

  @override
  Future<void> resolveReport(String reportId, String status) async {}

  @override
  Future<List<String>> listBlocks() async => [];

  @override
  Future<void> blockUser(String userId) async {}

  @override
  Future<void> unblockUser(String blockId) async {}
}

// ── Fake roster members ───────────────────────────────────────────────────────

final _fakeMembers = <RosterMember>[
  RosterMember(
    userId: 'user-alice',
    name: 'Alice',
    gymRole: 'member',
    verifiedMember: true,
    hasProfile: true,
  ),
  RosterMember(
    userId: 'user-bob',
    name: 'Bob',
    gymRole: 'member',
    verifiedMember: true,
    hasProfile: true,
  ),
];

// ── Navigation spy ────────────────────────────────────────────────────────────

class _SpyNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
  }
}

// ── Pump helpers ──────────────────────────────────────────────────────────────

_FakeMessagingRepository _fakeRepo = _FakeMessagingRepository();
_SpyNavigatorObserver _navObserver = _SpyNavigatorObserver();

Future<void> _pump(
  WidgetTester tester, {
  bool isManager = false,
  String currentUserId = 'user-me',
}) async {
  _fakeRepo = _FakeMessagingRepository();
  _navObserver = _SpyNavigatorObserver();

  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final userProfile = UserProfile(
    id: currentUserId,
    email: 'test@test.com',
    displayName: 'Test User',
    role: isManager ? 'admin' : 'practitioner',
  );

  // Use GoRouter so context.push('/messages/conv-123') is handled correctly.
  final router = GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    observers: [_navObserver],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const NewMessageScreen(gymId: 'g1'),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) => Scaffold(
          body: Text('thread-${state.pathParameters['conversationId']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messagingRepositoryProvider.overrideWithValue(_fakeRepo),
        rosterProvider('g1').overrideWith((_) => Future.value(_fakeMembers)),
        currentUserIdProvider.overrideWithValue(currentUserId),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(userProfile)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.glass(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  final UserProfile _profile;
  _FakeAuthNotifier(this._profile);

  @override
  AuthState build() {
    return AuthState(status: AuthStatus.authenticated, user: _profile);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('NewMessageScreen — Direct tab', () {
    testWidgets('shows Direct tab by default', (tester) async {
      await _pump(tester);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('Start button is disabled when no member selected', (tester) async {
      await _pump(tester);
      final startButton = tester.widget<ElevatedButton>(find.byKey(const Key('nm_start')));
      expect(startButton.onPressed, isNull);
    });

    testWidgets('pick a member then tap Start calls startDirect', (tester) async {
      await _pump(tester);

      // Select Alice from the member list
      await tester.tap(find.text('Alice'));
      await tester.pump();

      // Start button should now be enabled
      final startButton = tester.widget<ElevatedButton>(find.byKey(const Key('nm_start')));
      expect(startButton.onPressed, isNotNull);

      // Tap Start
      await tester.tap(find.byKey(const Key('nm_start')));
      await tester.pumpAndSettle();

      // Assert startDirect was called with Alice's userId
      expect(_fakeRepo.startDirectCalls, hasLength(1));
      expect(_fakeRepo.startDirectCalls.first, 'user-alice');

      // Assert navigation pushed to the thread route for conv-123
      expect(find.text('thread-conv-123'), findsOneWidget);
    });
  });

  group('NewMessageScreen — Group tab', () {
    testWidgets('switch to Group tab, enter title, select member, tap Create calls createGroup',
        (tester) async {
      await _pump(tester);

      // Switch to Group tab
      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();

      // Enter a group title
      await tester.enterText(find.byKey(const Key('nm_group_title')), 'Team Alpha');
      await tester.pump();

      // Select Bob
      await tester.tap(find.text('Bob'));
      await tester.pump();

      // Tap Create
      await tester.tap(find.byKey(const Key('nm_create')));
      await tester.pumpAndSettle();

      // Assert createGroup was called correctly
      expect(_fakeRepo.createGroupCalls, hasLength(1));
      final call = _fakeRepo.createGroupCalls.first;
      expect(call.gymId, 'g1');
      expect(call.title, 'Team Alpha');
      expect(call.participantIds, contains('user-bob'));

      // Assert navigation pushed to the thread route for conv-123
      expect(find.text('thread-conv-123'), findsOneWidget);
    });

    testWidgets('Create button is disabled when title is empty', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();

      // Select a member but leave title empty
      await tester.tap(find.text('Alice'));
      await tester.pump();

      final createButton = tester.widget<ElevatedButton>(find.byKey(const Key('nm_create')));
      expect(createButton.onPressed, isNull);
    });
  });

  group('NewMessageScreen — Channel tab visibility', () {
    testWidgets('Channel tab is visible for managers', (tester) async {
      await _pump(tester, isManager: true);
      expect(find.text('Channel'), findsOneWidget);
    });

    testWidgets('Channel tab is hidden for non-managers', (tester) async {
      await _pump(tester, isManager: false);
      expect(find.text('Channel'), findsNothing);
    });

    testWidgets('manager: enter channel title and tap Create calls createChannel',
        (tester) async {
      await _pump(tester, isManager: true);

      // Switch to Channel tab
      await tester.tap(find.text('Channel'));
      await tester.pumpAndSettle();

      // Enter channel title
      await tester.enterText(find.byKey(const Key('nm_channel_title')), 'Announcements');
      await tester.pump();

      // Tap Create
      await tester.tap(find.byKey(const Key('nm_channel_create')));
      await tester.pumpAndSettle();

      // Assert createChannel was called
      expect(_fakeRepo.createChannelCalls, hasLength(1));
      final call = _fakeRepo.createChannelCalls.first;
      expect(call.gymId, 'g1');
      expect(call.title, 'Announcements');

      // Assert navigation pushed to the thread route for conv-123
      expect(find.text('thread-conv-123'), findsOneWidget);
    });
  });
}
